<?php

namespace Tests\Feature;

use App\Domain\Stock\Models\PlantillaFormulario;
use App\Domain\Usuarios\Models\Rol;
use App\Domain\Usuarios\Models\Usuario;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class PlantillaPdfFeatureTest extends TestCase
{
    use RefreshDatabase;

    public function test_super_admin_can_generate_a_valid_pdf(): void
    {
        PlantillaFormulario::query()->create([
            'nombre' => 'Salas',
            'estructura_campos' => ['tipos_prenda' => ['Sábanas Superiores', 'Fundas']],
            'activo' => true,
        ]);
        Sanctum::actingAs($this->usuario('Super Admin'));

        $response = $this->get('/api/plantillas/pdf?plantilla=Salas')
            ->assertOk()
            ->assertHeader('content-type', 'application/pdf');

        $this->assertStringStartsWith('%PDF-', $response->getContent());
    }

    public function test_ropera_cannot_generate_template_pdf(): void
    {
        Sanctum::actingAs($this->usuario('Ropera'));

        $this->get('/api/plantillas/pdf?plantilla=Salas')->assertForbidden();
    }

    private function usuario(string $rolNombre): Usuario
    {
        $rol = Rol::query()->create(['nombre' => $rolNombre]);

        return Usuario::query()->create([
            'nombre' => "Usuario {$rolNombre}",
            'numero_item' => (string) (810000 + Usuario::query()->count()),
            'carnet_identidad' => '1234567',
            'password_hash' => 'hash-no-usado',
            'rol_id' => $rol->id,
            'activo' => true,
        ]);
    }
}
