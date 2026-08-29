<?php

namespace Tests\Feature;

use App\Domain\Stock\Models\Area;
use App\Domain\Stock\Models\PlantillaFormulario;
use App\Domain\Stock\Models\StockArea;
use App\Domain\Stock\Models\TipoPrenda;
use App\Domain\Usuarios\Models\Rol;
use App\Domain\Usuarios\Models\Usuario;
use Database\Seeders\CatalogoInicialSeeder;
use Database\Seeders\StockPilotoSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class StockAndCatalogFeatureTest extends TestCase
{
    use RefreshDatabase;

    public function test_super_admin_can_manage_catalog_and_update_a_template(): void
    {
        Sanctum::actingAs($this->usuario('Super Admin'));

        $this->postJson('/api/catalogo/prendas', ['nombre' => 'Sábana de prueba'])
            ->assertCreated()
            ->assertJsonPath('activo', true);
        $area = $this->postJson('/api/catalogo/areas', ['nombre' => 'Área de prueba'])
            ->assertCreated()
            ->json();
        $this->postJson("/api/catalogo/areas/{$area['id']}/alias", ['alias' => 'A. prueba'])
            ->assertCreated()
            ->assertJsonPath('alias_normalizado', 'APRUEBA');

        $plantilla = PlantillaFormulario::query()->create([
            'nombre' => 'Salas',
            'estructura_campos' => ['campos' => []],
            'activo' => true,
        ]);
        $this->patchJson("/api/catalogo/plantillas/{$plantilla->id}", [
            'estructura_campos' => ['campos' => ['prenda', 'cantidad']],
        ])->assertOk()
            ->assertJsonPath('estructura_campos.campos.0', 'prenda');
    }

    public function test_initial_stock_is_additive_and_never_exceeds_999(): void
    {
        Sanctum::actingAs($this->usuario('Super Admin'));
        $area = Area::query()->create(['nombre' => 'Cirugía Varones']);
        $prenda = TipoPrenda::query()->create(['nombre' => 'Sábana']);

        $this->postJson('/api/stock/carga-inicial', [
            'area_id' => $area->id,
            'tipo_prenda_id' => $prenda->id,
            'cantidad' => 93,
        ])->assertCreated()->assertJsonPath('cantidad_total', 93);
        $this->postJson('/api/stock/carga-inicial', [
            'area_id' => $area->id,
            'tipo_prenda_id' => $prenda->id,
            'cantidad' => 50,
        ])->assertCreated()->assertJsonPath('cantidad_total', 143);
        $this->postJson('/api/stock/carga-inicial', [
            'area_id' => $area->id,
            'tipo_prenda_id' => $prenda->id,
            'cantidad' => 857,
        ])->assertUnprocessable();

        $prenda->update(['activo' => false]);
        $this->postJson('/api/stock/carga-inicial', [
            'area_id' => $area->id,
            'tipo_prenda_id' => $prenda->id,
            'cantidad' => 1,
        ])->assertUnprocessable();
    }

    public function test_only_personal_manual_can_verify_and_difference_needs_an_observation(): void
    {
        $area = Area::query()->create(['nombre' => 'Quirófano']);
        $prenda = TipoPrenda::query()->create(['nombre' => 'Campo']);
        $area->stocks()->create([
            'tipo_prenda_id' => $prenda->id,
            'cantidad_total' => 10,
            'cantidad_en_area' => 10,
            'cantidad_en_lavanderia' => 0,
        ]);
        Sanctum::actingAs($this->usuario('Ropera'));
        $this->getJson("/api/stock/verificacion?area_id={$area->id}")->assertForbidden();

        Sanctum::actingAs($this->usuario('Personal manual', $area->id));
        $this->postJson('/api/stock/verificacion', [
            'area_id' => $area->id,
            'detalles' => [['tipo_prenda_id' => $prenda->id, 'cantidad_contada' => 9]],
        ])->assertUnprocessable();
        $this->postJson('/api/stock/verificacion', [
            'area_id' => $area->id,
            'observacion' => 'Falta una prenda tras revisión física.',
            'detalles' => [['tipo_prenda_id' => $prenda->id, 'cantidad_contada' => 9]],
        ])->assertCreated()
            ->assertJsonPath('resultado', 'irregularidad_reportada');
    }

    public function test_pilot_stock_seeder_loads_the_confirmed_pilot_records(): void
    {
        $this->seed(CatalogoInicialSeeder::class);
        $this->seed(StockPilotoSeeder::class);

        $this->assertDatabaseHas('stock_area', ['cantidad_total' => 40]);
        $this->assertDatabaseHas('stock_area', ['cantidad_total' => 30]);
        $this->assertDatabaseHas('stock_area', ['cantidad_total' => 55]);
        $this->assertSame(21, StockArea::query()->count());
    }

    public function test_personal_manual_requires_an_assigned_area_and_verifies_it_automatically(): void
    {
        Sanctum::actingAs($this->usuario('Super Admin'));
        $area = Area::query()->create(['nombre' => 'Área asignada']);
        $rol = Rol::query()->create(['nombre' => 'Personal manual']);

        $this->postJson('/api/usuarios', [
            'nombre' => 'Manual sin área',
            'numero_item' => '900001',
            'carnet_identidad' => '1234567',
            'rol_id' => $rol->id,
        ])->assertUnprocessable();

        $usuario = $this->usuario('Personal manual', $area->id);
        Sanctum::actingAs($usuario);
        $this->getJson('/api/stock/verificacion')->assertOk();
    }

    private function usuario(string $rolNombre, ?int $areaId = null): Usuario
    {
        $rol = Rol::query()->firstOrCreate(['nombre' => $rolNombre]);

        return Usuario::query()->create([
            'nombre' => "Usuario {$rolNombre}",
            'numero_item' => (string) (100000 + Usuario::query()->count()),
            'carnet_identidad' => '1234567',
            'password_hash' => 'hash-no-usado',
            'rol_id' => $rol->id,
            'area_id' => $areaId,
            'activo' => true,
        ]);
    }
}
