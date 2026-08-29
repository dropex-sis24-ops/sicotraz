<?php

namespace App\Console\Commands;

use App\Domain\Stock\Models\PlantillaFormulario;
use Barryvdh\DomPDF\Facade\Pdf;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\File;

class GenerarPlantillasPdf extends Command
{
    protected $signature = 'sicotraz:generar-plantillas {directorio?}';

    protected $description = 'Genera los formatos imprimibles de Salas y Quirófano';

    public function handle(): int
    {
        $directorio = $this->argument('directorio') ?: base_path('../output/pdf');
        File::ensureDirectoryExists($directorio);

        foreach (['Salas', 'Quirófano'] as $nombre) {
            $plantilla = PlantillaFormulario::query()->where('nombre', $nombre)->firstOrFail();
            $archivo = $nombre === 'Salas' ? 'plantilla-salas.pdf' : 'plantilla-quirofano.pdf';
            Pdf::loadView('pdf.plantilla', [
                'plantilla' => $plantilla,
                'area' => null,
                'prendas' => $plantilla->estructura_campos['tipos_prenda'] ?? [],
            ])->setPaper('a4')->save($directorio.'/'.$archivo);
            $this->info($archivo);
        }

        return self::SUCCESS;
    }
}
