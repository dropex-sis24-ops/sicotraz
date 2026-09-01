<?php

namespace App\Domain\Usuarios\Http\Controllers;

use App\Domain\Usuarios\Models\Rol;
use App\Domain\Usuarios\Models\Usuario;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rule;

class UsuarioController
{
    public function index(Request $request): JsonResponse
    {
        $usuarios = Usuario::query()->with(['rol', 'area'])
            ->when($request->string('buscar')->isNotEmpty(), function ($query) use ($request): void {
                $buscar = $request->string('buscar')->toString();
                $query->where(fn ($q) => $q->where('nombre', 'like', "%{$buscar}%")->orWhere('numero_item', 'like', "%{$buscar}%"));
            })->paginate($request->integer('per_page', 20));

        return response()->json($usuarios);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'nombre' => ['required', 'string', 'max:255'],
            'numero_item' => ['required', 'regex:/^[0-9]{1,10}$/', 'unique:usuario,numero_item'],
            'carnet_identidad' => ['required', 'string', 'max:255'],
            'rol_id' => ['required', 'exists:rol,id'],
            'area_id' => ['nullable', 'exists:area,id'],
        ]);
        $this->validarAreaPersonalManual($data);
        $data['password_hash'] = Hash::make($data['carnet_identidad']);
        $data['debe_cambiar_password'] = true;
        $data['activo'] = true;

        $usuario = Usuario::query()->create($data)->load(['rol', 'area']);

        return response()->json($usuario, 201);
    }

    public function update(Request $request, Usuario $usuario): JsonResponse
    {
        $data = $request->validate([
            'nombre' => ['sometimes', 'required', 'string', 'max:255'],
            'numero_item' => ['sometimes', 'required', 'regex:/^[0-9]{1,10}$/', Rule::unique('usuario', 'numero_item')->ignore($usuario->id)],
            'carnet_identidad' => ['sometimes', 'required', 'string', 'max:255'],
            'rol_id' => ['sometimes', 'required', 'exists:rol,id'],
            'area_id' => ['sometimes', 'nullable', 'exists:area,id'],
        ]);
        $this->validarAreaPersonalManual($data, $usuario);
        $carnetCambio = isset($data['carnet_identidad'])
            && $data['carnet_identidad'] !== $usuario->carnet_identidad;
        if ($carnetCambio) {
            $data['password_hash'] = Hash::make($data['carnet_identidad']);
            $data['debe_cambiar_password'] = true;
            $data['intentos_fallidos'] = 0;
            $data['bloqueado_hasta'] = null;
        }
        $usuario->update($data);
        if ($carnetCambio) {
            $usuario->tokens()->delete();
        }

        return response()->json($usuario->fresh()->load(['rol', 'area']));
    }

    public function desactivar(Usuario $usuario): JsonResponse
    {
        $usuario->update(['activo' => false]);
        $usuario->tokens()->delete();

        return response()->json($usuario->fresh());
    }

    public function reactivar(Usuario $usuario): JsonResponse
    {
        $usuario->update(['activo' => true]);

        return response()->json($usuario->fresh());
    }

    public function desbloquear(Usuario $usuario): JsonResponse
    {
        $usuario->update(['intentos_fallidos' => 0, 'bloqueado_hasta' => null]);

        return response()->json($usuario->fresh());
    }

    public function resetearPassword(Usuario $usuario): JsonResponse
    {
        $usuario->update([
            'password_hash' => Hash::make($usuario->carnet_identidad),
            'debe_cambiar_password' => true,
            'intentos_fallidos' => 0,
            'bloqueado_hasta' => null,
        ]);
        $usuario->tokens()->delete();

        return response()->json(['message' => 'Contraseña restablecida correctamente.']);
    }

    public function destroy(Request $request, Usuario $usuario): JsonResponse
    {
        abort_if($request->user()->is($usuario), 422, 'No puede eliminar su propia cuenta.');
        abort_if($this->tieneHistorial($usuario), 422, 'El usuario tiene historial operativo y no puede eliminarse. Desactívelo para conservar la trazabilidad.');

        DB::transaction(function () use ($usuario): void {
            $usuario->tokens()->delete();
            $usuario->delete();
        });

        return response()->json(['message' => 'Usuario eliminado correctamente.']);
    }

    /** @param array<string, mixed> $data */
    private function validarAreaPersonalManual(array $data, ?Usuario $usuario = null): void
    {
        $rolId = $data['rol_id'] ?? $usuario?->rol_id;
        $esPersonalManual = Rol::query()->whereKey($rolId)->value('nombre') === 'Personal manual';
        $areaId = $data['area_id'] ?? $usuario?->area_id;

        if ($esPersonalManual && $areaId === null) {
            abort(422, 'El Personal manual debe tener un área asignada.');
        }
    }

    private function tieneHistorial(Usuario $usuario): bool
    {
        $referencias = [
            'lote' => ['usuario_entrega_id', 'usuario_registra_id', 'usuario_recibe_id'],
            'movimiento_lote' => ['usuario_id'],
            'verificacion_stock' => ['usuario_id'],
            'alerta' => ['usuario_reporta_id', 'usuario_resuelve_id'],
            'baja' => ['usuario_costura_id'],
            'conflicto_sincronizacion' => ['resuelto_por_id'],
        ];
        foreach ($referencias as $tabla => $columnas) {
            foreach ($columnas as $columna) {
                if (DB::table($tabla)->where($columna, $usuario->id)->exists()) {
                    return true;
                }
            }
        }

        return false;
    }
}
