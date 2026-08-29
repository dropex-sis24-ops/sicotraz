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

class LoteController
{
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
            $ahora = now('America/La_Paz');
            $automatico = $this->esQuirofano($area) && $this->enHorarioQuirofano($ahora);
            $plantilla = $this->plantillaParaArea($area);
            $this->moverHaciaLavanderia($area->id, $data['detalles']);

            $lote = Lote::query()->create([
                'area_id' => $area->id,
                'etapa' => $automatico ? 'en_lavado' : 'sucio_recibido',
                'fecha_hora' => $ahora,
                'peso_kg' => $data['peso_kg'],
                'usuario_entrega_id' => $usuarioEntrega?->id,
                'usuario_registra_id' => $usuario->id,
                'origen_registro' => 'manual',
                'plantilla_id' => $plantilla?->id,
                'nombre_quien_trae' => $data['nombre_quien_trae'] ?? null,
                'sincronizado' => true,
                'fecha_ultima_modificacion' => $ahora,
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
            'detalles.*.tipo_prenda_id' => ['required_with:detalles', 'distinct', 'exists:tipo_prenda,id'],
            'detalles.*.cantidad' => ['required_with:detalles', 'integer', 'min:1', 'max:999'],
        ]);

        DB::transaction(function () use ($data, $lote) {
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
            $lote->fecha_ultima_modificacion = now('America/La_Paz');
            $lote->save();
        });

        return response()->json($this->cargar($lote->fresh()));
    }

    public function avanzarEtapa(Request $request, Lote $lote): JsonResponse
    {
        $data = $request->validate(['etapa' => ['required', 'in:en_lavado']]);
        if ($lote->etapa !== 'sucio_recibido') {
            abort(422, 'El lote no puede avanzar a esa etapa.');
        }
        $this->cambiarEtapa($lote, $data['etapa'], $request->user()->id);

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
            $detalles = $lote->detalles()->get()->map(fn (DetalleLote $d) => [
                'tipo_prenda_id' => $d->tipo_prenda_id, 'cantidad' => $d->cantidad,
            ])->all();
            $this->devolverAlArea($lote->area_id, $detalles, 'cantidad_en_lavanderia');
            $lote->update([
                'usuario_recibe_id' => $recibe?->id,
                'etapa' => 'limpio_entregado',
                'fecha_ultima_modificacion' => now('America/La_Paz'),
            ]);
            $this->movimiento($lote, 'limpio_entregado', $request->user()->id, now('America/La_Paz'));
        });

        return response()->json($this->cargar($lote->fresh()));
    }

    public function historial(Request $request): JsonResponse
    {
        $data = $request->validate([
            'trabajador_id' => ['nullable', 'exists:usuario,id'],
            'area_id' => ['nullable', 'exists:area,id'],
            'desde' => ['nullable', 'date'],
            'hasta' => ['nullable', 'date'],
        ]);
        $lotes = Lote::query()->with(['area', 'detalles.tipoPrenda', 'registra', 'movimientos.usuario'])
            ->when($data['trabajador_id'] ?? null, fn ($q, $id) => $q->where('usuario_registra_id', $id))
            ->when($data['area_id'] ?? null, fn ($q, $id) => $q->where('area_id', $id))
            ->when($data['desde'] ?? null, fn ($q, $fecha) => $q->whereDate('fecha_hora', '>=', $fecha))
            ->when($data['hasta'] ?? null, fn ($q, $fecha) => $q->whereDate('fecha_hora', '<=', $fecha))
            ->latest('fecha_hora')
            ->paginate($request->integer('per_page', 20));

        return response()->json($lotes);
    }

    private function validarLote(Request $request): array
    {
        return $request->validate([
            'area_id' => ['required', 'exists:area,id'],
            'numero_item_entrega' => ['nullable', 'regex:/^[0-9]{1,10}$/'],
            'nombre_quien_trae' => ['nullable', 'string', 'max:255'],
            'peso_kg' => ['required', 'numeric', 'min:0.01', 'max:999.99'],
            'detalles' => ['required', 'array', 'min:1'],
            'detalles.*.tipo_prenda_id' => ['required', 'distinct', 'exists:tipo_prenda,id'],
            'detalles.*.cantidad' => ['required', 'integer', 'min:1', 'max:999'],
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

    private function devolverAlArea(int $areaId, array $detalles, string $origen): void
    {
        foreach ($detalles as $detalle) {
            $stock = StockArea::query()->lockForUpdate()->where([
                'area_id' => $areaId, 'tipo_prenda_id' => $detalle['tipo_prenda_id'],
            ])->firstOrFail();
            if ($stock->{$origen} < $detalle['cantidad']) {
                abort(422, 'El stock del lote ya no permite esta operación.');
            }
            $stock->{$origen} -= $detalle['cantidad'];
            $stock->cantidad_en_area += $detalle['cantidad'];
            $stock->save();
        }
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
        $fecha = now('America/La_Paz');
        $lote->update(['etapa' => $etapa, 'fecha_ultima_modificacion' => $fecha]);
        $this->movimiento($lote, $etapa, $usuarioId, $fecha);
    }

    private function autorizarCorreccion(Request $request, Lote $lote): void
    {
        $rol = $request->user()->rol?->nombre;
        if (in_array($rol, ['Super Admin', 'Encargado de Ropería y Lavandería'], true)) {
            return;
        }
        if ($rol === 'Ropera' && $this->esQuirofano($lote->area) && $lote->fecha_hora->greaterThan(now('America/La_Paz')->subHour())) {
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
        $hora = $fecha->format('H:i');

        return $hora >= '06:30' && $hora <= '16:30';
    }

    private function usuarioPorItem(?string $numeroItem): ?Usuario
    {
        if ($numeroItem === null || $numeroItem === '') {
            return null;
        }

        return Usuario::query()->where('numero_item', $numeroItem)->firstOrFail();
    }

    private function cargar(Lote $lote): Lote
    {
        return $lote->load(['area', 'detalles.tipoPrenda', 'movimientos.usuario', 'registra', 'entrega', 'recibe']);
    }
}
