<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('alerta', function (Blueprint $table) {
            $table->id();
            $table->foreignId('area_id')->constrained('area');
            $table->foreignId('tipo_prenda_id')->constrained('tipo_prenda');
            $table->foreignId('usuario_reporta_id')->constrained('usuario');
            $table->timestamp('fecha_hora_reporte');
            $table->text('descripcion');
            $table->string('foto_evidencia_url')->nullable();
            $table->string('estado');
            $table->foreignId('usuario_resuelve_id')->nullable()->constrained('usuario');
            $table->timestamp('fecha_resolucion')->nullable();
            $table->text('nota_resolucion')->nullable();
            $table->boolean('sincronizado')->default(false);
            $table->timestamp('fecha_ultima_modificacion');
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('alerta');
    }
};
