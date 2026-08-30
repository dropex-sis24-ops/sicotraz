<?php

namespace App\Domain\Sync\Http\Controllers;

use App\Domain\Alertas\Http\Controllers\AlertaController;
use App\Domain\Alertas\Models\Alerta;
use App\Domain\Costura\Http\Controllers\BajaController;
use App\Domain\Costura\Models\Baja;
use App\Domain\Movimientos\Http\Controllers\LoteController;
use App\Domain\Movimientos\Models\Lote;
use App\Domain\Stock\Http\Controllers\VerificacionStockController;
use App\Domain\Stock\Models\StockArea;
use App\Domain\Sync\Models\ConflictoSincronizacion;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

class SyncController
{
    private const CONFIG = [
        'lote' => ['model' => Lote::class, 'controller' => LoteController::class, 'roles' => ['Ropera', 'Encargado de Ropería y Lavandería']],
        'alerta' => ['model' => Alerta::class, 'controller' => AlertaController::class, 'roles' => ['Personal manual', 'Ropera', 'Encargado de Ropería y Lavandería']],
        'baja' => ['model' => Baja::class, 'controller' => BajaController::class, 'roles' => ['Costura']],
        'verificacion_stock' => ['model' => null, 'controller' => VerificacionStockController::class, 'roles' => ['Personal manual']],
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
        foreach ($data['registros'] as $registro) {
            $config = self::CONFIG[$registro['tipo']];
            $rol = $request->user()->rol?->nombre;
            abort_unless(in_array($rol, $config['roles'], true), 403, 'El rol no puede sincronizar este tipo de registro.');

            $hash = $this->hash($registro['datos']);
            $existente = DB::table($registro['tipo'])
                ->where('uuid_local', $registro['uuid_local'])
                ->first();
            if ($existente !== null) {
                if ($existente->sync_payload_hash === $hash) {
                    $guardados[] = ['uuid_local' => $registro['uuid_local'], 'id' => $existente->id, 'duplicado' => true];

                    continue;
                }
                $conflicto = ConflictoSincronizacion::query()->firstOrCreate(
                    ['entidad_tipo' => $registro['tipo'], 'entidad_id' => $existente->id, 'estado' => 'pendiente'],
                    ['version_local_json' => $registro['datos'], 'version_servidor_json' => $this->versionServidor($registro['tipo'], (array) $existente)],
                );
                $conflictos[] = [
                    'id' => $conflicto->id,
                    'uuid_local' => $registro['uuid_local'],
                ];

                continue;
            }

            $payload = [...$registro['datos'], 'uuid_local' => $registro['uuid_local']];
            $subrequest = Request::create('/api/sync/'.$registro['tipo'], 'POST', $payload);
            $subrequest->setUserResolver(fn () => $request->user());
            $response = app($config['controller'])->store($subrequest);
            $created = $response->getData(true);
            DB::table($registro['tipo'])->where('id', $created['id'])->update([
                'uuid_local' => $registro['uuid_local'],
                'sync_payload_hash' => $hash,
                'sincronizado' => true,
                'fecha_ultima_modificacion' => $registro['fecha_ultima_modificacion'],
            ]);
            $guardados[] = ['uuid_local' => $registro['uuid_local'], 'id' => $created['id'], 'duplicado' => false];
        }

        return response()->json(['guardados' => $guardados, 'conflictos' => $conflictos]);
    }

    public function index(): JsonResponse
    {
        return response()->json(ConflictoSincronizacion::query()
            ->where('estado', 'pendiente')->latest()->get());
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
                $conflicto->version_local_json = [];
            }
            $conflicto->estado = 'resuelto';
            $conflicto->version_elegida = $data['version_elegida'];
            $conflicto->resuelto_por_id = $request->user()->id;
            $conflicto->fecha_resolucion = now('America/La_Paz');
            $conflicto->save();
        });

        return response()->json($conflicto->fresh());
    }

    private function aplicarVersionLocal(ConflictoSincronizacion $conflicto): void
    {
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
        $actual = DB::table('verificacion_stock')->where('id', $conflicto->entidad_id)->firstOrFail();
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

    private function actualizarBasico(ConflictoSincronizacion $conflicto, array $permitidos): void
    {
        $values = Arr::only($conflicto->version_local_json, $permitidos);
        $values['sync_payload_hash'] = $this->hash($conflicto->version_local_json);
        $values['fecha_ultima_modificacion'] = now('America/La_Paz');
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
            }
        };
        $sort($payload);

        return hash('sha256', json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES));
    }
}
