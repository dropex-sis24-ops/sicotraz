<?php

namespace App\Domain\Alertas\Http\Controllers;

use App\Domain\Alertas\Models\Alerta;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AlertaController
{
    // RF13–RF15 — registrar y resolver discrepancias dentro de la app.
    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'area_id' => ['nullable', 'exists:area,id'],
            'tipo_prenda_id' => ['required', 'exists:tipo_prenda,id'],
            'descripcion' => ['required', 'string', 'min:3'],
            'foto_evidencia_url' => ['nullable', 'string', 'max:2048'],
            'uuid_local' => ['nullable', 'uuid'],
        ]);
        $usuario = $request->user();
        $areaId = $data['area_id'] ?? $usuario->area_id;
        if ($areaId === null) {
            abort(422, 'Debe indicar un área para registrar la alerta.');
        }
        if ($usuario->rol?->nombre === 'Personal manual' && $areaId !== $usuario->area_id) {
            abort(403, 'Solo puede reportar alertas de su área asignada.');
        }

        $alerta = Alerta::query()->create([
            'area_id' => $areaId,
            'tipo_prenda_id' => $data['tipo_prenda_id'],
            'usuario_reporta_id' => $usuario->id,
            'fecha_hora_reporte' => now('America/La_Paz'),
            'descripcion' => $data['descripcion'],
            'foto_evidencia_url' => $data['foto_evidencia_url'] ?? null,
            'estado' => 'pendiente',
            'sincronizado' => true,
            'fecha_ultima_modificacion' => now('America/La_Paz'),
            'uuid_local' => $data['uuid_local'] ?? null,
        ]);

        return response()->json($this->cargar($alerta), 201);
    }

    public function index(Request $request): JsonResponse
    {
        $data = $request->validate(['estado' => ['nullable', 'in:pendiente,resuelta']]);

        return response()->json(Alerta::query()
            ->with(['area', 'tipoPrenda', 'reporta', 'resuelve'])
            ->when($data['estado'] ?? null, fn ($query, $estado) => $query->where('estado', $estado))
            ->latest('fecha_hora_reporte')
            ->paginate($request->integer('per_page', 20)));
    }

    public function resolver(Request $request, Alerta $alerta): JsonResponse
    {
        if ($alerta->estado === 'resuelta') {
            abort(422, 'La alerta ya fue resuelta.');
        }
        $data = $request->validate(['nota_resolucion' => ['nullable', 'string']]);
        $alerta->update([
            'estado' => 'resuelta',
            'usuario_resuelve_id' => $request->user()->id,
            'fecha_resolucion' => now('America/La_Paz'),
            'nota_resolucion' => $data['nota_resolucion'] ?? null,
            'fecha_ultima_modificacion' => now('America/La_Paz'),
        ]);

        return response()->json($this->cargar($alerta));
    }

    private function cargar(Alerta $alerta): Alerta
    {
        return $alerta->load(['area', 'tipoPrenda', 'reporta', 'resuelve']);
    }
}
