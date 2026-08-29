<?php

namespace App\Domain\Stock\Http\Controllers;

use App\Domain\Stock\Models\Area;
use App\Domain\Stock\Models\StockArea;
use App\Domain\Stock\Models\TipoPrenda;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class StockController
{
    public function cargaInicial(Request $request): JsonResponse
    {
        $data = $request->validate([
            'area_id' => ['required', 'exists:area,id'],
            'tipo_prenda_id' => ['required', 'exists:tipo_prenda,id'],
            'cantidad' => ['required', 'integer', 'min:0', 'max:999'],
        ]);
        if (! Area::query()->whereKey($data['area_id'])->where('activo', true)->exists()
            || ! TipoPrenda::query()->whereKey($data['tipo_prenda_id'])->where('activo', true)->exists()) {
            abort(422, 'El área y la prenda deben estar activas para cargar stock.');
        }

        $stock = DB::transaction(function () use ($data) {
            $stock = StockArea::query()->lockForUpdate()->firstOrNew([
                'area_id' => $data['area_id'],
                'tipo_prenda_id' => $data['tipo_prenda_id'],
            ]);
            $nuevoTotal = $stock->cantidad_total + $data['cantidad'];

            if ($nuevoTotal > 999) {
                abort(422, 'La carga supera el máximo permitido de 999 prendas.');
            }

            $stock->cantidad_total = $nuevoTotal;
            $stock->cantidad_en_area += $data['cantidad'];
            $stock->cantidad_en_lavanderia ??= 0;
            $stock->save();

            return $stock;
        });

        return response()->json($stock, 201);
    }

    public function verificacion(Request $request): JsonResponse
    {
        $data = $request->validate(['area_id' => ['nullable', 'exists:area,id']]);
        $areaId = $data['area_id'] ?? $request->user()->area_id;
        if ($areaId === null) {
            abort(422, 'El usuario no tiene un área asignada.');
        }

        return response()->json(StockArea::query()
            ->with('tipoPrenda:id,nombre')
            ->where('area_id', $areaId)
            ->orderBy('tipo_prenda_id')
            ->get());
    }

    public function porArea(Request $request): JsonResponse
    {
        return $this->verificacion($request);
    }
}
