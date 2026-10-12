<?php

namespace App\Domain\Auth\Http\Controllers;

use App\Domain\Usuarios\Models\Usuario;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;

class AuthController
{
    public function login(Request $request): JsonResponse
    {
        $credentials = $request->validate([
            'numero_item' => ['required', 'string', 'regex:/^[0-9]{1,10}$/'],
            'password' => ['required', 'string'],
        ]);

        $usuario = Usuario::query()
            ->with(['rol', 'area'])
            ->where('numero_item', $credentials['numero_item'])
            ->first();

        if ($usuario === null || ! $usuario->activo) {
            return $this->invalidCredentials();
        }

        if ($usuario->bloqueado_hasta !== null) {
            if ($usuario->bloqueado_hasta->isFuture()) {
                return response()->json([
                    'message' => 'Cuenta bloqueada temporalmente por intentos fallidos. Intente de nuevo en '
                        .$usuario->bloqueado_hasta->diffForHumans(['parts' => 1, 'short' => true])
                        .' o solicite el desbloqueo al Super Admin.',
                    'bloqueado_hasta' => $usuario->bloqueado_hasta->toIso8601String(),
                ], 423);
            }
            $usuario->forceFill(['intentos_fallidos' => 0, 'bloqueado_hasta' => null])->save();
        }

        if (! Hash::check($credentials['password'], $usuario->password_hash)) {
            $usuario->intentos_fallidos++;

            if ($usuario->intentos_fallidos >= 5) {
                $usuario->bloqueado_hasta = now()->addMinutes(5);
                $usuario->save();

                return response()->json([
                    'message' => 'Cuenta bloqueada por 5 intentos fallidos. Intente de nuevo en 5 minutos '
                        .'o solicite el desbloqueo al Super Admin.',
                    'bloqueado_hasta' => $usuario->bloqueado_hasta->toIso8601String(),
                ], 423);
            }

            $usuario->save();

            return $this->invalidCredentials();
        }

        $usuario->forceFill([
            'intentos_fallidos' => 0,
            'bloqueado_hasta' => null,
        ])->save();

        return response()->json([
            'token' => $usuario->createToken('mobile')->plainTextToken,
            'usuario' => $this->usuarioResponse($usuario),
            'debe_cambiar_password' => $usuario->debe_cambiar_password,
        ]);
    }

    public function cambiarPassword(Request $request): JsonResponse
    {
        $data = $request->validate([
            'password_actual' => ['required', 'string'],
            'password_nueva' => [
                'required',
                'string',
                'min:8',
                'max:30',
                'confirmed',
                'different:password_actual',
                'regex:/[A-Z]/',
                'regex:/[a-z]/',
                'regex:/[0-9]/',
                'regex:/[^A-Za-z0-9]/',
            ],
        ]);

        /** @var Usuario $usuario */
        $usuario = $request->user();

        if (! Hash::check($data['password_actual'], $usuario->password_hash)) {
            throw ValidationException::withMessages([
                'password_actual' => 'La contraseña actual no es correcta.',
            ]);
        }

        $tokenActual = $usuario->currentAccessToken()?->getKey();
        $usuario->forceFill([
            'password_hash' => Hash::make($data['password_nueva']),
            'debe_cambiar_password' => false,
        ])->save();
        // Al cambiar la contraseña caducan las sesiones abiertas en otros equipos.
        $usuario->tokens()->when($tokenActual !== null, fn ($q) => $q->whereKeyNot($tokenActual))->delete();

        return response()->json([
            'message' => 'Contraseña actualizada correctamente.',
            'usuario' => $this->usuarioResponse($usuario->load(['rol', 'area'])),
        ]);
    }

    public function logout(Request $request): JsonResponse
    {
        $request->user()?->currentAccessToken()?->delete();

        return response()->json(status: 204);
    }

    private function invalidCredentials(): JsonResponse
    {
        return response()->json([
            'message' => 'N° de ítem o contraseña incorrectos.',
        ], 401);
    }

    private function usuarioResponse(Usuario $usuario): array
    {
        return [
            'id' => $usuario->id,
            'nombre' => $usuario->nombre,
            'numero_item' => $usuario->numero_item,
            'rol' => $usuario->rol?->nombre,
            'area_id' => $usuario->area_id,
            'area_nombre' => $usuario->area?->nombre,
            'debe_cambiar_password' => $usuario->debe_cambiar_password,
        ];
    }
}
