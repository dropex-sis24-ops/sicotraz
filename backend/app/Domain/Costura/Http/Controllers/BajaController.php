<?php

namespace App\Domain\Costura\Http\Controllers;

use App\Domain\Costura\Models\Baja;
use App\Domain\Stock\Models\StockArea;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

class BajaController
{
    private const MOTIVOS = [
        'Rota / rasgada',
        'Manchada sin arreglo',
        'Desgastada por uso',
        'Costura descosida sin reparación posible',
        'Perdida',
        'Quemada',
        'Otro',
    ];

    // RF21–RF23 — baja permanente y reducción atómica del stock del área.
    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'area_id' => ['required', 'exists:area,id'],
            'tipo_prenda_id' => ['required', 'exists:tipo_prenda,id'],
            'cantidad' => ['required', 'integer', 'min:1', 'max:999'],
            'motivo' => ['required', Rule::in(self::MOTIVOS)],
            'descripcion' => ['nullable', 'required_if:motivo,Otro', 'string', 'max:1000'],
            'foto_evidencia_url' => ['nullable', 'string', 'max:2048'],
            'uuid_local' => ['nullable', 'uuid'],
        ]);

        $baja = DB::transaction(function () use ($data, $request): Baja {
            $stock = StockArea::query()->lockForUpdate()->where([
                'area_id' => $data['area_id'],
                'tipo_prenda_id' => $data['tipo_prenda_id'],
            ])->first();
            if ($stock === null || $stock->cantidad_total < $data['cantidad']) {
                abort(422, 'No existe stock suficiente para registrar la baja.');
            }

            $restante = $data['cantidad'];
            $desdeArea = min($restante, $stock->cantidad_en_area);
            $stock->cantidad_en_area -= $desdeArea;
            $restante -= $desdeArea;
            if ($restante > $stock->cantidad_en_lavanderia) {
                abort(422, 'La distribución actual del stock no permite registrar la baja.');
            }
            $stock->cantidad_en_lavanderia -= $restante;
            $stock->cantidad_total -= $data['cantidad'];
            $stock->save();

            $ahora = now('America/La_Paz');

            return Baja::query()->create([
                ...$data,
                'usuario_costura_id' => $request->user()->id,
                'fecha_hora' => $ahora,
                'sincronizado' => true,
                'fecha_ultima_modificacion' => $ahora,
                'uuid_local' => $data['uuid_local'] ?? null,
            ]);
        });

        return response()->json($baja->load(['area', 'tipoPrenda', 'usuarioCostura']), 201);
    }

    public function index(Request $request): JsonResponse
    {
        $data = $request->validate(['usuario_id' => ['nullable', 'exists:usuario,id']]);
        $usuario = $request->user();
        $esCostura = $usuario->rol?->nombre === 'Costura';

        $bajas = Baja::query()
            ->with(['area', 'tipoPrenda', 'usuarioCostura'])
            ->when($esCostura, fn ($query) => $query->where('usuario_costura_id', $usuario->id))
            ->when(! $esCostura && isset($data['usuario_id']), fn ($query) => $query->where('usuario_costura_id', $data['usuario_id']))
            ->latest('fecha_hora')
            ->paginate($request->integer('per_page', 20));

        return response()->json($bajas);
    }
}
