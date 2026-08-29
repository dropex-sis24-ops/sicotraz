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
        Schema::create('stock_area', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('area_id');
            $table->unsignedBigInteger('tipo_prenda_id');
            $table->integer('cantidad_total')->default(0);
            $table->integer('cantidad_en_area')->default(0);
            $table->integer('cantidad_en_lavanderia')->default(0);

            $table->foreign('area_id')->references('id')->on('area');
            $table->foreign('tipo_prenda_id')->references('id')->on('tipo_prenda');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('stock_area');
    }
};
