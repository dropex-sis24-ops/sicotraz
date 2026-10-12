<?php

namespace App\Http\Controllers;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ArchivoController
{
    public const PREFIJO_PUBLICO = '/storage/';

    /**
     * Las evidencias solo pueden apuntar a un archivo subido por esta API: un
     * campo de texto libre permitía guardar enlaces externos arbitrarios.
     */
    public static function reglasEvidencia(): array
    {
        return ['nullable', 'string', 'max:2048', 'regex:/^\/storage\/(alertas|bajas)\/[A-Za-z0-9._-]+$/'];
    }

    // RF14 y RF22 — evidencia fotográfica opcional de alertas o bajas.
    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'foto' => ['required', 'image', 'mimes:jpg,jpeg,png,webp', 'max:5120'],
            'categoria' => ['nullable', 'in:alertas,bajas'],
        ]);

        $path = $request->file('foto')->store($data['categoria'] ?? 'alertas', 'public');

        return response()->json([
            'url' => self::PREFIJO_PUBLICO.$path,
        ], 201);
    }
}
