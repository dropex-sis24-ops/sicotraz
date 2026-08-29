<?php

namespace App\Http\Controllers;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ArchivoController
{
    // RF14 — evidencia fotográfica opcional adjunta a una alerta.
    public function store(Request $request): JsonResponse
    {
        $request->validate([
            'foto' => ['required', 'image', 'mimes:jpg,jpeg,png,webp', 'max:5120'],
        ]);

        $path = $request->file('foto')->store('alertas', 'public');

        return response()->json([
            'url' => '/storage/'.$path,
        ], 201);
    }
}
