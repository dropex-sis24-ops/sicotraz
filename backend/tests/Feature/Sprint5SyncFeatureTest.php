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

    public function test_a_record_the_role_cannot_sync_is_rejected_without_losing_the_rest(): void
    {
        $area = Area::query()->create(['nombre' => 'Cirugía Varones']);
        $prenda = TipoPrenda::query()->create(['nombre' => 'Sábana']);
        Sanctum::actingAs($this->usuario('Personal manual', $area->id));

        $response = $this->postJson('/api/sync', ['registros' => [
            // Personal manual no puede sincronizar bajas: antes este registro
            // abortaba el lote completo con un 403 y la alerta se perdía.
            [
                'tipo' => 'baja',
                'uuid_local' => '1b9d1a3e-0d64-45a7-9c3f-2e1c7a9d4f10',
                'fecha_ultima_modificacion' => '2026-08-30T15:00:00Z',
                'datos' => ['area_id' => $area->id, 'tipo_prenda_id' => $prenda->id, 'cantidad' => 1, 'motivo' => 'Perdida'],
            ],
            [
                'tipo' => 'alerta',
                'uuid_local' => '2c0e2b4f-1e75-46b8-8d40-3f2d8bae5021',
                'fecha_ultima_modificacion' => '2026-08-30T15:00:00Z',
                'datos' => ['area_id' => $area->id, 'tipo_prenda_id' => $prenda->id, 'descripcion' => 'Faltan dos unidades'],
            ],
        ]]);

        $response->assertOk()
            ->assertJsonCount(1, 'guardados')
            ->assertJsonCount(1, 'rechazados')
            ->assertJsonPath('rechazados.0.uuid_local', '1b9d1a3e-0d64-45a7-9c3f-2e1c7a9d4f10');
        $this->assertDatabaseCount('alerta', 1);
        $this->assertDatabaseCount('baja', 0);
    }

    public function test_keeping_the_server_version_stops_the_conflict_from_coming_back(): void
    {
        $area = Area::query()->create(['nombre' => 'Cirugía Varones']);
        $prenda = TipoPrenda::query()->create(['nombre' => 'Sábana']);
        $manual = $this->usuario('Personal manual', $area->id);
        Sanctum::actingAs($manual);
        $uuid = 'af1d5c2b-7e38-4a91-93c5-6d0b2e4f7a83';

        $this->postJson('/api/sync', $this->batch($uuid, $area->id, $prenda->id, 'Versión servidor'))->assertOk();
        $cambiado = $this->batch($uuid, $area->id, $prenda->id, 'Versión dispositivo');
        $conflictId = $this->postJson('/api/sync', $cambiado)->assertOk()->json('conflictos.0.id');

        Sanctum::actingAs($this->usuario('Super Admin'));
        $this->patchJson("/api/sync/conflictos/$conflictId/resolver", [
            'version_elegida' => 'servidor',
        ])->assertOk();

        // El dispositivo reenvía su versión: debe reconocerse como duplicada en
        // lugar de abrir otro conflicto idéntico en cada sincronización.
        Sanctum::actingAs($manual);
        $this->postJson('/api/sync', $cambiado)->assertOk()
            ->assertJsonPath('guardados.0.duplicado', true)
            ->assertJsonCount(0, 'conflictos');
        $this->assertDatabaseCount('conflicto_sincronizacion', 1);
    }

    public function test_reordering_the_details_is_not_treated_as_a_change(): void
    {
        $area = Area::query()->create(['nombre' => 'Cirugía Varones']);
        $sabana = TipoPrenda::query()->create(['nombre' => 'Sábana']);
        $toalla = TipoPrenda::query()->create(['nombre' => 'Toalla']);
        StockArea::query()->create([
            'area_id' => $area->id, 'tipo_prenda_id' => $sabana->id,
            'cantidad_total' => 20, 'cantidad_en_area' => 20, 'cantidad_en_lavanderia' => 0,
        ]);
        StockArea::query()->create([
            'area_id' => $area->id, 'tipo_prenda_id' => $toalla->id,
            'cantidad_total' => 20, 'cantidad_en_area' => 20, 'cantidad_en_lavanderia' => 0,
        ]);
        Sanctum::actingAs($this->usuario('Ropera'));
        $uuid = 'c3b8f0d1-5a26-4f7e-8b19-0e5d7c2a9f64';

        $lote = fn (array $detalles) => ['registros' => [[
            'tipo' => 'lote',
            'uuid_local' => $uuid,
            'fecha_ultima_modificacion' => '2026-08-30T16:00:00Z',
            'datos' => ['area_id' => $area->id, 'peso_kg' => 4.5, 'detalles' => $detalles],
        ]]];
        $sabanaPrimero = [
            ['tipo_prenda_id' => $sabana->id, 'cantidad' => 3],
            ['tipo_prenda_id' => $toalla->id, 'cantidad' => 2],
        ];

        $this->postJson('/api/sync', $lote($sabanaPrimero))->assertOk();
        $this->postJson('/api/sync', $lote(array_reverse($sabanaPrimero)))->assertOk()
            ->assertJsonPath('guardados.0.duplicado', true)
            ->assertJsonCount(0, 'conflictos');
    }

    public function test_a_user_only_sees_the_conflicts_of_their_own_records(): void
    {
        $area = Area::query()->create(['nombre' => 'Cirugía Varones']);
        $prenda = TipoPrenda::query()->create(['nombre' => 'Sábana']);
        $uuid = 'e5f7a9c1-2b48-4d60-9e73-1a8c5b3d7f92';
        Sanctum::actingAs($this->usuario('Personal manual', $area->id));
        $this->postJson('/api/sync', $this->batch($uuid, $area->id, $prenda->id, 'Versión servidor'))->assertOk();
        $this->postJson('/api/sync', $this->batch($uuid, $area->id, $prenda->id, 'Versión dispositivo'))->assertOk();

        // Otro usuario del mismo rol no debe ver el contenido del conflicto ajeno.
        Sanctum::actingAs($this->usuario('Personal manual', $area->id));
        $this->getJson('/api/sync/conflictos')->assertOk()->assertJsonCount(0);

        Sanctum::actingAs($this->usuario('Encargado de Ropería y Lavandería'));
        $this->getJson('/api/sync/conflictos')->assertOk()->assertJsonCount(1);
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
