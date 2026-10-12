<?php

namespace App\Domain\Stock\Http\Controllers;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class VerificacionStockController
{
    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'area_id' => ['nullable', 'exists:area,id'],
            'observacion' => ['nullable', 'string', 'max:1000'],
            'detalles' => ['required', 'array', 'min:1'],
            'detalles.*.tipo_prenda_id' => ['required', 'distinct', 'exists:tipo_prenda,id'],
            'detalles.*.cantidad_contada' => ['required', 'integer', 'min:0', 'max:999'],
            'uuid_local' => ['nullable', 'uuid'],
        ]);

        $areaId = $data['area_id'] ?? $request->user()->area_id;
        if ($areaId === null) {
            abort(422, 'El usuario no tiene un área asignada.');
        }
        if ($request->user()->area_id !== null && $areaId !== $request->user()->area_id) {
            abort(403, 'Solo puede verificar el stock de su área asignada.');
        }
        $data['area_id'] = $areaId;
        $resultado = 'sin_novedad';
        $verificacion = DB::transaction(function () use ($request, $data, &$resultado) {
            $stocks = DB::table('stock_area')->where('area_id', $data['area_id'])
                ->pluck('cantidad_en_area', 'tipo_prenda_id')
                // Según el driver, pluck devuelve cadenas; con la comparación
                // estricta anterior toda verificación salía como irregularidad.
                ->map(fn ($cantidad) => (int) $cantidad);
            $contadas = collect($data['detalles'])
                ->mapWithKeys(fn (array $detalle) => [
                    (int) $detalle['tipo_prenda_id'] => (int) $detalle['cantidad_contada'],
                ]);
            // Una prenda con stock que no se contó también es una diferencia:
            // antes se podía ocultar un faltante simplemente omitiéndola.
            $prendas = $stocks->keys()->merge($contadas->keys())->unique();
            foreach ($prendas as $tipoPrendaId) {
                if (($stocks[$tipoPrendaId] ?? 0) !== ($contadas[$tipoPrendaId] ?? 0)) {
                    $resultado = 'irregularidad_reportada';
                }
            }
            if ($resultado === 'irregularidad_reportada' && blank($data['observacion'] ?? null)) {
                abort(422, 'La observación es obligatoria cuando existe una diferencia.');
            }
            $id = DB::table('verificacion_stock')->insertGetId([
                'area_id' => $data['area_id'], 'usuario_id' => $request->user()->id, 'fecha_hora' => now(),
                'resultado' => $resultado, 'observacion' => $data['observacion'] ?? null,
                'sincronizado' => true, 'fecha_ultima_modificacion' => now(), 'created_at' => now(), 'updated_at' => now(),
                'uuid_local' => $data['uuid_local'] ?? null,
            ]);
            foreach ($prendas as $tipoPrendaId) {
                DB::table('detalle_verificacion_stock')->insert([
                    'verificacion_stock_id' => $id, 'tipo_prenda_id' => $tipoPrendaId,
                    'cantidad_esperada' => $stocks[$tipoPrendaId] ?? 0,
                    'cantidad_contada' => $contadas[$tipoPrendaId] ?? 0,
                    'created_at' => now(), 'updated_at' => now(),
                ]);
            }

            return $id;
        });

        return response()->json(['id' => $verificacion, 'resultado' => $resultado], 201);
    }
}
