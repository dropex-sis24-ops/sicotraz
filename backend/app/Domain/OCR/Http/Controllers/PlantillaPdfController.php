<?php

namespace App\Domain\OCR\Http\Controllers;

use App\Domain\Stock\Models\Area;
use App\Domain\Stock\Models\PlantillaFormulario;
use Barryvdh\DomPDF\Facade\Pdf;
use Illuminate\Http\Request;

class PlantillaPdfController
{
    // RF44 — formato físico reutilizable, disponible para Super Admin y Encargado.
    public function descargar(Request $request)
    {
        $data = $request->validate([
            'plantilla' => ['required', 'in:Salas,Quirófano'],
            'area_id' => ['nullable', 'exists:area,id'],
        ]);
        $plantilla = PlantillaFormulario::query()->where('nombre', $data['plantilla'])->firstOrFail();
        $area = isset($data['area_id']) ? Area::query()->findOrFail($data['area_id']) : null;

        return Pdf::loadView('pdf.plantilla', [
            'plantilla' => $plantilla,
            'area' => $area,
            'prendas' => $plantilla->estructura_campos['tipos_prenda'] ?? [],
        ])->setPaper('a4')->download('plantilla-'.strtolower(str_replace('ó', 'o', $plantilla->nombre)).'.pdf');
    }
}
