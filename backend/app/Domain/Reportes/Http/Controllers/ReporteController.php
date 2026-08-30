<?php

namespace App\Domain\Reportes\Http\Controllers;

use App\Domain\Alertas\Models\Alerta;
use App\Domain\Costura\Models\Baja;
use App\Domain\Movimientos\Models\MovimientoLote;
use App\Domain\Stock\Models\Area;
use App\Domain\Stock\Models\StockArea;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ReporteController
{
    // RF26 y RF45 — siete indicadores reales y control agregado por área.
    public function dashboard(): JsonResponse
    {
        $ahora = now('America/La_Paz');
        $inicioMes = $ahora->copy()->startOfMonth();
        $movimientosSemana = $this->movimientosLavado($ahora->copy()->startOfWeek(), $ahora);
        $movimientosMes = $this->movimientosLavado($inicioMes, $ahora);
        $alertasMes = Alerta::query()->with('area')
            ->whereBetween('fecha_hora_reporte', [$inicioMes, $ahora])->get();
        $bajasMes = Baja::query()->with('tipoPrenda')
            ->whereBetween('fecha_hora', [$inicioMes, $ahora])->get();

        $areaMasAlertas = $alertasMes->groupBy('area_id')->sortByDesc->count()->first();
        $prendaMasBajas = $bajasMes->groupBy('tipo_prenda_id')
            ->sortByDesc(fn ($items) => $items->sum('cantidad'))->first();

        $totalesPorArea = Area::query()->with('stocks')->orderBy('nombre')->get()->map(fn (Area $area) => [
            'area_id' => $area->id,
            'area' => $area->nombre,
            'cantidad_total' => $area->stocks->sum('cantidad_total'),
            'cantidad_en_area' => $area->stocks->sum('cantidad_en_area'),
            'cantidad_en_lavanderia' => $area->stocks->sum('cantidad_en_lavanderia'),
        ])->values();

        return response()->json([
            'alertas_pendientes_hoy' => Alerta::query()->where('estado', 'pendiente')->whereDate('fecha_hora_reporte', $ahora->toDateString())->count(),
            'lavado_semana_cantidad' => $this->cantidadPrendas($movimientosSemana),
            'lavado_mes_cantidad' => $this->cantidadPrendas($movimientosMes),
            'bajas_mes' => $bajasMes->sum('cantidad'),
            'ropa_circulando' => StockArea::query()->sum('cantidad_en_lavanderia'),
            'area_mas_alertas_mes' => $areaMasAlertas ? [
                'nombre' => $areaMasAlertas->first()->area?->nombre,
                'cantidad' => $areaMasAlertas->count(),
            ] : null,
            'prenda_mas_bajas_mes' => $prendaMasBajas ? [
                'nombre' => $prendaMasBajas->first()->tipoPrenda?->nombre,
                'cantidad' => $prendaMasBajas->sum('cantidad'),
            ] : null,
            'totales_por_area' => $totalesPorArea,
        ]);
    }

    public function circulando(): JsonResponse
    {
        return response()->json(['total' => StockArea::query()->sum('cantidad_en_lavanderia')]);
    }

    // RF25 — reporte de solo lectura agrupado por día o mes.
    public function cantidadPeso(Request $request): JsonResponse
    {
        $data = $request->validate([
            'desde' => ['nullable', 'date'],
            'hasta' => ['nullable', 'date', 'after_or_equal:desde'],
            'periodo' => ['nullable', 'in:diario,mensual'],
        ]);
        $desde = isset($data['desde']) ? Carbon::parse($data['desde'], 'America/La_Paz')->startOfDay() : now('America/La_Paz')->startOfMonth();
        $hasta = isset($data['hasta']) ? Carbon::parse($data['hasta'], 'America/La_Paz')->endOfDay() : now('America/La_Paz')->endOfDay();
        $formato = ($data['periodo'] ?? 'diario') === 'mensual' ? 'Y-m' : 'Y-m-d';
        $movimientos = $this->movimientosLavado($desde, $hasta);

        $grupos = $movimientos->groupBy(fn (MovimientoLote $movimiento) => $movimiento->fecha_hora->format($formato))
            ->map(fn ($items, $periodo) => [
                'periodo' => $periodo,
                'lotes' => $items->count(),
                'cantidad_prendas' => $this->cantidadPrendas($items),
                'peso_kg' => round($items->sum(fn (MovimientoLote $movimiento) => (float) $movimiento->lote->peso_kg), 2),
            ])->values();

        return response()->json([
            'desde' => $desde->toDateString(),
            'hasta' => $hasta->toDateString(),
            'agrupacion' => $data['periodo'] ?? 'diario',
            'totales' => [
                'lotes' => $movimientos->count(),
                'cantidad_prendas' => $this->cantidadPrendas($movimientos),
                'peso_kg' => round($movimientos->sum(fn (MovimientoLote $movimiento) => (float) $movimiento->lote->peso_kg), 2),
            ],
            'detalle' => $grupos,
        ]);
    }

    // RF24 y RF27 — bajas y faltantes se mantienen como conceptos separados.
    public function bajasVsFaltantes(Request $request): JsonResponse
    {
        $data = $request->validate([
            'desde' => ['nullable', 'date'],
            'hasta' => ['nullable', 'date', 'after_or_equal:desde'],
        ]);
        $desde = isset($data['desde']) ? Carbon::parse($data['desde'], 'America/La_Paz')->startOfDay() : now('America/La_Paz')->startOfMonth();
        $hasta = isset($data['hasta']) ? Carbon::parse($data['hasta'], 'America/La_Paz')->endOfDay() : now('America/La_Paz')->endOfDay();
        $bajas = Baja::query()->with(['area', 'tipoPrenda'])
            ->whereBetween('fecha_hora', [$desde, $hasta])->get();
        $faltantes = Alerta::query()->with(['area', 'tipoPrenda'])
            ->where('estado', 'pendiente')
            ->whereBetween('fecha_hora_reporte', [$desde, $hasta])->get();

        $areas = Area::query()->orderBy('nombre')->get()->map(function (Area $area) use ($bajas, $faltantes): array {
            return [
                'area_id' => $area->id,
                'area' => $area->nombre,
                'bajas_confirmadas' => $bajas->where('area_id', $area->id)->sum('cantidad'),
                'faltantes_pendientes' => $faltantes->where('area_id', $area->id)->count(),
            ];
        })->filter(fn (array $area) => $area['bajas_confirmadas'] > 0 || $area['faltantes_pendientes'] > 0)
            ->sortByDesc('bajas_confirmadas')->values();

        return response()->json([
            'bajas_confirmadas' => [
                'cantidad' => $bajas->sum('cantidad'),
                'registros' => $bajas,
            ],
            'faltantes_sin_resolver' => [
                'cantidad_alertas' => $faltantes->count(),
                'registros' => $faltantes,
            ],
            'areas_con_disminucion' => $areas,
        ]);
    }

    private function movimientosLavado(Carbon $desde, Carbon $hasta)
    {
        return MovimientoLote::query()->with('lote.detalles')
            ->where('etapa', 'en_lavado')
            ->whereBetween('fecha_hora', [$desde, $hasta])
            ->get()->unique('lote_id')->values();
    }

    private function cantidadPrendas($movimientos): int
    {
        return $movimientos->sum(fn (MovimientoLote $movimiento) => $movimiento->lote->detalles->sum('cantidad'));
    }
}
