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
            'area_id' => ['required', 'exists:area,id'],
            'observacion' => ['nullable', 'string'],
            'detalles' => ['required', 'array', 'min:1'],
            'detalles.*.tipo_prenda_id' => ['required', 'exists:tipo_prenda,id'],
            'detalles.*.cantidad_contada' => ['required', 'integer', 'min:0', 'max:999'],
        ]);

        $resultado = 'sin_novedad';
        $verificacion = DB::transaction(function () use ($request, $data, &$resultado) {
            $stocks = DB::table('stock_area')->where('area_id', $data['area_id'])->pluck('cantidad_en_area', 'tipo_prenda_id');
            foreach ($data['detalles'] as $detalle) {
                if (($stocks[$detalle['tipo_prenda_id']] ?? 0) !== $detalle['cantidad_contada']) {
                    $resultado = 'irregularidad_reportada';
                }
            }
            $id = DB::table('verificacion_stock')->insertGetId([
                'area_id' => $data['area_id'], 'usuario_id' => $request->user()->id, 'fecha_hora' => now(),
                'resultado' => $resultado, 'observacion' => $data['observacion'] ?? null,
                'sincronizado' => true, 'fecha_ultima_modificacion' => now(), 'created_at' => now(), 'updated_at' => now(),
            ]);
            foreach ($data['detalles'] as $detalle) {
                DB::table('detalle_verificacion_stock')->insert([
                    'verificacion_stock_id' => $id, 'tipo_prenda_id' => $detalle['tipo_prenda_id'],
                    'cantidad_esperada' => $stocks[$detalle['tipo_prenda_id']] ?? 0, 'cantidad_contada' => $detalle['cantidad_contada'],
                    'created_at' => now(), 'updated_at' => now(),
                ]);
            }

            return $id;
        });

        return response()->json(['id' => $verificacion, 'resultado' => $resultado], 201);
    }
}
