<?php

namespace App\Domain\Auth\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureRole
{
    public function handle(Request $request, Closure $next, string ...$roles): Response
    {
        $usuario = $request->user();

        if ($usuario === null || ! in_array($usuario->rol?->nombre, $roles, true)) {
            return response()->json(['message' => 'No tiene permiso para realizar esta acción.'], 403);
        }

        return $next($request);
    }
}
