<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('rol', function (Blueprint $table): void {
            $table->unique('nombre');
        });

        Schema::table('usuario', function (Blueprint $table): void {
            $table->unique('numero_item');
        });

        Schema::table('area', function (Blueprint $table): void {
            $table->unique('nombre');
        });

        Schema::table('tipo_prenda', function (Blueprint $table): void {
            $table->unique('nombre');
        });

        Schema::table('alias_area', function (Blueprint $table): void {
            $table->unique('alias_normalizado');
        });

        // Sin esta clave, dos cargas simultáneas crean dos filas para el mismo
        // par área/prenda y el stock queda partido e imposible de validar.
        Schema::table('stock_area', function (Blueprint $table): void {
            $table->unique(['area_id', 'tipo_prenda_id']);
        });

        // La validación aceptaba 2048 caracteres contra columnas de 255.
        Schema::table('alerta', function (Blueprint $table): void {
            $table->string('foto_evidencia_url', 2048)->nullable()->change();
            $table->index(['estado', 'fecha_hora_reporte']);
        });

        Schema::table('baja', function (Blueprint $table): void {
            $table->string('foto_evidencia_url', 2048)->nullable()->change();
            $table->index('fecha_hora');
        });

        Schema::table('lote', function (Blueprint $table): void {
            $table->index('fecha_hora');
            $table->index('etapa');
        });

        Schema::table('movimiento_lote', function (Blueprint $table): void {
            $table->index(['etapa', 'fecha_hora']);
        });

        Schema::table('verificacion_stock', function (Blueprint $table): void {
            $table->index('fecha_hora');
        });

        Schema::table('conflicto_sincronizacion', function (Blueprint $table): void {
            $table->index(['estado', 'entidad_tipo']);
        });
    }

    public function down(): void
    {
        Schema::table('conflicto_sincronizacion', fn (Blueprint $t) => $t->dropIndex(['estado', 'entidad_tipo']));
        Schema::table('verificacion_stock', fn (Blueprint $t) => $t->dropIndex(['fecha_hora']));
        Schema::table('movimiento_lote', fn (Blueprint $t) => $t->dropIndex(['etapa', 'fecha_hora']));
        Schema::table('lote', function (Blueprint $table): void {
            $table->dropIndex(['fecha_hora']);
            $table->dropIndex(['etapa']);
        });
        Schema::table('baja', fn (Blueprint $t) => $t->dropIndex(['fecha_hora']));
        Schema::table('alerta', fn (Blueprint $t) => $t->dropIndex(['estado', 'fecha_hora_reporte']));
        Schema::table('stock_area', fn (Blueprint $t) => $t->dropUnique(['area_id', 'tipo_prenda_id']));
        Schema::table('alias_area', fn (Blueprint $t) => $t->dropUnique(['alias_normalizado']));
        Schema::table('tipo_prenda', fn (Blueprint $t) => $t->dropUnique(['nombre']));
        Schema::table('area', fn (Blueprint $t) => $t->dropUnique(['nombre']));
        Schema::table('usuario', fn (Blueprint $t) => $t->dropUnique(['numero_item']));
        Schema::table('rol', fn (Blueprint $t) => $t->dropUnique(['nombre']));
    }
};
