<?php

namespace Tests\Feature;

use App\Domain\Alertas\Models\Alerta;
use App\Domain\Stock\Models\Area;
use App\Domain\Stock\Models\TipoPrenda;
use App\Domain\Usuarios\Models\Rol;
use App\Domain\Usuarios\Models\Usuario;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class UserManagementFeatureTest extends TestCase
{
    use RefreshDatabase;

    public function test_super_admin_edits_carnet_and_it_becomes_the_new_temporary_password(): void
    {
        $admin = $this->usuario('Super Admin', '900001');
        $target = $this->usuario('Ropera', '33370');
        $target->createToken('telefono');
        Sanctum::actingAs($admin);

        $this->putJson("/api/usuarios/{$target->id}", [
            'carnet_identidad' => '7654321',
        ])->assertOk()->assertJsonPath('debe_cambiar_password', true);

        $target->refresh();
        $this->assertSame('7654321', $target->carnet_identidad);
        $this->assertTrue(Hash::check('7654321', $target->password_hash));
        $this->assertDatabaseMissing('personal_access_tokens', [
            'tokenable_type' => Usuario::class,
            'tokenable_id' => $target->id,
        ]);
    }

    public function test_unused_user_can_be_deleted_and_item_can_be_registered_again(): void
    {
        $admin = $this->usuario('Super Admin', '900001');
        $target = $this->usuario('Ropera', '33370');
        $roleId = $target->rol_id;
        Sanctum::actingAs($admin);

        $this->deleteJson("/api/usuarios/{$target->id}")->assertOk()
            ->assertJsonPath('message', 'Usuario eliminado correctamente.');
        $this->assertDatabaseMissing('usuario', ['id' => $target->id]);

        $this->postJson('/api/usuarios', [
            'nombre' => 'Alejandra Antezana Amaya',
            'numero_item' => '33370',
            'carnet_identidad' => '1234567',
            'rol_id' => $roleId,
        ])->assertCreated();
    }

    public function test_self_deletion_and_deletion_of_users_with_history_are_rejected(): void
    {
        $admin = $this->usuario('Super Admin', '900001');
        Sanctum::actingAs($admin);
        $this->deleteJson("/api/usuarios/{$admin->id}")->assertUnprocessable();

        $target = $this->usuario('Personal manual', '33370');
        $area = Area::query()->create(['nombre' => 'Cirugía Mujeres']);
        $prenda = TipoPrenda::query()->create(['nombre' => 'Sábanas Superiores']);
        Alerta::query()->create([
            'area_id' => $area->id,
            'tipo_prenda_id' => $prenda->id,
            'usuario_reporta_id' => $target->id,
            'fecha_hora_reporte' => now(),
            'descripcion' => 'Faltan 2 sábanas.',
            'estado' => 'pendiente',
            'sincronizado' => true,
            'fecha_ultima_modificacion' => now(),
        ]);

        $this->deleteJson("/api/usuarios/{$target->id}")->assertUnprocessable()
            ->assertJsonPath('message', 'El usuario tiene historial operativo y no puede eliminarse. Desactívelo para conservar la trazabilidad.');
        $this->assertDatabaseHas('usuario', ['id' => $target->id]);
    }

    private function usuario(string $roleName, string $item): Usuario
    {
        $role = Rol::query()->firstOrCreate(['nombre' => $roleName]);

        return Usuario::query()->create([
            'nombre' => "Usuario $roleName",
            'numero_item' => $item,
            'carnet_identidad' => '1111111',
            'password_hash' => Hash::make('Temporal123!'),
            'rol_id' => $role->id,
            'activo' => true,
        ]);
    }
}
