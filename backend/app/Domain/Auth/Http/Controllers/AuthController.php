<?php

namespace App\Domain\Auth\Http\Controllers;

use App\Domain\Usuarios\Models\Usuario;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;

class AuthController
{
    public function login(Request $request): JsonResponse
    {
        $credentials = $request->validate([
            'numero_item' => ['required', 'string', 'regex:/^[0-9]{1,10}$/'],
            'password' => ['required', 'string'],
        ]);

        $usuario = Usuario::query()
            ->with('rol')
            ->where('numero_item', $credentials['numero_item'])
            ->first();

        if ($usuario === null || ! $usuario->activo) {
            return $this->invalidCredentials();
        }

        if ($usuario->bloqueado_hasta !== null && $usuario->bloqueado_hasta->isFuture()) {
            return response()->json([
                'message' => 'Cuenta bloqueada por intentos fallidos. Contacte al Super Admin.',
            ], 423);
        }

        if (! Hash::check($credentials['password'], $usuario->password_hash)) {
            $usuario->intentos_fallidos++;

            if ($usuario->intentos_fallidos >= 5) {
                $usuario->bloqueado_hasta = now()->addMinutes(5);
                $usuario->save();

                return response()->json([
                    'message' => 'Cuenta bloqueada por intentos fallidos. Contacte al Super Admin.',
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
            'password_nueva' => [
                'required',
                'string',
                'min:8',
                'max:30',
                'confirmed',
                'regex:/[A-Z]/',
                'regex:/[a-z]/',
                'regex:/[0-9]/',
                'regex:/[^A-Za-z0-9]/',
            ],
        ]);

        /** @var Usuario $usuario */
        $usuario = $request->user();
        $usuario->forceFill([
            'password_hash' => Hash::make($data['password_nueva']),
            'debe_cambiar_password' => false,
        ])->save();

        return response()->json([
            'message' => 'Contraseña actualizada correctamente.',
            'usuario' => $this->usuarioResponse($usuario->load('rol')),
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
            'debe_cambiar_password' => $usuario->debe_cambiar_password,
        ];
    }
}
