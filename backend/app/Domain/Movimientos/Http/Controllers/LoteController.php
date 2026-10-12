<?php

namespace App\Domain\Movimientos\Http\Controllers;

use App\Domain\Movimientos\Models\DetalleLote;
use App\Domain\Movimientos\Models\Lote;
use App\Domain\Stock\Models\Area;
use App\Domain\Stock\Models\PlantillaFormulario;
use App\Domain\Stock\Models\StockArea;
use App\Domain\Stock\Models\TipoPrenda;
use App\Domain\Usuarios\Models\Usuario;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

class LoteController
{
    /** @var array<int, array{tipo_prenda_id: int, cantidad: int}> */
    private array $avisoBajas = [];

    // RF16–RF20 — ingreso manual, etapas, entrega limpia e historial.
    public function formulario(Request $request): JsonResponse
    {
        $data = $request->validate(['area_id' => ['required', 'exists:area,id']]);
        $area = Area::query()->findOrFail($data['area_id']);
        $plantilla = $this->plantillaParaArea($area);
        $nombres = $plantilla?->estructura_campos['tipos_prenda'] ?? [];
        $prendas = TipoPrenda::query()->where('activo', true)->get()
            ->filter(fn (TipoPrenda $prenda) => in_array($prenda->nombre, $nombres, true))
            ->sortBy(function (TipoPrenda $prenda) use ($nombres): int {
                return array_search($prenda->nombre, $nombres, true);
            })
            ->values();

        return response()->json(['plantilla' => $plantilla?->nombre, 'prendas' => $prendas]);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $this->validarLote($request);
        $usuarioEntrega = $this->usuarioPorItem($data['numero_item_entrega'] ?? null);
        $usuario = $request->user();

        $lote = DB::transaction(function () use ($data, $usuarioEntrega, $usuario) {
            $area = Area::query()->findOrFail($data['area_id']);
            $ahora = now();
            $automatico = $this->esQuirofano($area) && $this->enHorarioQuirofano($ahora);
            $plantilla = $this->plantillaParaArea($area);
            abort_if(
                ($data['origen_registro'] ?? 'manual') === 'ocr_local' && $plantilla === null,
                422,
                'No existe la plantilla de formulario del área. Un lote digitalizado por OCR '
                .'requiere su plantilla (RN15); créela antes de registrar.',
            );
            $this->moverHaciaLavanderia($area->id, $data['detalles']);

            $lote = Lote::query()->create([
                'area_id' => $area->id,
                'etapa' => $automatico ? 'en_lavado' : 'sucio_recibido',
                'fecha_hora' => $ahora,
                'peso_kg' => $data['peso_kg'],
                'usuario_entrega_id' => $usuarioEntrega?->id,
                'usuario_registra_id' => $usuario->id,
                'origen_registro' => $data['origen_registro'] ?? 'manual',
                'plantilla_id' => $plantilla?->id,
                'nombre_quien_trae' => $data['nombre_quien_trae'] ?? null,
                'sincronizado' => true,
                'fecha_ultima_modificacion' => $ahora,
                'uuid_local' => $data['uuid_local'] ?? null,
            ]);
            $this->guardarDetalles($lote, $data['detalles']);
            $this->movimiento($lote, 'sucio_recibido', $usuario->id, $ahora);
            if ($automatico) {
                $this->movimiento($lote, 'en_lavado', $usuario->id, $ahora);
            }

            return $lote;
        });

        return response()->json($this->cargar($lote), 201);
    }

    public function show(Lote $lote): JsonResponse
    {
        return response()->json($this->cargar($lote));
    }

    public function actualizar(Request $request, Lote $lote): JsonResponse
    {
        $this->autorizarCorreccion($request, $lote);
        if ($lote->etapa === 'limpio_entregado') {
            abort(422, 'No se puede corregir un lote ya entregado.');
        }
        $data = $request->validate([
            'peso_kg' => ['sometimes', 'numeric', 'min:0', 'max:999.99'],
            'nombre_quien_trae' => ['sometimes', 'nullable', 'string', 'max:255'],
            'detalles' => ['sometimes', 'array', 'min:1'],
            'detalles.*.tipo_prenda_id' => [
                'required_with:detalles', 'distinct',
                Rule::exists('tipo_prenda', 'id')->where('activo', true),
            ],
            'detalles.*.cantidad' => ['required_with:detalles', 'integer', 'min:1', 'max:999'],
        ]);

        DB::transaction(function () use ($data, $lote) {
            $lote = Lote::query()->whereKey($lote->id)->lockForUpdate()->firstOrFail();
            if ($lote->etapa === 'limpio_entregado') {
                abort(422, 'No se puede corregir un lote ya entregado.');
            }
            if (isset($data['detalles'])) {
                $actuales = $lote->detalles()->get()->map(fn (DetalleLote $d) => [
                    'tipo_prenda_id' => $d->tipo_prenda_id, 'cantidad' => $d->cantidad,
                ])->all();
                $this->devolverAlArea($lote->area_id, $actuales, 'cantidad_en_lavanderia');
                $this->moverHaciaLavanderia($lote->area_id, $data['detalles']);
                $lote->detalles()->delete();
                $this->guardarDetalles($lote, $data['detalles']);
            }
            $lote->fill(collect($data)->except('detalles')->all());
            $lote->fecha_ultima_modificacion = now();
            $lote->save();
        });

        return response()->json($this->cargar($lote->fresh()));
    }

