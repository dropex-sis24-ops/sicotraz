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
        Schema::create('detalle_lote', function (Blueprint $table) {
            $table->id();
            $table->foreignId('lote_id')->constrained('lote');
            $table->foreignId('tipo_prenda_id')->constrained('tipo_prenda');
            $table->unsignedSmallInteger('cantidad');
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('detalle_lote');
    }
};
