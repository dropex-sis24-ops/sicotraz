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
        Schema::create('verificacion_stock', function (Blueprint $table) {
            $table->id();
            $table->foreignId('area_id')->constrained('area');
            $table->foreignId('usuario_id')->constrained('usuario');
            $table->timestamp('fecha_hora');
            $table->string('resultado');
            $table->text('observacion')->nullable();
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
        Schema::dropIfExists('verificacion_stock');
    }
};
