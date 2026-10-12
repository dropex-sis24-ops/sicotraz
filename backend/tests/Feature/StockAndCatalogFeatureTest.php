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
            'estructura_campos' => ['tipos_prenda' => []],
            'activo' => true,
        ]);
        $this->patchJson("/api/catalogo/plantillas/{$plantilla->id}", [
            'estructura_campos' => ['tipos_prenda' => ['Sábana de prueba']],
        ])->assertOk()
            ->assertJsonPath('estructura_campos.tipos_prenda.0', 'Sábana de prueba');

        // Una estructura sin 'tipos_prenda' dejaba el formulario de ingreso
        // vacío sin ningún aviso, y una prenda inexistente hacía lo mismo.
        $this->patchJson("/api/catalogo/plantillas/{$plantilla->id}", [
            'estructura_campos' => ['campos' => ['prenda', 'cantidad']],
        ])->assertUnprocessable();
        $this->patchJson("/api/catalogo/plantillas/{$plantilla->id}", [
            'estructura_campos' => ['tipos_prenda' => ['Prenda que no existe']],
        ])->assertUnprocessable();
    }

    public function test_renaming_a_clothing_type_keeps_it_in_the_area_template(): void
    {
        $this->seed(CatalogoInicialSeeder::class);
        Sanctum::actingAs($this->usuario('Super Admin'));
        $area = Area::query()->where('nombre', '!=', 'Quirófano')->firstOrFail();
        $prenda = TipoPrenda::query()->where('nombre', collect(
            PlantillaFormulario::query()->where('nombre', 'Salas')->value('estructura_campos')['tipos_prenda']
        )->first())->firstOrFail();

        $this->patchJson("/api/catalogo/prendas/{$prenda->id}", ['nombre' => 'Sábana renombrada'])->assertOk();

        // Las plantillas guardan nombres: sin propagar el cambio, la prenda
        // desaparecía del formulario de ingreso del área.
        $this->getJson("/api/lotes/formulario?area_id={$area->id}");
        $nombres = PlantillaFormulario::query()->where('nombre', 'Salas')->value('estructura_campos')['tipos_prenda'];
        $this->assertContains('Sábana renombrada', $nombres);
        $this->getJson("/api/catalogo/prendas?area_id={$area->id}")
            ->assertOk()
            ->assertJsonFragment(['nombre' => 'Sábana renombrada']);
    }

    public function test_an_alias_cannot_be_shared_by_two_areas(): void
    {
        Sanctum::actingAs($this->usuario('Super Admin'));
        $primera = $this->postJson('/api/catalogo/areas', ['nombre' => 'Cirugía Varones'])->json();
        $segunda = $this->postJson('/api/catalogo/areas', ['nombre' => 'Cirugía Mujeres'])->json();

        $this->postJson("/api/catalogo/areas/{$primera['id']}/alias", ['alias' => 'CIR-V'])->assertCreated();
        // El OCR resuelve el área por alias: repetirlo la vuelve ambigua.
        $this->postJson("/api/catalogo/areas/{$segunda['id']}/alias", ['alias' => 'cir v'])->assertUnprocessable();
    }

    public function test_quirofano_cannot_be_renamed_because_its_rules_depend_on_the_name(): void
    {
        Sanctum::actingAs($this->usuario('Super Admin'));
        $area = Area::query()->create(['nombre' => 'Quirófano']);

        $this->patchJson("/api/catalogo/areas/{$area->id}", ['nombre' => 'Quirofano 1'])
            ->assertUnprocessable();
    }

    public function test_clothing_catalog_is_filtered_by_the_area_template(): void
    {
        $this->seed(CatalogoInicialSeeder::class);
        Sanctum::actingAs($this->usuario('Personal manual'));
        $sala = Area::query()->where('nombre', 'Cirugía Mujeres')->firstOrFail();
        $quirofano = Area::query()->where('nombre', 'Quirófano')->firstOrFail();

        $this->getJson("/api/catalogo/prendas?area_id={$sala->id}")->assertOk()
            ->assertJsonFragment(['nombre' => 'Sábanas Superiores'])
            ->assertJsonMissing(['nombre' => 'Campo Grande (C. GRANDE)']);
        $this->getJson("/api/catalogo/prendas?area_id={$quirofano->id}")->assertOk()
            ->assertJsonFragment(['nombre' => 'Campo Grande (C. GRANDE)'])
            ->assertJsonMissing(['nombre' => 'Sábanas Superiores']);
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

    public function test_a_deactivated_item_keeps_its_history_but_cannot_enter_a_new_lote(): void
    {
        Sanctum::actingAs($this->usuario('Super Admin'));
        $area = Area::query()->create(['nombre' => 'Cirugía Varones']);
        $prenda = TipoPrenda::query()->create(['nombre' => 'Sábana']);
        StockArea::query()->create([
            'area_id' => $area->id, 'tipo_prenda_id' => $prenda->id,
            'cantidad_total' => 10, 'cantidad_en_area' => 10, 'cantidad_en_lavanderia' => 0,
        ]);
        PlantillaFormulario::query()->create([
            'nombre' => 'Salas',
            'estructura_campos' => ['tipos_prenda' => ['Sábana']],
            'activo' => true,
        ]);

        // Pantalla 5: desactivar un ítem con historial está aprobado.
        $this->patchJson("/api/catalogo/prendas/{$prenda->id}", ['activo' => false])
            ->assertOk()
            ->assertJsonPath('activo', false);

        // Lo que debe bloquearse es usarlo en un lote nuevo.
        Sanctum::actingAs($this->usuario('Ropera'));
        $this->postJson('/api/lotes', [
            'area_id' => $area->id,
            'peso_kg' => 2,
            'detalles' => [['tipo_prenda_id' => $prenda->id, 'cantidad' => 1]],
        ])->assertUnprocessable()
            ->assertJsonValidationErrors('detalles.0.tipo_prenda_id');

        // Y lo mismo con un área desactivada.
        Sanctum::actingAs($this->usuario('Super Admin'));
        $this->patchJson("/api/catalogo/prendas/{$prenda->id}", ['activo' => true])->assertOk();
        $this->patchJson("/api/catalogo/areas/{$area->id}", ['activo' => false])->assertOk();
        Sanctum::actingAs($this->usuario('Ropera'));
        $this->postJson('/api/lotes', [
            'area_id' => $area->id,
            'peso_kg' => 2,
            'detalles' => [['tipo_prenda_id' => $prenda->id, 'cantidad' => 1]],
        ])->assertUnprocessable()
            ->assertJsonValidationErrors('area_id');
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
