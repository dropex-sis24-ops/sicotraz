<?php

namespace Tests\Feature;

use App\Domain\Movimientos\Models\Lote;
use App\Domain\Movimientos\Models\MovimientoLote;
use App\Domain\Stock\Models\Area;
use App\Domain\Stock\Models\PlantillaFormulario;
use App\Domain\Stock\Models\StockArea;
use App\Domain\Stock\Models\TipoPrenda;
use App\Domain\Usuarios\Models\Rol;
use App\Domain\Usuarios\Models\Usuario;
use Carbon\Carbon;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class MovimientosYAlertasFeatureTest extends TestCase
{
    use RefreshDatabase;

    public function test_quirofano_enters_laundry_automatically_and_delivery_returns_stock(): void
    {
        Carbon::setTestNow(Carbon::parse('2026-08-29 08:00:00', 'America/La_Paz'));
        try {
            $quirofano = Area::query()->create(['nombre' => 'Quirófano']);
            $campo = TipoPrenda::query()->create(['nombre' => 'Campo Grande (C. GRANDE)']);
            // RN15: un lote con origen 'ocr_local' exige su plantilla.
            PlantillaFormulario::query()->create([
                'nombre' => 'Quirófano',
                'estructura_campos' => ['tipos_prenda' => ['Campo Grande (C. GRANDE)']],
                'activo' => true,
            ]);
            StockArea::query()->create([
                'area_id' => $quirofano->id,
                'tipo_prenda_id' => $campo->id,
                'cantidad_total' => 30,
                'cantidad_en_area' => 30,
                'cantidad_en_lavanderia' => 0,
            ]);
            $ropera = $this->usuario('Ropera');
            Sanctum::actingAs($ropera);

            $response = $this->postJson('/api/lotes', [
                'area_id' => $quirofano->id,
                'peso_kg' => 4.5,
                'origen_registro' => 'ocr_local',
                'detalles' => [['tipo_prenda_id' => $campo->id, 'cantidad' => 5]],
            ])->assertCreated()
                ->assertJsonPath('etapa', 'en_lavado')
                ->assertJsonPath('origen_registro', 'ocr_local')
                ->assertJsonCount(2, 'movimientos');

            $loteId = $response->json('id');
            $this->assertDatabaseHas('stock_area', [
                'area_id' => $quirofano->id,
                'tipo_prenda_id' => $campo->id,
                'cantidad_en_area' => 25,
                'cantidad_en_lavanderia' => 5,
                'cantidad_total' => 30,
            ]);
            $this->postJson("/api/lotes/{$loteId}/entrega-limpia", [])
                ->assertOk()
                ->assertJsonPath('etapa', 'limpio_entregado');
            $this->assertDatabaseHas('stock_area', [
                'area_id' => $quirofano->id,
                'tipo_prenda_id' => $campo->id,
                'cantidad_en_area' => 30,
                'cantidad_en_lavanderia' => 0,
                'cantidad_total' => 30,
            ]);
        } finally {
            Carbon::setTestNow();
        }
    }

    public function test_other_areas_remain_sucio_recibido_until_processing_starts(): void
    {
        Carbon::setTestNow(Carbon::parse('2026-08-29 08:00:00', 'America/La_Paz'));
        try {
            $area = Area::query()->create(['nombre' => 'Cirugía Varones']);
            $prenda = TipoPrenda::query()->create(['nombre' => 'Sábanas Superiores']);
            $this->stock($area, $prenda, 40);
            Sanctum::actingAs($this->usuario('Ropera'));

            $id = $this->postJson('/api/lotes', [
                'area_id' => $area->id,
                'peso_kg' => 3,
                'detalles' => [['tipo_prenda_id' => $prenda->id, 'cantidad' => 4]],
            ])->assertCreated()->assertJsonPath('etapa', 'sucio_recibido')->json('id');
            $this->patchJson("/api/lotes/{$id}/etapa", ['etapa' => 'en_lavado'])
                ->assertOk()
                ->assertJsonPath('etapa', 'en_lavado');
        } finally {
            Carbon::setTestNow();
        }
    }

    public function test_personal_manual_reports_alert_and_ropera_resolves_it(): void
    {
        $area = Area::query()->create(['nombre' => 'Cirugía Varones']);
        $prenda = TipoPrenda::query()->create(['nombre' => 'Fundas']);
        $manual = $this->usuario('Personal manual', $area->id);
        Sanctum::actingAs($manual);

        $id = $this->postJson('/api/alertas', [
            'tipo_prenda_id' => $prenda->id,
            'descripcion' => 'Falta una funda después de revisar físicamente.',
        ])->assertCreated()
            ->assertJsonPath('estado', 'pendiente')
            ->assertJsonPath('area_id', $area->id)
            ->json('id');

        Sanctum::actingAs($this->usuario('Ropera'));
        $this->getJson('/api/alertas?estado=pendiente')
            ->assertOk()
            ->assertJsonCount(1, 'data');
        $this->patchJson("/api/alertas/{$id}/resolver", [])
            ->assertOk()
            ->assertJsonPath('estado', 'resuelta');
        $this->assertDatabaseHas('alerta', ['id' => $id, 'estado' => 'resuelta']);
    }

    public function test_a_lote_can_be_closed_even_if_its_clothes_were_written_off(): void
    {
        $area = Area::query()->create(['nombre' => 'Cirugía Varones']);
        $prenda = TipoPrenda::query()->create(['nombre' => 'Sábana']);
        StockArea::query()->create([
            'area_id' => $area->id, 'tipo_prenda_id' => $prenda->id,
            'cantidad_total' => 4, 'cantidad_en_area' => 4, 'cantidad_en_lavanderia' => 0,
        ]);
        $ropera = $this->usuario('Ropera');
        Sanctum::actingAs($ropera);
        // Todo el stock del área viaja en el lote: la baja solo puede salir de
        // lo que está en lavandería.
        $lote = $this->postJson('/api/lotes', [
            'area_id' => $area->id,
            'peso_kg' => 3,
            'detalles' => [['tipo_prenda_id' => $prenda->id, 'cantidad' => 4]],
        ])->assertCreated()->json();
        $this->patchJson("/api/lotes/{$lote['id']}/etapa", ['etapa' => 'en_lavado'])->assertOk();

        // Costura da de baja dos prendas que viajaban en ese lote.
        Sanctum::actingAs($this->usuario('Costura'));
        $this->postJson('/api/bajas', [
            'area_id' => $area->id,
            'tipo_prenda_id' => $prenda->id,
            'cantidad' => 2,
            'motivo' => 'Rota / rasgada',
        ])->assertCreated();

        // Antes la entrega limpia fallaba con 422 y el lote quedaba atascado
        // en 'en_lavado' con su stock inmovilizado para siempre.
        Sanctum::actingAs($ropera);
        $this->postJson("/api/lotes/{$lote['id']}/entrega-limpia", [])
            ->assertOk()
            ->assertJsonPath('etapa', 'limpio_entregado')
            ->assertJsonPath('prendas_dadas_de_baja.0.cantidad', 2);

        $this->assertDatabaseHas('stock_area', [
            'area_id' => $area->id,
            'tipo_prenda_id' => $prenda->id,
            'cantidad_total' => 2,
            'cantidad_en_area' => 2,
            'cantidad_en_lavanderia' => 0,
        ]);
    }

    public function test_the_stage_cannot_be_advanced_twice_for_the_same_lote(): void
    {
        $area = Area::query()->create(['nombre' => 'Cirugía Varones']);
        $prenda = TipoPrenda::query()->create(['nombre' => 'Sábana']);
        StockArea::query()->create([
            'area_id' => $area->id, 'tipo_prenda_id' => $prenda->id,
            'cantidad_total' => 10, 'cantidad_en_area' => 10, 'cantidad_en_lavanderia' => 0,
        ]);
        Sanctum::actingAs($this->usuario('Ropera'));
        $lote = $this->postJson('/api/lotes', [
            'area_id' => $area->id,
            'peso_kg' => 3,
            'detalles' => [['tipo_prenda_id' => $prenda->id, 'cantidad' => 4]],
        ])->assertCreated()->json();

        $this->patchJson("/api/lotes/{$lote['id']}/etapa", ['etapa' => 'en_lavado'])->assertOk();
        $this->patchJson("/api/lotes/{$lote['id']}/etapa", ['etapa' => 'en_lavado'])->assertUnprocessable();
        $this->postJson("/api/lotes/{$lote['id']}/entrega-limpia", [])->assertOk();
        // Un segundo toque devolvía el stock otra vez, creando prendas de la nada.
        $this->postJson("/api/lotes/{$lote['id']}/entrega-limpia", [])->assertUnprocessable();

        $this->assertDatabaseHas('stock_area', [
            'area_id' => $area->id, 'tipo_prenda_id' => $prenda->id,
            'cantidad_total' => 10, 'cantidad_en_area' => 10, 'cantidad_en_lavanderia' => 0,
        ]);
        $this->assertSame(3, MovimientoLote::query()->where('lote_id', $lote['id'])->count());
    }

    public function test_an_unknown_item_number_explains_itself_instead_of_returning_a_404(): void
    {
        $area = Area::query()->create(['nombre' => 'Cirugía Varones']);
        $prenda = TipoPrenda::query()->create(['nombre' => 'Sábana']);
        StockArea::query()->create([
            'area_id' => $area->id, 'tipo_prenda_id' => $prenda->id,
            'cantidad_total' => 10, 'cantidad_en_area' => 10, 'cantidad_en_lavanderia' => 0,
        ]);
        Sanctum::actingAs($this->usuario('Ropera'));

        $this->postJson('/api/lotes', [
            'area_id' => $area->id,
            'numero_item_entrega' => '9999999',
            'peso_kg' => 3,
            'detalles' => [['tipo_prenda_id' => $prenda->id, 'cantidad' => 1]],
        ])->assertUnprocessable()
            ->assertJsonPath('message', 'No existe un usuario con el N° de ítem 9999999.');
    }

    public function test_an_ocr_lote_requires_its_form_template(): void
    {
        $area = Area::query()->create(['nombre' => 'Cirugía Varones']);
        $prenda = TipoPrenda::query()->create(['nombre' => 'Sábana']);
        StockArea::query()->create([
            'area_id' => $area->id, 'tipo_prenda_id' => $prenda->id,
            'cantidad_total' => 10, 'cantidad_en_area' => 10, 'cantidad_en_lavanderia' => 0,
        ]);
        Sanctum::actingAs($this->usuario('Ropera'));
        $payload = [
            'area_id' => $area->id,
            'peso_kg' => 3,
            'origen_registro' => 'ocr_local',
            'detalles' => [['tipo_prenda_id' => $prenda->id, 'cantidad' => 2]],
        ];

        // RN15: sin la plantilla "Salas" en la base, el lote OCR se guardaba
        // con plantilla_id en null en lugar de rechazarse.
        $this->postJson('/api/lotes', $payload)->assertUnprocessable();

        PlantillaFormulario::query()->create([
            'nombre' => 'Salas',
            'estructura_campos' => ['tipos_prenda' => ['Sábana']],
            'activo' => true,
        ]);
        $this->postJson('/api/lotes', $payload)->assertCreated()
            ->assertJsonPath('origen_registro', 'ocr_local');
        $this->assertDatabaseMissing('lote', ['origen_registro' => 'ocr_local', 'plantilla_id' => null]);
    }

    public function test_all_authenticated_roles_can_consult_history(): void
    {
        $area = Area::query()->create(['nombre' => 'Cirugía Varones']);
        $ropera = $this->usuario('Ropera');
        $lote = Lote::query()->create([
            'area_id' => $area->id,
            'etapa' => 'sucio_recibido',
            'fecha_hora' => now(),
            'peso_kg' => 1,
            'usuario_registra_id' => $ropera->id,
            'origen_registro' => 'manual',
            'sincronizado' => true,
            'fecha_ultima_modificacion' => now(),
        ]);
        Sanctum::actingAs($this->usuario('Costura'));

        $this->getJson("/api/historial?area_id={$area->id}")
            ->assertOk()
            ->assertJsonPath('data.0.id', $lote->id);
    }

    private function stock(Area $area, TipoPrenda $prenda, int $cantidad): void
    {
        StockArea::query()->create([
            'area_id' => $area->id,
            'tipo_prenda_id' => $prenda->id,
            'cantidad_total' => $cantidad,
            'cantidad_en_area' => $cantidad,
            'cantidad_en_lavanderia' => 0,
        ]);
    }

    private function usuario(string $rolNombre, ?int $areaId = null): Usuario
    {
        $rol = Rol::query()->firstOrCreate(['nombre' => $rolNombre]);

        return Usuario::query()->create([
            'nombre' => "Usuario {$rolNombre}",
            'numero_item' => (string) (700000 + Usuario::query()->count()),
            'carnet_identidad' => '1234567',
            'password_hash' => 'hash-no-usado',
            'rol_id' => $rol->id,
            'area_id' => $areaId,
            'activo' => true,
        ]);
    }
}
