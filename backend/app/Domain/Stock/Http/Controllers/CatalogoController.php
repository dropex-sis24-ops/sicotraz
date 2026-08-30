<?php

namespace App\Domain\Stock\Http\Controllers;

use App\Domain\Stock\Models\AliasArea;
use App\Domain\Stock\Models\Area;
use App\Domain\Stock\Models\PlantillaFormulario;
use App\Domain\Stock\Models\TipoPrenda;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class CatalogoController
{
    public function prendas(Request $request): JsonResponse
    {
        $data = $request->validate(['area_id' => ['nullable', 'exists:area,id']]);
        $query = TipoPrenda::query()->orderBy('nombre');
        if (isset($data['area_id'])) {
            $area = Area::query()->findOrFail($data['area_id']);
            $plantilla = PlantillaFormulario::query()
                ->where('nombre', $area->nombre === 'Quirófano' ? 'Quirófano' : 'Salas')
                ->first();
            $nombres = $plantilla?->estructura_campos['tipos_prenda'] ?? [];
            $query->whereIn('nombre', $nombres);
        }

        return response()->json($query->get());
    }

    public function crearPrenda(Request $request): JsonResponse
    {
        $p = TipoPrenda::query()->create($request->validate(['nombre' => ['required', 'string', 'max:255', 'unique:tipo_prenda,nombre']]));

        return response()->json($p->fresh(), 201);
    }

    public function actualizarPrenda(Request $request, TipoPrenda $prenda): JsonResponse
    {
        $prenda->update($request->validate(['nombre' => ['sometimes', 'required', 'string', 'max:255'], 'activo' => ['sometimes', 'boolean']]));

        return response()->json($prenda->fresh());
    }

    public function areas(): JsonResponse
    {
        return response()->json(Area::query()->with('aliases')->orderBy('nombre')->get());
    }

    public function crearArea(Request $request): JsonResponse
    {
        $a = Area::query()->create($request->validate(['nombre' => ['required', 'string', 'max:255', 'unique:area,nombre']]));

        return response()->json($a->fresh(), 201);
    }

    public function actualizarArea(Request $request, Area $area): JsonResponse
    {
        $area->update($request->validate(['nombre' => ['sometimes', 'required', 'string', 'max:255'], 'activo' => ['sometimes', 'boolean']]));

        return response()->json($area->fresh());
    }

    public function crearAlias(Request $request, Area $area): JsonResponse
    {
        $data = $request->validate(['alias' => ['required', 'string', 'max:255']]);
        $alias = AliasArea::query()->create(['area_id' => $area->id, 'alias_normalizado' => $this->normalizar($data['alias']), 'activo' => true]);

        return response()->json($alias, 201);
    }

    public function actualizarAlias(Request $request, AliasArea $alias): JsonResponse
    {
        $data = $request->validate(['alias' => ['sometimes', 'required', 'string', 'max:255'], 'activo' => ['sometimes', 'boolean']]);
        if (isset($data['alias'])) {
            $data['alias_normalizado'] = $this->normalizar($data['alias']);
        } unset($data['alias']);
        $alias->update($data);

        return response()->json($alias->fresh());
    }

    public function plantillas(): JsonResponse
    {
        return response()->json(PlantillaFormulario::query()->orderBy('nombre')->get());
    }

    public function actualizarPlantilla(Request $request, PlantillaFormulario $plantilla): JsonResponse
    {
        $data = $request->validate([
            'estructura_campos' => ['sometimes', 'required', 'array'],
            'activo' => ['sometimes', 'boolean'],
        ]);
        $plantilla->update($data);

        return response()->json($plantilla->fresh());
    }

    private function normalizar(string $value): string
    {
        return preg_replace('/[^A-Z0-9]+/', '', Str::upper(Str::ascii($value))) ?: '';
    }
}
