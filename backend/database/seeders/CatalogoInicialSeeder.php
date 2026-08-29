<?php

namespace Database\Seeders;

use App\Domain\Stock\Models\AliasArea;
use App\Domain\Stock\Models\Area;
use App\Domain\Stock\Models\PlantillaFormulario;
use App\Domain\Stock\Models\TipoPrenda;
use Illuminate\Database\Seeder;
use Illuminate\Support\Str;

class CatalogoInicialSeeder extends Seeder
{
    public function run(): void
    {
        foreach (['Cubrecamas', 'Sábanas Superiores', 'Sábanas Inferiores', 'Fundas', 'Sabanilla', 'Camisa', 'Hule', 'Frazada', 'Inmovilizador', 'Almohadas', 'Colchonetas', 'Cortina', 'Bata Médica', 'Saco', 'Pantalón', 'Toalla de Enf.', 'Secador', 'Campo Grande (C. GRANDE)', 'Batas (Quirófano)', 'Funda Mayo', 'F.M.', 'Precampo (P. PRECAMPO)', 'Compresa', 'A. Grande', 'A. Simple', 'Sábana (Quirófano)', 'Campo Paciente (C. PACIENTE)', 'Campo Anestesiólogo (C. ANESTESIO)', 'Bata Celeste', 'Pechera', 'Sixto', 'Pijamas'] as $nombre) {
            TipoPrenda::query()->firstOrCreate(['nombre' => $nombre]);
        }
        $areas = ['Neurocirugía' => ['NC', 'N.C.'], 'Cirugía Mujeres' => ['C.M.'], 'Cirugía Varones' => ['C.V.', 'CV'], 'Medicina Mujeres' => ['M.M.'], 'Medicina Varones' => ['M.V.'], 'Infectología' => ['Infecto'], 'Oncología' => ['Onco'], 'Terapia Intensiva' => ['UTI'], 'Terapia Intermedia' => ['UCI'], 'Transplante Renal' => ['T.R.'], 'Emergencia' => ['E.M.G.', 'EMG', 'Emergencia'], 'Quirófano' => ['Quirofano']];
        foreach ($areas as $nombre => $aliases) {
            $area = Area::query()->firstOrCreate(['nombre' => $nombre]);
            foreach ($aliases as $alias) {
                AliasArea::query()->firstOrCreate(['area_id' => $area->id, 'alias_normalizado' => preg_replace('/[^A-Z0-9]+/', '', Str::upper(Str::ascii($alias)))]);
            }
        }

        PlantillaFormulario::query()->firstOrCreate(
            ['nombre' => 'Salas'],
            ['estructura_campos' => ['tipo' => 'salas', 'campos' => []], 'activo' => true],
        );
        PlantillaFormulario::query()->firstOrCreate(
            ['nombre' => 'Quirófano'],
            ['estructura_campos' => ['tipo' => 'quirofano', 'campos' => []], 'activo' => true],
        );
    }
}
