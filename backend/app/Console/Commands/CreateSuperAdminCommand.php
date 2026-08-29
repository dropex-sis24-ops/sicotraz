<?php

namespace App\Console\Commands;

use App\Domain\Usuarios\Models\Rol;
use App\Domain\Usuarios\Models\Usuario;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Hash;

class CreateSuperAdminCommand extends Command
{
    protected $signature = 'sicotraz:crear-super-admin';

    protected $description = 'Crea la cuenta inicial de Super Admin con contraseña temporal igual al carnet.';

    public function handle(): int
    {
        $rol = Rol::query()->where('nombre', 'Super Admin')->first();

        if ($rol === null) {
            $this->error('No existe el rol Super Admin. Ejecute primero php artisan db:seed.');

            return self::FAILURE;
        }

        if (Usuario::query()->where('rol_id', $rol->id)->exists()) {
            $this->error('Ya existe una cuenta Super Admin. Use la gestión de usuarios para administrar cuentas.');

            return self::FAILURE;
        }

        $nombre = $this->ask('Nombre completo');
        $numeroItem = $this->ask('N° de ítem/contrato (máximo 10 dígitos)');
        $carnet = $this->secret('Carnet de identidad (será la contraseña temporal)');

        if (! is_string($nombre) || trim($nombre) === '' || ! is_string($numeroItem) || ! preg_match('/^[0-9]{1,10}$/', $numeroItem) || ! is_string($carnet) || trim($carnet) === '') {
            $this->error('Datos inválidos. El nombre y carnet son obligatorios; el número de ítem debe tener entre 1 y 10 dígitos.');

            return self::FAILURE;
        }

        if (Usuario::query()->where('numero_item', $numeroItem)->exists()) {
            $this->error('Ya existe una cuenta con ese número de ítem/contrato.');

            return self::FAILURE;
        }

        Usuario::query()->create([
            'nombre' => trim($nombre),
            'numero_item' => $numeroItem,
            'carnet_identidad' => trim($carnet),
            'password_hash' => Hash::make($carnet),
            'rol_id' => $rol->id,
            'activo' => true,
            'debe_cambiar_password' => true,
        ]);

        $this->info('Cuenta Super Admin creada. En el primer ingreso deberá cambiar la contraseña.');

        return self::SUCCESS;
    }
}
