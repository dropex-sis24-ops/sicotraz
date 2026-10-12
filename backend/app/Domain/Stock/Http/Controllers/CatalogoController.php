<?php

namespace App\Domain\Stock\Http\Controllers;

use App\Domain\Stock\Models\AliasArea;
use App\Domain\Stock\Models\Area;
use App\Domain\Stock\Models\PlantillaFormulario;
use App\Domain\Stock\Models\TipoPrenda;
use App\Domain\Usuarios\Models\Rol;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;

class CatalogoController
{
    public function prendas(Request $request): JsonResponse
    {
        $data = $request->validate([
            'area_id' => ['nullable', 'exists:area,id'],
            'incluir_inactivas' => ['nullable', 'boolean'],
        ]);
        $query = TipoPrenda::query()->orderBy('nombre')
            ->unless($request->boolean('incluir_inactivas'), fn ($q) => $q->where('activo', true));
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
        $data = $request->validate([
            'nombre' => ['sometimes', 'required', 'string', 'max:255', Rule::unique('tipo_prenda', 'nombre')->ignore($prenda->id)],
            'activo' => ['sometimes', 'boolean'],
        ]);
        $nombreAnterior = $prenda->nombre;
        $renombra = isset($data['nombre']) && $data['nombre'] !== $nombreAnterior;

        DB::transaction(function () use ($prenda, $data, $renombra, $nombreAnterior): void {
            $prenda->update($data);
            // Las plantillas referencian las prendas por nombre: sin arrastrar
            // el cambio, renombrar una prenda la hacía desaparecer del formulario.
            if ($renombra) {
                $this->renombrarEnPlantillas($nombreAnterior, $data['nombre']);
            }
        });

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
        $data = $request->validate([
            'nombre' => ['sometimes', 'required', 'string', 'max:255', Rule::unique('area', 'nombre')->ignore($area->id)],
            'activo' => ['sometimes', 'boolean'],
        ]);

        // El horario automático, la plantilla y la ventana de corrección de
        // Quirófano se deciden por el nombre del área; renombrarla las anula.
        abort_if(
            $area->nombre === 'Quirófano' && isset($data['nombre']) && $data['nombre'] !== 'Quirófano',
            422,
            'El área Quirófano no puede renombrarse: de ella dependen el ingreso automático en horario y su plantilla.',
        );

        $area->update($data);

        return response()->json($area->fresh());
    }

    public function crearAlias(Request $request, Area $area): JsonResponse
    {
        $data = $request->validate(['alias' => ['required', 'string', 'max:255']]);
        $normalizado = $this->normalizar($data['alias']);
        abort_if($normalizado === '', 422, 'El alias debe contener al menos una letra o un número.');
        $this->validarAliasDisponible($normalizado);
        $alias = AliasArea::query()->create(['area_id' => $area->id, 'alias_normalizado' => $normalizado, 'activo' => true]);

        return response()->json($alias, 201);
    }

    public function actualizarAlias(Request $request, AliasArea $alias): JsonResponse
    {
        $data = $request->validate(['alias' => ['sometimes', 'required', 'string', 'max:255'], 'activo' => ['sometimes', 'boolean']]);
        if (isset($data['alias'])) {
            $normalizado = $this->normalizar($data['alias']);
            abort_if($normalizado === '', 422, 'El alias debe contener al menos una letra o un número.');
            $this->validarAliasDisponible($normalizado, $alias->id);
            $data['alias_normalizado'] = $normalizado;
        }
        unset($data['alias']);
        $alias->update($data);

        return response()->json($alias->fresh());
    }

    /**
     * Los roles son fijos (RF03) pero sus identificadores los asigna la base de
     * datos: la app los necesita para no deducirlos por posición.
     */
    public function roles(): JsonResponse
    {
        return response()->json(Rol::query()->orderBy('id')->get(['id', 'nombre']));
    }

    public function plantillas(): JsonResponse
    {
        return response()->json(PlantillaFormulario::query()->orderBy('nombre')->get());
    }

    public function actualizarPlantilla(Request $request, PlantillaFormulario $plantilla): JsonResponse
    {
        $data = $request->validate([
            'estructura_campos' => ['sometimes', 'required', 'array'],
            'estructura_campos.tipos_prenda' => ['required_with:estructura_campos', 'array', 'min:1'],
            'estructura_campos.tipos_prenda.*' => ['required', 'string', 'distinct', 'exists:tipo_prenda,nombre'],
            'activo' => ['sometimes', 'boolean'],
        ]);
        $plantilla->update($data);

        return response()->json($plantilla->fresh());
    }

    private function validarAliasDisponible(string $normalizado, ?int $ignorarId = null): void
    {
        $ocupado = AliasArea::query()
            ->where('alias_normalizado', $normalizado)
            ->when($ignorarId !== null, fn ($q) => $q->whereKeyNot($ignorarId))
            ->exists();

        abort_if($ocupado, 422, 'Ese alias ya está asignado a un área; el OCR no podría distinguirlas.');
    }

    private function renombrarEnPlantillas(string $anterior, string $nuevo): void
    {
        foreach (PlantillaFormulario::query()->get() as $plantilla) {
            $estructura = $plantilla->estructura_campos ?? [];
            $nombres = $estructura['tipos_prenda'] ?? [];
            if (! in_array($anterior, $nombres, true)) {
                continue;
            }
            $estructura['tipos_prenda'] = array_values(array_map(
                fn (string $nombre) => $nombre === $anterior ? $nuevo : $nombre,
                $nombres,
            ));
            $plantilla->update(['estructura_campos' => $estructura]);
        }
    }

    private function normalizar(string $value): string
    {
        return preg_replace('/[^A-Z0-9]+/', '', Str::upper(Str::ascii($value))) ?: '';
    }
}
