<?php

namespace Tests\Feature;

use App\Domain\Movimientos\Models\Lote;
use App\Domain\Stock\Models\Area;
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
