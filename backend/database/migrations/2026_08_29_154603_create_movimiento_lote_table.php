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
        Schema::create('movimiento_lote', function (Blueprint $table) {
            $table->id();
            $table->foreignId('lote_id')->constrained('lote');
            $table->string('etapa');
            $table->timestamp('fecha_hora');
            $table->foreignId('usuario_id')->constrained('usuario');
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('movimiento_lote');
    }
};
