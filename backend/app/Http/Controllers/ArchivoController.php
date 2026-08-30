<?php

namespace App\Http\Controllers;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ArchivoController
{
    // RF14 y RF22 — evidencia fotográfica opcional de alertas o bajas.
    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'foto' => ['required', 'image', 'mimes:jpg,jpeg,png,webp', 'max:5120'],
            'categoria' => ['nullable', 'in:alertas,bajas'],
        ]);

        $path = $request->file('foto')->store($data['categoria'] ?? 'alertas', 'public');

        return response()->json([
            'url' => '/storage/'.$path,
        ], 201);
    }
}
