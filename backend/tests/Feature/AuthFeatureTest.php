<?php

namespace Tests\Feature;

use App\Console\Commands\CreateSuperAdminCommand;
use App\Domain\Usuarios\Models\Rol;
use App\Domain\Usuarios\Models\Usuario;
use Database\Seeders\RolSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AuthFeatureTest extends TestCase
{
    use RefreshDatabase;

    public function test_roles_seeded_are_exactly_the_five_roles_from_the_master_document(): void
    {
        $this->seed(RolSeeder::class);

        $this->assertSame([
            'Costura',
            'Encargado de Ropería y Lavandería',
            'Personal manual',
            'Ropera',
            'Super Admin',
        ], Rol::query()->orderBy('nombre')->pluck('nombre')->all());
    }

    public function test_valid_login_returns_token_and_forces_initial_password_change(): void
    {
        $usuario = $this->usuario();

        $this->postJson('/api/login', [
            'numero_item' => $usuario->numero_item,
            'password' => 'Carnet@123',
        ])->assertOk()
            ->assertJsonPath('usuario.numero_item', '123456')
            ->assertJsonPath('usuario.rol', 'Super Admin')
            ->assertJsonPath('debe_cambiar_password', true)
            ->assertJsonStructure(['token']);
    }

    public function test_invalid_login_is_generic_and_locks_after_five_attempts(): void
    {
        $usuario = $this->usuario();

        for ($attempt = 1; $attempt <= 4; $attempt++) {
            $this->postJson('/api/login', [
                'numero_item' => $usuario->numero_item,
                'password' => 'incorrecta',
            ])->assertUnauthorized()
                ->assertJson(['message' => 'N° de ítem o contraseña incorrectos.']);
        }

        $this->postJson('/api/login', [
            'numero_item' => $usuario->numero_item,
            'password' => 'incorrecta',
        ])->assertStatus(423);

        $this->assertNotNull($usuario->fresh()->bloqueado_hasta);
    }

    public function test_authenticated_user_can_change_initial_password_when_it_meets_policy(): void
    {
        $usuario = $this->usuario();
        Sanctum::actingAs($usuario);

        $this->postJson('/api/cambiar-password', [
            'password_nueva' => 'Nueva@123',
            'password_nueva_confirmation' => 'Nueva@123',
        ])->assertOk()
            ->assertJsonPath('usuario.debe_cambiar_password', false);

        $usuario->refresh();
        $this->assertFalse($usuario->debe_cambiar_password);
        $this->assertTrue(Hash::check('Nueva@123', $usuario->password_hash));
    }

    public function test_initial_super_admin_is_created_with_temporary_carnet_password(): void
    {
        $this->seed(RolSeeder::class);

        $this->artisan(CreateSuperAdminCommand::class)
            ->expectsQuestion('Nombre completo', 'Administrador SICOTRAZ')
            ->expectsQuestion('N° de ítem/contrato (máximo 10 dígitos)', '1234567890')
            ->expectsQuestion('Carnet de identidad (será la contraseña temporal)', '9876543')
            ->assertSuccessful();

        $usuario = Usuario::query()->firstOrFail();

        $this->assertSame('Super Admin', $usuario->rol->nombre);
        $this->assertTrue($usuario->debe_cambiar_password);
        $this->assertTrue(Hash::check('9876543', $usuario->password_hash));
    }

    private function usuario(): Usuario
    {
        $rol = Rol::query()->create(['nombre' => 'Super Admin']);

        return Usuario::query()->create([
            'nombre' => 'Administrador de prueba',
            'numero_item' => '123456',
            'carnet_identidad' => '9999999',
            'password_hash' => Hash::make('Carnet@123'),
            'rol_id' => $rol->id,
            'activo' => true,
            'debe_cambiar_password' => true,
        ]);
    }
}
