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
        Schema::create('lote', function (Blueprint $table) {
            $table->id();
            $table->foreignId('area_id')->constrained('area');
            $table->string('etapa');
            $table->timestamp('fecha_hora');
            $table->decimal('peso_kg', 8, 2);
            $table->foreignId('usuario_entrega_id')->constrained('usuario');
            $table->foreignId('usuario_registra_id')->constrained('usuario');
            $table->foreignId('usuario_recibe_id')->nullable()->constrained('usuario');
            $table->string('origen_registro');
            $table->foreignId('plantilla_id')->nullable()->constrained('plantilla_formulario');
            $table->string('nombre_quien_trae')->nullable();
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
        Schema::dropIfExists('lote');
    }
};