    public function avanzarEtapa(Request $request, Lote $lote): JsonResponse
    {
        $data = $request->validate(['etapa' => ['required', 'in:en_lavado']]);

        DB::transaction(function () use ($lote, $data, $request): void {
            // Se relee con bloqueo: sin esto, dos toques seguidos registraban
            // el movimiento dos veces.
            $actual = Lote::query()->whereKey($lote->id)->lockForUpdate()->firstOrFail();
            if ($actual->etapa !== 'sucio_recibido') {
                abort(422, 'El lote no puede avanzar a esa etapa.');
            }
            $this->cambiarEtapa($actual, $data['etapa'], $request->user()->id);
        });

        return response()->json($this->cargar($lote->fresh()));
    }

    public function entregaLimpia(Request $request, Lote $lote): JsonResponse
    {
        $data = $request->validate(['numero_item_recibe' => ['nullable', 'regex:/^[0-9]{1,10}$/']]);
        if ($lote->etapa !== 'en_lavado') {
            abort(422, 'La entrega limpia requiere que el lote esté en lavado.');
        }
        $recibe = $this->usuarioPorItem($data['numero_item_recibe'] ?? null);
        DB::transaction(function () use ($lote, $recibe, $request) {
            $actual = Lote::query()->whereKey($lote->id)->lockForUpdate()->firstOrFail();
            if ($actual->etapa !== 'en_lavado') {
                abort(422, 'La entrega limpia requiere que el lote esté en lavado.');
            }
            $detalles = $actual->detalles()->get()->map(fn (DetalleLote $d) => [
                'tipo_prenda_id' => $d->tipo_prenda_id, 'cantidad' => $d->cantidad,
            ])->all();
            $noDevueltas = $this->devolverAlArea($actual->area_id, $detalles, 'cantidad_en_lavanderia', tolerarBajas: true);
            $actual->update([
                'usuario_recibe_id' => $recibe?->id,
                'etapa' => 'limpio_entregado',
                'fecha_ultima_modificacion' => now(),
            ]);
            $this->movimiento($actual, 'limpio_entregado', $request->user()->id, now());
            $this->avisoBajas = $noDevueltas;
        });

        $respuesta = $this->cargar($lote->fresh())->toArray();
        if ($this->avisoBajas !== []) {
            $respuesta['aviso'] = 'Algunas prendas del lote se dieron de baja mientras estaba en lavandería '
                .'y no se devolvieron al área.';
            $respuesta['prendas_dadas_de_baja'] = $this->avisoBajas;
        }

        return response()->json($respuesta);
    }

    public function historial(Request $request): JsonResponse
    {
        $data = $request->validate([
            'trabajador_id' => ['nullable', 'exists:usuario,id'],
            'area_id' => ['nullable', 'exists:area,id'],
            'desde' => ['nullable', 'date'],
            'hasta' => ['nullable', 'date', 'after_or_equal:desde'],
            'etapa' => ['nullable', 'in:sucio_recibido,en_lavado,limpio_entregado'],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:100'],
        ]);
        // RF20: el historial es consultable por todos los roles autenticados.
        $lotes = Lote::query()->with(['area', 'detalles.tipoPrenda', 'registra', 'movimientos.usuario'])
            ->when($data['trabajador_id'] ?? null, fn ($q, $id) => $q->where('usuario_registra_id', $id))
            ->when($data['area_id'] ?? null, fn ($q, $id) => $q->where('area_id', $id))
            ->when($data['etapa'] ?? null, fn ($q, $etapa) => $q->where('etapa', $etapa))
            ->when($data['desde'] ?? null, fn ($q, $fecha) => $q->whereDate('fecha_hora', '>=', $fecha))
            ->when($data['hasta'] ?? null, fn ($q, $fecha) => $q->whereDate('fecha_hora', '<=', $fecha))
            ->latest('fecha_hora')
            ->paginate(min($request->integer('per_page', 20), 100));

        return response()->json($lotes);
    }

    private function validarLote(Request $request): array
    {
        return $request->validate([
            'area_id' => ['required', Rule::exists('area', 'id')->where('activo', true)],
            'numero_item_entrega' => ['nullable', 'regex:/^[0-9]{1,10}$/'],
            'nombre_quien_trae' => ['nullable', 'string', 'max:255'],
            'origen_registro' => ['nullable', 'in:manual,ocr_local'],
            'peso_kg' => ['required', 'numeric', 'min:0.01', 'max:999.99'],
            'detalles' => ['required', 'array', 'min:1'],
            'detalles.*.tipo_prenda_id' => [
                'required', 'distinct',
                Rule::exists('tipo_prenda', 'id')->where('activo', true),
            ],
            'detalles.*.cantidad' => ['required', 'integer', 'min:1', 'max:999'],
            'uuid_local' => ['nullable', 'uuid'],
        ]);
    }

