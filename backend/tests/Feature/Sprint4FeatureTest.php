<?php

namespace Tests\Feature;

use App\Domain\Alertas\Models\Alerta;
use App\Domain\Costura\Models\Baja;
use App\Domain\Movimientos\Models\DetalleLote;
use App\Domain\Movimientos\Models\Lote;
use App\Domain\Movimientos\Models\MovimientoLote;
use App\Domain\Stock\Models\Area;
use App\Domain\Stock\Models\StockArea;
use App\Domain\Stock\Models\TipoPrenda;
use App\Domain\Usuarios\Models\Rol;
use App\Domain\Usuarios\Models\Usuario;
use Carbon\Carbon;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class Sprint4FeatureTest extends TestCase
{
    use RefreshDatabase;

    public function test_costura_registers_baja_and_stock_invariant_is_preserved(): void
    {
        [$area, $prenda] = $this->catalogo();
        StockArea::query()->create([
            'area_id' => $area->id,
            'tipo_prenda_id' => $prenda->id,
            'cantidad_total' => 40,
            'cantidad_en_area' => 30,
            'cantidad_en_lavanderia' => 10,
        ]);
        Sanctum::actingAs($this->usuario('Costura'));

        $this->postJson('/api/bajas', [
            'area_id' => $area->id,
            'tipo_prenda_id' => $prenda->id,
            'cantidad' => 35,
            'motivo' => 'Rota / rasgada',
        ])->assertCreated()->assertJsonPath('cantidad', 35);

        $this->assertDatabaseHas('stock_area', [
            'area_id' => $area->id,
            'tipo_prenda_id' => $prenda->id,
            'cantidad_total' => 5,
            'cantidad_en_area' => 0,
            'cantidad_en_lavanderia' => 5,
        ]);
        $this->assertDatabaseHas('baja', ['cantidad' => 35, 'motivo' => 'Rota / rasgada']);
    }

    public function test_baja_validates_other_description_and_available_stock(): void
    {
        [$area, $prenda] = $this->catalogo();
        StockArea::query()->create([
            'area_id' => $area->id,
            'tipo_prenda_id' => $prenda->id,
            'cantidad_total' => 2,
            'cantidad_en_area' => 2,
            'cantidad_en_lavanderia' => 0,
        ]);
        Sanctum::actingAs($this->usuario('Costura'));

        $this->postJson('/api/bajas', [
            'area_id' => $area->id,
            'tipo_prenda_id' => $prenda->id,
            'cantidad' => 1,
            'motivo' => 'Otro',
        ])->assertUnprocessable()->assertJsonValidationErrors('descripcion');

        $this->postJson('/api/bajas', [
            'area_id' => $area->id,
            'tipo_prenda_id' => $prenda->id,
            'cantidad' => 3,
            'motivo' => 'Quemada',
        ])->assertUnprocessable();
    }

    public function test_dashboard_and_reports_use_real_separated_data(): void
    {
        Carbon::setTestNow(Carbon::parse('2026-08-30 10:00:00', 'America/La_Paz'));
        try {
            [$area, $prenda] = $this->catalogo();
            $admin = $this->usuario('Super Admin');
            $ahora = now('America/La_Paz');
            StockArea::query()->create([
                'area_id' => $area->id,
                'tipo_prenda_id' => $prenda->id,
                'cantidad_total' => 100,
                'cantidad_en_area' => 80,
                'cantidad_en_lavanderia' => 20,
            ]);
            $lote = Lote::query()->create([
                'area_id' => $area->id,
                'etapa' => 'en_lavado',
                'fecha_hora' => $ahora,
                'peso_kg' => 5,
                'usuario_registra_id' => $admin->id,
                'origen_registro' => 'manual',
                'sincronizado' => true,
                'fecha_ultima_modificacion' => $ahora,
            ]);
            DetalleLote::query()->create([
                'lote_id' => $lote->id,
                'tipo_prenda_id' => $prenda->id,
                'cantidad' => 12,
            ]);
            MovimientoLote::query()->create([
                'lote_id' => $lote->id,
                'etapa' => 'en_lavado',
                'fecha_hora' => $ahora,
                'usuario_id' => $admin->id,
            ]);
            Alerta::query()->create([
                'area_id' => $area->id,
                'tipo_prenda_id' => $prenda->id,
                'usuario_reporta_id' => $admin->id,
                'fecha_hora_reporte' => $ahora,
                'descripcion' => 'Faltante pendiente',
                'estado' => 'pendiente',
                'sincronizado' => true,
                'fecha_ultima_modificacion' => $ahora,
            ]);
            Baja::query()->create([
                'area_id' => $area->id,
                'tipo_prenda_id' => $prenda->id,
                'usuario_costura_id' => $admin->id,
                'cantidad' => 3,
                'motivo' => 'Desgastada por uso',
                'fecha_hora' => $ahora,
                'sincronizado' => true,
                'fecha_ultima_modificacion' => $ahora,
            ]);
            Sanctum::actingAs($admin);

            $this->getJson('/api/dashboard')->assertOk()
                ->assertJsonPath('alertas_pendientes_hoy', 1)
                ->assertJsonPath('lavado_semana_cantidad', 12)
                ->assertJsonPath('lavado_mes_cantidad', 12)
                ->assertJsonPath('bajas_mes', 3)
                ->assertJsonPath('ropa_circulando', 20)
                ->assertJsonPath('area_mas_alertas_mes.nombre', 'Cirugía Varones')
                ->assertJsonPath('prenda_mas_bajas_mes.nombre', 'Fundas');

            $this->getJson('/api/reportes/cantidad-peso?desde=2026-08-01&hasta=2026-08-30')
                ->assertOk()
                ->assertJsonPath('totales.cantidad_prendas', 12)
                ->assertJsonPath('totales.peso_kg', 5);
            $this->getJson('/api/reportes/bajas-vs-faltantes?desde=2026-08-01&hasta=2026-08-30')
                ->assertOk()
                ->assertJsonPath('bajas_confirmadas.cantidad', 3)
                ->assertJsonPath('faltantes_sin_resolver.cantidad_alertas', 1)
                ->assertJsonPath('areas_con_disminucion.0.bajas_confirmadas', 3)
                ->assertJsonPath('areas_con_disminucion.0.faltantes_pendientes', 1);
        } finally {
            Carbon::setTestNow();
        }
    }

    public function test_sprint_four_permissions_are_enforced(): void
    {
        Sanctum::actingAs($this->usuario('Ropera'));
        $this->postJson('/api/bajas', [])->assertForbidden();
        $this->getJson('/api/dashboard')->assertForbidden();
        $this->getJson('/api/reportes/cantidad-peso')->assertForbidden();

        Sanctum::actingAs($this->usuario('Encargado de Ropería y Lavandería'));
        $this->getJson('/api/dashboard')->assertOk();
        $this->getJson('/api/reportes/cantidad-peso')->assertForbidden();
    }

    private function catalogo(): array
    {
        return [
            Area::query()->create(['nombre' => 'Cirugía Varones']),
            TipoPrenda::query()->create(['nombre' => 'Fundas']),
        ];
    }

    private function usuario(string $rolNombre): Usuario
    {
        $rol = Rol::query()->firstOrCreate(['nombre' => $rolNombre]);

        return Usuario::query()->create([
            'nombre' => "Usuario {$rolNombre}",
            'numero_item' => (string) (900000 + Usuario::query()->count()),
            'carnet_identidad' => '1234567',
            'password_hash' => 'hash-no-usado',
            'rol_id' => $rol->id,
            'activo' => true,
        ]);
    }
}
