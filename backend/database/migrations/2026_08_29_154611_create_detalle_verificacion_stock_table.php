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
        Schema::create('detalle_verificacion_stock', function (Blueprint $table) {
            $table->id();
            $table->foreignId('verificacion_stock_id')->constrained('verificacion_stock');
            $table->foreignId('tipo_prenda_id')->constrained('tipo_prenda');
            $table->unsignedSmallInteger('cantidad_esperada');
            $table->unsignedSmallInteger('cantidad_contada');
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('detalle_verificacion_stock');
    }
};
