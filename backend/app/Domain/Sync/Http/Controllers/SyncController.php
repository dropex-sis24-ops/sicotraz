<?php

namespace App\Domain\Sync\Http\Controllers;

use App\Domain\Alertas\Http\Controllers\AlertaController;
use App\Domain\Costura\Http\Controllers\BajaController;
use App\Domain\Movimientos\Http\Controllers\LoteController;
use App\Domain\Stock\Http\Controllers\VerificacionStockController;
use App\Domain\Stock\Models\StockArea;
use App\Domain\Sync\Models\ConflictoSincronizacion;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpKernel\Exception\HttpExceptionInterface;

class SyncController
{
    private const CONFIG = [
        'lote' => [
            'controller' => LoteController::class,
            'roles' => ['Ropera', 'Encargado de Ropería y Lavandería'],
            'autor' => 'usuario_registra_id',
        ],
        'alerta' => [
            'controller' => AlertaController::class,
            'roles' => ['Personal manual', 'Ropera', 'Encargado de Ropería y Lavandería'],
            'autor' => 'usuario_reporta_id',
        ],
        'baja' => [
            'controller' => BajaController::class,
            'roles' => ['Costura'],
            'autor' => 'usuario_costura_id',
        ],
        'verificacion_stock' => [
            'controller' => VerificacionStockController::class,
            'roles' => ['Personal manual'],
            'autor' => 'usuario_id',
        ],
    ];

    private const ROLES_RESOLUTORES = ['Super Admin', 'Encargado de Ropería y Lavandería'];

