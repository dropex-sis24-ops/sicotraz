<?php

namespace Database\Seeders;

use App\Domain\Usuarios\Models\Rol;
use Illuminate\Database\Seeder;

class RolSeeder extends Seeder
{
    public function run(): void
    {
        foreach ([
            'Super Admin',
            'Encargado de Ropería y Lavandería',
            'Ropera',
            'Personal manual',
            'Costura',
        ] as $nombre) {
            Rol::query()->firstOrCreate(['nombre' => $nombre]);
        }
    }
}
