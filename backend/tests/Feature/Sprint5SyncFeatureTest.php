<?php

namespace Tests\Feature;

use App\Domain\Stock\Models\Area;
use App\Domain\Stock\Models\StockArea;
use App\Domain\Stock\Models\TipoPrenda;
use App\Domain\Usuarios\Models\Rol;
use App\Domain\Usuarios\Models\Usuario;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class Sprint5SyncFeatureTest extends TestCase
{
    use RefreshDatabase;

    public function test_offline_batch_is_idempotent_and_a_changed_copy_creates_conflict(): void
    {
        $area = Area::query()->create(['nombre' => 'Cirugía Varones']);
        $prenda = TipoPrenda::query()->create(['nombre' => 'Sábana']);
        Sanctum::actingAs($this->usuario('Personal manual', $area->id));
        $uuid = '7dbcb4b6-ff1b-4ad8-a309-6f3565b11a6a';
        $payload = $this->batch($uuid, $area->id, $prenda->id, 'Faltan dos unidades');

        $this->postJson('/api/sync', $payload)->assertOk()
            ->assertJsonPath('guardados.0.uuid_local', $uuid)
            ->assertJsonPath('guardados.0.duplicado', false)
            ->assertJsonCount(0, 'conflictos');

        $this->postJson('/api/sync', $payload)->assertOk()
            ->assertJsonPath('guardados.0.duplicado', true);
        $this->assertDatabaseCount('alerta', 1);

        $changed = $this->batch($uuid, $area->id, $prenda->id, 'Faltan tres unidades');
        $response = $this->postJson('/api/sync', $changed)->assertOk()
            ->assertJsonCount(1, 'conflictos');
        $conflictId = $response->json('conflictos.0.id');
        $this->assertDatabaseHas('conflicto_sincronizacion', [
            'id' => $conflictId,
            'entidad_tipo' => 'alerta',
            'estado' => 'pendiente',
        ]);
        $this->getJson('/api/sync/conflictos')->assertOk()
            ->assertJsonPath('0.version_local_json.descripcion', 'Faltan tres unidades')
            ->assertJsonPath('0.version_servidor_json.descripcion', 'Faltan dos unidades');
    }

    public function test_only_responsible_roles_resolve_and_discarded_version_is_removed(): void
    {
        $area = Area::query()->create(['nombre' => 'Cirugía Varones']);
        $prenda = TipoPrenda::query()->create(['nombre' => 'Sábana']);
        $manual = $this->usuario('Personal manual', $area->id);
        Sanctum::actingAs($manual);
        $uuid = 'd197bc65-6e20-4e2c-b19a-8d1af610cf61';
        $this->postJson('/api/sync', $this->batch($uuid, $area->id, $prenda->id, 'Versión servidor'))->assertOk();
        $conflictResponse = $this->postJson(
            '/api/sync',
            $this->batch($uuid, $area->id, $prenda->id, 'Versión dispositivo'),
        )->assertOk()->assertJsonCount(1, 'conflictos');
        $conflictId = $conflictResponse->json('conflictos.0.id');
        $this->assertIsInt($conflictId);
        $this->assertDatabaseHas('conflicto_sincronizacion', ['id' => $conflictId]);

        $this->patchJson("/api/sync/conflictos/$conflictId/resolver", [
            'version_elegida' => 'local',
        ])->assertForbidden();

        $encargado = $this->usuario('Encargado de Ropería y Lavandería');
        Sanctum::actingAs($encargado);
        $this->patchJson("/api/sync/conflictos/$conflictId/resolver", [
            'version_elegida' => 'local',
        ])->assertOk()
            ->assertJsonPath('estado', 'resuelto')
            ->assertJsonPath('version_elegida', 'local')
            ->assertJsonPath('version_servidor_json', []);

        $this->assertDatabaseHas('alerta', [
            'uuid_local' => $uuid,
            'descripcion' => 'Versión dispositivo',
        ]);
        $this->getJson('/api/sync/conflictos')->assertOk()->assertExactJson([]);
    }

    public function test_choosing_local_lote_replaces_details_and_preserves_stock(): void
    {
        $area = Area::query()->create(['nombre' => 'Cirugía Varones']);
        $prenda = TipoPrenda::query()->create(['nombre' => 'Sábana']);
        StockArea::query()->create([
            'area_id' => $area->id,
            'tipo_prenda_id' => $prenda->id,
            'cantidad_total' => 20,
            'cantidad_en_area' => 20,
            'cantidad_en_lavanderia' => 0,
        ]);
        Sanctum::actingAs($this->usuario('Ropera'));
        $uuid = '13029ae4-bb21-48a8-8d40-aa9d49d649d3';
        $batch = fn (int $amount) => ['registros' => [[
            'tipo' => 'lote',
            'uuid_local' => $uuid,
            'fecha_ultima_modificacion' => '2026-08-30T16:00:00Z',
            'datos' => [
                'area_id' => $area->id,
                'peso_kg' => 4.5,
                'detalles' => [['tipo_prenda_id' => $prenda->id, 'cantidad' => $amount]],
            ],
        ]]];
        $this->postJson('/api/sync', $batch(10))->assertOk();
        $conflictId = $this->postJson('/api/sync', $batch(6))->assertOk()->json('conflictos.0.id');

        Sanctum::actingAs($this->usuario('Super Admin'));
        $this->patchJson("/api/sync/conflictos/$conflictId/resolver", [
            'version_elegida' => 'local',
        ])->assertOk();

        $this->assertDatabaseHas('detalle_lote', ['tipo_prenda_id' => $prenda->id, 'cantidad' => 6]);
        $this->assertDatabaseHas('stock_area', [
            'area_id' => $area->id,
            'tipo_prenda_id' => $prenda->id,
            'cantidad_total' => 20,
            'cantidad_en_area' => 14,
            'cantidad_en_lavanderia' => 6,
        ]);
    }

    private function batch(string $uuid, int $areaId, int $prendaId, string $description): array
    {
        return ['registros' => [[
            'tipo' => 'alerta',
            'uuid_local' => $uuid,
            'fecha_ultima_modificacion' => '2026-08-30T15:00:00Z',
            'datos' => [
                'area_id' => $areaId,
                'tipo_prenda_id' => $prendaId,
                'descripcion' => $description,
            ],
        ]]];
    }

    private function usuario(string $roleName, ?int $areaId = null): Usuario
    {
        $role = Rol::query()->firstOrCreate(['nombre' => $roleName]);

        return Usuario::query()->create([
            'nombre' => $roleName,
            'numero_item' => (string) random_int(100000, 999999),
            'carnet_identidad' => (string) random_int(1000000, 9999999),
            'password_hash' => bcrypt('Temporal123!'),
            'rol_id' => $role->id,
            'area_id' => $areaId,
        ]);
    }
}