    /** Reglas con las que se valida la versión local antes de aplicarla. */
    private const REGLAS_VERSION_LOCAL = [
        'lote' => [
            'area_id' => ['sometimes', 'integer', 'exists:area,id'],
            'peso_kg' => ['sometimes', 'numeric', 'min:0.01', 'max:999.99'],
            'nombre_quien_trae' => ['sometimes', 'nullable', 'string', 'max:255'],
            'origen_registro' => ['sometimes', 'in:manual,ocr_local'],
            'detalles' => ['sometimes', 'array', 'min:1'],
            'detalles.*.tipo_prenda_id' => ['required_with:detalles', 'integer', 'distinct', 'exists:tipo_prenda,id'],
            'detalles.*.cantidad' => ['required_with:detalles', 'integer', 'min:1', 'max:999'],
        ],
        'baja' => [
            'area_id' => ['sometimes', 'integer', 'exists:area,id'],
            'tipo_prenda_id' => ['sometimes', 'integer', 'exists:tipo_prenda,id'],
            'cantidad' => ['sometimes', 'integer', 'min:1', 'max:999'],
            'motivo' => ['sometimes', 'string', 'max:255'],
            'descripcion' => ['sometimes', 'nullable', 'string', 'max:1000'],
            'foto_evidencia_url' => ['sometimes', 'nullable', 'string', 'max:2048'],
        ],
        'verificacion_stock' => [
            'area_id' => ['sometimes', 'integer', 'exists:area,id'],
            'observacion' => ['sometimes', 'nullable', 'string', 'max:1000'],
            'detalles' => ['sometimes', 'array'],
            'detalles.*.tipo_prenda_id' => ['required_with:detalles', 'integer', 'exists:tipo_prenda,id'],
            'detalles.*.cantidad_contada' => ['required_with:detalles', 'integer', 'min:0', 'max:999'],
        ],
        'alerta' => [
            'area_id' => ['sometimes', 'integer', 'exists:area,id'],
            'tipo_prenda_id' => ['sometimes', 'integer', 'exists:tipo_prenda,id'],
            'descripcion' => ['sometimes', 'string', 'min:3', 'max:1000'],
            'foto_evidencia_url' => ['sometimes', 'nullable', 'string', 'max:2048'],
        ],
    ];

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'registros' => ['required', 'array', 'min:1', 'max:100'],
            'registros.*.tipo' => ['required', Rule::in(array_keys(self::CONFIG))],
            'registros.*.uuid_local' => ['required', 'uuid'],
            'registros.*.fecha_ultima_modificacion' => ['required', 'date'],
            'registros.*.datos' => ['required', 'array'],
        ]);

        $guardados = [];
        $conflictos = [];
        $rechazados = [];
        $rol = $request->user()->rol?->nombre;

        foreach ($data['registros'] as $registro) {
            $config = self::CONFIG[$registro['tipo']];

            // Un registro que el rol no puede sincronizar se rechaza solo a sí
            // mismo: antes abortaba el lote completo y el dispositivo reintentaba
            // el mismo envío indefinidamente.
            if (! in_array($rol, $config['roles'], true)) {
                $rechazados[] = [
                    'uuid_local' => $registro['uuid_local'],
                    'motivo' => 'El rol no puede sincronizar este tipo de registro.',
                ];

                continue;
            }

            try {
                $resultado = DB::transaction(fn () => $this->procesar($request, $registro, $config));
            } catch (HttpExceptionInterface $excepcion) {
                // El servidor rechazó el contenido (p. ej. sin stock). Reintentarlo
                // nunca va a funcionar, así que se informa y se saca de la cola.
                $rechazados[] = [
                    'uuid_local' => $registro['uuid_local'],
                    'motivo' => $excepcion->getMessage() ?: 'El servidor rechazó el registro.',
                ];

                continue;
            } catch (ValidationException $excepcion) {
                $rechazados[] = [
                    'uuid_local' => $registro['uuid_local'],
                    'motivo' => collect($excepcion->errors())->flatten()->first() ?? 'Datos inválidos.',
                ];

                continue;
            }

            if (isset($resultado['conflicto'])) {
                $conflictos[] = $resultado['conflicto'];
            } else {
                $guardados[] = $resultado['guardado'];
            }
        }

        return response()->json([
            'guardados' => $guardados,
            'conflictos' => $conflictos,
            'rechazados' => $rechazados,
        ]);
    }

    /**
     * @param  array<string, mixed>  $registro
     * @param  array<string, mixed>  $config
     * @return array<string, mixed>
     */
    private function procesar(Request $request, array $registro, array $config): array
    {
        $hash = $this->hash($registro['datos']);
        $existente = DB::table($registro['tipo'])
            ->where('uuid_local', $registro['uuid_local'])
            ->lockForUpdate()
            ->first();

        if ($existente !== null) {
            if ($existente->sync_payload_hash === $hash) {
                return ['guardado' => [
                    'uuid_local' => $registro['uuid_local'],
                    'id' => $existente->id,
                    'duplicado' => true,
                ]];
            }
            $conflicto = ConflictoSincronizacion::query()->firstOrCreate(
                ['entidad_tipo' => $registro['tipo'], 'entidad_id' => $existente->id, 'estado' => 'pendiente'],
                [
                    'version_local_json' => $registro['datos'],
                    'version_servidor_json' => $this->versionServidor($registro['tipo'], (array) $existente),
                ],
            );

            return ['conflicto' => [
                'id' => $conflicto->id,
                'uuid_local' => $registro['uuid_local'],
            ]];
        }

        $payload = [...$registro['datos'], 'uuid_local' => $registro['uuid_local']];
        $subrequest = Request::create('/api/sync/'.$registro['tipo'], 'POST', $payload);
        $subrequest->setUserResolver(fn () => $request->user());
        $response = app($config['controller'])->store($subrequest);
        $created = $response->getData(true);
        abort_unless(isset($created['id']), 500, 'La respuesta del registro no incluye su identificador.');

        DB::table($registro['tipo'])->where('id', $created['id'])->update([
            'uuid_local' => $registro['uuid_local'],
            'sync_payload_hash' => $hash,
            'sincronizado' => true,
            // La fecha la pone el servidor: un reloj desajustado en la tablet
            // dejaba registros fechados en el futuro.
            'fecha_ultima_modificacion' => now(),
        ]);

        return ['guardado' => [
            'uuid_local' => $registro['uuid_local'],
            'id' => $created['id'],
            'duplicado' => false,
        ]];
    }

    public function index(Request $request): JsonResponse
    {
        $usuario = $request->user();
        $conflictos = ConflictoSincronizacion::query()->where('estado', 'pendiente');

        // Quien no resuelve conflictos solo ve los de sus propios registros.
        if (! in_array($usuario->rol?->nombre, self::ROLES_RESOLUTORES, true)) {
            $conflictos->where(function ($query) use ($usuario): void {
                foreach (self::CONFIG as $tipo => $config) {
                    $query->orWhere(fn ($q) => $q
                        ->where('entidad_tipo', $tipo)
                        ->whereIn('entidad_id', DB::table($tipo)
                            ->where($config['autor'], $usuario->id)
                            ->select('id')));
                }
            });
        }

        return response()->json($conflictos->latest()->limit(100)->get());
    }

    public function resolver(Request $request, int $conflicto): JsonResponse
    {
        $conflicto = ConflictoSincronizacion::query()->findOrFail($conflicto);
        abort_if($conflicto->estado !== 'pendiente', 422, 'El conflicto ya fue resuelto.');
        $data = $request->validate(['version_elegida' => ['required', Rule::in(['local', 'servidor'])]]);

        DB::transaction(function () use ($conflicto, $data, $request): void {
            if ($data['version_elegida'] === 'local') {
                $this->aplicarVersionLocal($conflicto);
                $conflicto->version_servidor_json = [];
            } else {
                // Se sella el hash de la versión local descartada para que el
                // dispositivo la reconozca como ya resuelta y deje de reenviarla.
                DB::table($conflicto->entidad_tipo)
                    ->where('id', $conflicto->entidad_id)
                    ->update([
                        'sync_payload_hash' => $this->hash($conflicto->version_local_json),
                        'fecha_ultima_modificacion' => now(),
                    ]);
                $conflicto->version_local_json = [];
            }
            $conflicto->estado = 'resuelto';
            $conflicto->version_elegida = $data['version_elegida'];
            $conflicto->resuelto_por_id = $request->user()->id;
            $conflicto->fecha_resolucion = now();
            $conflicto->save();
        });

        return response()->json($conflicto->fresh());
    }

    private function aplicarVersionLocal(ConflictoSincronizacion $conflicto): void
    {
        $this->validarVersionLocal($conflicto);

        match ($conflicto->entidad_tipo) {
            'lote' => $this->aplicarLote($conflicto),
            'baja' => $this->aplicarBaja($conflicto),
            'verificacion_stock' => $this->aplicarVerificacion($conflicto),
            default => $this->actualizarBasico($conflicto, [
                'area_id', 'tipo_prenda_id', 'descripcion', 'foto_evidencia_url',
            ]),
        };
    }

    private function aplicarLote(ConflictoSincronizacion $conflicto): void
    {
        $local = $conflicto->version_local_json;
        $actual = DB::table('lote')->where('id', $conflicto->entidad_id)->lockForUpdate()->firstOrFail();
        $detallesActuales = DB::table('detalle_lote')->where('lote_id', $actual->id)->get();
        foreach ($detallesActuales as $detalle) {
            $stock = StockArea::query()->lockForUpdate()->where([
                'area_id' => $actual->area_id,
                'tipo_prenda_id' => $detalle->tipo_prenda_id,
            ])->firstOrFail();
            abort_if($stock->cantidad_en_lavanderia < $detalle->cantidad, 422, 'El stock actual impide reemplazar el lote.');
            $stock->cantidad_en_lavanderia -= $detalle->cantidad;
            $stock->cantidad_en_area += $detalle->cantidad;
            $stock->save();
        }
        $areaId = (int) ($local['area_id'] ?? $actual->area_id);
        foreach ($local['detalles'] ?? [] as $detalle) {
            $stock = StockArea::query()->lockForUpdate()->where([
                'area_id' => $areaId,
                'tipo_prenda_id' => $detalle['tipo_prenda_id'],
            ])->firstOrFail();
            abort_if($stock->cantidad_en_area < $detalle['cantidad'], 422, 'No existe stock suficiente para elegir esta versión del lote.');
            $stock->cantidad_en_area -= $detalle['cantidad'];
            $stock->cantidad_en_lavanderia += $detalle['cantidad'];
            $stock->save();
        }
        DB::table('detalle_lote')->where('lote_id', $actual->id)->delete();
        foreach ($local['detalles'] ?? [] as $detalle) {
            DB::table('detalle_lote')->insert([
                'lote_id' => $actual->id,
                'tipo_prenda_id' => $detalle['tipo_prenda_id'],
                'cantidad' => $detalle['cantidad'],
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        }
        $this->actualizarBasico($conflicto, [
            'area_id', 'peso_kg', 'nombre_quien_trae', 'origen_registro',
        ]);
    }

    private function aplicarBaja(ConflictoSincronizacion $conflicto): void
    {
        $local = $conflicto->version_local_json;
        $actual = DB::table('baja')->where('id', $conflicto->entidad_id)->lockForUpdate()->firstOrFail();
        $stockAnterior = StockArea::query()->lockForUpdate()->where([
            'area_id' => $actual->area_id,
            'tipo_prenda_id' => $actual->tipo_prenda_id,
        ])->firstOrFail();
        $stockAnterior->cantidad_total += $actual->cantidad;
        $stockAnterior->cantidad_en_area += $actual->cantidad;
        $stockAnterior->save();

        $cantidad = (int) ($local['cantidad'] ?? $actual->cantidad);
        $stockNuevo = StockArea::query()->lockForUpdate()->where([
            'area_id' => $local['area_id'] ?? $actual->area_id,
            'tipo_prenda_id' => $local['tipo_prenda_id'] ?? $actual->tipo_prenda_id,
        ])->firstOrFail();
        abort_if($stockNuevo->cantidad_total < $cantidad, 422, 'No existe stock suficiente para elegir esta versión de la baja.');
        $desdeArea = min($cantidad, $stockNuevo->cantidad_en_area);
        $stockNuevo->cantidad_en_area -= $desdeArea;
        $restante = $cantidad - $desdeArea;
        abort_if($stockNuevo->cantidad_en_lavanderia < $restante, 422, 'La distribución del stock impide elegir esta versión.');
        $stockNuevo->cantidad_en_lavanderia -= $restante;
        $stockNuevo->cantidad_total -= $cantidad;
        $stockNuevo->save();
        $this->actualizarBasico($conflicto, [
            'area_id', 'tipo_prenda_id', 'cantidad', 'motivo', 'descripcion', 'foto_evidencia_url',
        ]);
    }

    private function aplicarVerificacion(ConflictoSincronizacion $conflicto): void
    {
        $local = $conflicto->version_local_json;
        $actual = DB::table('verificacion_stock')->where('id', $conflicto->entidad_id)->lockForUpdate()->firstOrFail();
        $areaId = (int) ($local['area_id'] ?? $actual->area_id);
        $stocks = DB::table('stock_area')->where('area_id', $areaId)->pluck('cantidad_en_area', 'tipo_prenda_id');
        $resultado = 'sin_novedad';
        DB::table('detalle_verificacion_stock')->where('verificacion_stock_id', $actual->id)->delete();
        foreach ($local['detalles'] ?? [] as $detalle) {
            $esperada = (int) ($stocks[$detalle['tipo_prenda_id']] ?? 0);
            if ($esperada !== (int) $detalle['cantidad_contada']) {
                $resultado = 'irregularidad_reportada';
            }
            DB::table('detalle_verificacion_stock')->insert([
                'verificacion_stock_id' => $actual->id,
                'tipo_prenda_id' => $detalle['tipo_prenda_id'],
                'cantidad_esperada' => $esperada,
                'cantidad_contada' => $detalle['cantidad_contada'],
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        }
        $local['resultado'] = $resultado;
        $conflicto->version_local_json = $local;
        $this->actualizarBasico($conflicto, ['area_id', 'observacion', 'resultado']);
    }

    /**
     * La versión local procede del dispositivo: sin esta comprobación se podía
     * escribir un peso negativo o un área inexistente directamente en la tabla.
     */
    private function validarVersionLocal(ConflictoSincronizacion $conflicto): void
    {
        $reglas = self::REGLAS_VERSION_LOCAL[$conflicto->entidad_tipo] ?? [];
        $datos = Arr::only($conflicto->version_local_json, array_map(
            fn (string $campo) => Str::before($campo, '.'),
            array_keys($reglas),
        ));

        Validator::make($datos, $reglas)->validate();
    }

    private function actualizarBasico(ConflictoSincronizacion $conflicto, array $permitidos): void
    {
        $values = Arr::only($conflicto->version_local_json, $permitidos);
        $values['sync_payload_hash'] = $this->hash($conflicto->version_local_json);
        $values['fecha_ultima_modificacion'] = now();
        DB::table($conflicto->entidad_tipo)->where('id', $conflicto->entidad_id)->update($values);
    }

    private function versionServidor(string $tipo, array $registro): array
    {
        if ($tipo === 'lote') {
            $registro['detalles'] = DB::table('detalle_lote')->where('lote_id', $registro['id'])->get()->map(fn ($item) => (array) $item)->all();
        }
        if ($tipo === 'verificacion_stock') {
            $registro['detalles'] = DB::table('detalle_verificacion_stock')->where('verificacion_stock_id', $registro['id'])->get()->map(fn ($item) => (array) $item)->all();
        }

        return $registro;
    }

    private function hash(array $payload): string
    {
        $sort = function (&$value) use (&$sort): void {
            if (! is_array($value)) {
                return;
            }
            foreach ($value as &$child) {
                $sort($child);
            }
            if (Arr::isAssoc($value)) {
                ksort($value);

                return;
            }
            // Las listas se ordenan por su contenido: el orden en que el
            // dispositivo envía los detalles no debe generar un falso conflicto.
            usort($value, fn ($a, $b) => strcmp(
                json_encode($a, JSON_UNESCAPED_UNICODE),
                json_encode($b, JSON_UNESCAPED_UNICODE),
            ));
        };
        $sort($payload);

        return hash('sha256', json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES));
    }
}