    private function moverHaciaLavanderia(int $areaId, array $detalles): void
    {
        foreach ($detalles as $detalle) {
            $stock = StockArea::query()->lockForUpdate()->firstOrNew([
                'area_id' => $areaId, 'tipo_prenda_id' => $detalle['tipo_prenda_id'],
            ]);
            if (! $stock->exists || $stock->cantidad_en_area < $detalle['cantidad']) {
                abort(422, 'No existe stock suficiente en el área para registrar este lote.');
            }
            $stock->cantidad_en_area -= $detalle['cantidad'];
            $stock->cantidad_en_lavanderia += $detalle['cantidad'];
            $stock->save();
        }
    }

    /**
     * @param  array<int, array{tipo_prenda_id: int, cantidad: int}>  $detalles
     * @return array<int, array{tipo_prenda_id: int, cantidad: int}> prendas del
     *                                                               lote que ya no estaban en lavandería (dadas de baja entre medias)
     */
    private function devolverAlArea(int $areaId, array $detalles, string $origen, bool $tolerarBajas = false): array
    {
        $noDevueltas = [];
        foreach ($detalles as $detalle) {
            $stock = StockArea::query()->lockForUpdate()->where([
                'area_id' => $areaId, 'tipo_prenda_id' => $detalle['tipo_prenda_id'],
            ])->firstOrFail();
            if ($stock->{$origen} < $detalle['cantidad']) {
                // Una baja registrada mientras el lote estaba en lavandería ya
                // descontó esas prendas: bloquear la entrega dejaría el lote
                // atascado sin forma de cerrarlo.
                abort_unless($tolerarBajas, 422, 'El stock del lote ya no permite esta operación.');
                $devolver = max(0, (int) $stock->{$origen});
                $noDevueltas[] = [
                    'tipo_prenda_id' => $detalle['tipo_prenda_id'],
                    'cantidad' => $detalle['cantidad'] - $devolver,
                ];
            } else {
                $devolver = $detalle['cantidad'];
            }
            if ($devolver === 0) {
                continue;
            }
            $stock->{$origen} -= $devolver;
            $stock->cantidad_en_area += $devolver;
            $stock->save();
        }

        return $noDevueltas;
    }

    private function guardarDetalles(Lote $lote, array $detalles): void
    {
        foreach ($detalles as $detalle) {
            $lote->detalles()->create($detalle);
        }
    }

    private function movimiento(Lote $lote, string $etapa, int $usuarioId, Carbon $fecha): void
    {
        $lote->movimientos()->create(['etapa' => $etapa, 'fecha_hora' => $fecha, 'usuario_id' => $usuarioId]);
    }

    private function cambiarEtapa(Lote $lote, string $etapa, int $usuarioId): void
    {
        $fecha = now();
        $lote->update(['etapa' => $etapa, 'fecha_ultima_modificacion' => $fecha]);
        $this->movimiento($lote, $etapa, $usuarioId, $fecha);
    }

    private function autorizarCorreccion(Request $request, Lote $lote): void
    {
        $rol = $request->user()->rol?->nombre;
        if (in_array($rol, ['Super Admin', 'Encargado de Ropería y Lavandería'], true)) {
            return;
        }
        if ($rol === 'Ropera' && $this->esQuirofano($lote->area) && $lote->fecha_hora->greaterThan(now()->subHour())) {
            return;
        }
        abort(403, 'No tiene permiso para corregir este lote.');
    }

    private function plantillaParaArea(Area $area): ?PlantillaFormulario
    {
        return PlantillaFormulario::query()->where('nombre', $this->esQuirofano($area) ? 'Quirófano' : 'Salas')->first();
    }

    private function esQuirofano(Area $area): bool
    {
        return $area->nombre === 'Quirófano';
    }

    private function enHorarioQuirofano(Carbon $fecha): bool
    {
        $minutos = $fecha->hour * 60 + $fecha->minute;

        return $minutos >= (6 * 60 + 30) && $minutos <= (16 * 60 + 30);
    }

    private function usuarioPorItem(?string $numeroItem): ?Usuario
    {
        if ($numeroItem === null || $numeroItem === '') {
            return null;
        }

        $usuario = Usuario::query()->where('numero_item', $numeroItem)->first();
        abort_if($usuario === null, 422, "No existe un usuario con el N° de ítem {$numeroItem}.");
        abort_if(! $usuario->activo, 422, "La cuenta con N° de ítem {$numeroItem} está desactivada.");

        return $usuario;
    }

    private function cargar(Lote $lote): Lote
    {
        return $lote->load(['area', 'detalles.tipoPrenda', 'movimientos.usuario', 'registra', 'entrega', 'recibe']);
    }
}
