<?php

namespace Database\Seeders;

use App\Domain\Stock\Models\Area;
use App\Domain\Stock\Models\StockArea;
use App\Domain\Stock\Models\TipoPrenda;
use Illuminate\Database\Seeder;

class StockPilotoSeeder extends Seeder
{
    /**
     * Datos de validación del Sprint 1 confirmados por el usuario.
     * Los valores de Quirófano, excepto Campo Grande, son de prueba fijos
     * dentro del rango acordado de 25 a 55; no son inventario oficial.
     */
    public function run(): void
    {
        $piloto = [
            'Cirugía Varones' => [
                'Sábanas Superiores' => 40,
                'Fundas' => 40,
            ],
            'Quirófano' => [
                'Campo Grande (C. GRANDE)' => 30,
                'Batas (Quirófano)' => 42,
                'Funda Mayo' => 28,
                'F.M.' => 47,
                'Precampo (P. PRECAMPO)' => 35,
                'Compresa' => 55,
                'A. Grande' => 31,
                'A. Simple' => 44,
                'Sábana (Quirófano)' => 50,
                'Sabanilla' => 26,
                'Campo Paciente (C. PACIENTE)' => 38,
                'Campo Anestesiólogo (C. ANESTESIO)' => 46,
                'Bata Celeste' => 33,
                'Hule' => 29,
                'Frazada' => 41,
                'Pechera' => 52,
                'Sixto' => 27,
                'Pijamas' => 48,
                'Inmovilizador' => 36,
            ],
        ];

        foreach ($piloto as $nombreArea => $prendas) {
            $area = Area::query()->where('nombre', $nombreArea)->firstOrFail();
            foreach ($prendas as $nombrePrenda => $cantidad) {
                $prenda = TipoPrenda::query()->where('nombre', $nombrePrenda)->firstOrFail();
                StockArea::query()->updateOrCreate(
                    ['area_id' => $area->id, 'tipo_prenda_id' => $prenda->id],
                    [
                        'cantidad_total' => $cantidad,
                        'cantidad_en_area' => $cantidad,
                        'cantidad_en_lavanderia' => 0,
                    ],
                );
            }
        }
    }
}
