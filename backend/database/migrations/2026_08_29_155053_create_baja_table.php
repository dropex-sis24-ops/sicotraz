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
        Schema::create('baja', function (Blueprint $table) {
            $table->id();
            $table->foreignId('tipo_prenda_id')->constrained('tipo_prenda');
            $table->foreignId('area_id')->constrained('area');
            $table->foreignId('usuario_costura_id')->constrained('usuario');
            $table->unsignedSmallInteger('cantidad');
            $table->string('motivo');
            $table->string('foto_evidencia_url')->nullable();
            $table->timestamp('fecha_hora');
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
        Schema::dropIfExists('baja');
    }
};
