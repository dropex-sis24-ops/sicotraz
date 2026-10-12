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
            'password_actual' => 'Carnet@123',
            'password_nueva' => 'Nueva@123',
            'password_nueva_confirmation' => 'Nueva@123',
        ])->assertOk()
            ->assertJsonPath('usuario.debe_cambiar_password', false);

        $usuario->refresh();
        $this->assertFalse($usuario->debe_cambiar_password);
        $this->assertTrue(Hash::check('Nueva@123', $usuario->password_hash));
    }

    public function test_password_change_requires_the_current_password(): void
    {
        $usuario = $this->usuario();
        Sanctum::actingAs($usuario);

        $this->postJson('/api/cambiar-password', [
            'password_actual' => 'Equivocada@1',
            'password_nueva' => 'Nueva@123',
            'password_nueva_confirmation' => 'Nueva@123',
        ])->assertUnprocessable()
            ->assertJsonValidationErrors('password_actual');

        $this->assertTrue(Hash::check('Carnet@123', $usuario->fresh()->password_hash));
    }

    public function test_password_change_closes_the_sessions_opened_on_other_devices(): void
    {
        $usuario = $this->usuario();
        $otroDispositivo = $usuario->createToken('tablet')->accessToken;
        Sanctum::actingAs($usuario);

        $this->postJson('/api/cambiar-password', [
            'password_actual' => 'Carnet@123',
            'password_nueva' => 'Nueva@123',
            'password_nueva_confirmation' => 'Nueva@123',
        ])->assertOk();

        $this->assertDatabaseMissing('personal_access_tokens', ['id' => $otroDispositivo->getKey()]);
    }

    public function test_failed_attempts_reset_once_the_lock_expires(): void
    {
        $usuario = $this->usuario();
        $usuario->forceFill([
            'intentos_fallidos' => 5,
            'bloqueado_hasta' => now()->subMinute(),
        ])->save();

        // Antes el contador seguía en 5 y el primer fallo volvía a bloquear.
        $this->postJson('/api/login', [
            'numero_item' => '123456',
            'password' => 'Equivocada@1',
        ])->assertUnauthorized();

        $usuario->refresh();
        $this->assertSame(1, $usuario->intentos_fallidos);
        $this->assertNull($usuario->bloqueado_hasta);
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
