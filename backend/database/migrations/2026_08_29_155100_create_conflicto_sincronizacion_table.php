<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('conflicto_sincronizacion', function (Blueprint $table) {
            $table->id();
            $table->string('entidad_tipo');
            $table->unsignedBigInteger('entidad_id');
            $table->json('version_local_json');
            $table->json('version_servidor_json');
            $table->string('estado');
            $table->string('version_elegida')->nullable();
            $table->foreignId('resuelto_por_id')->nullable()->constrained('usuario');
            $table->timestamp('fecha_resolucion')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('conflicto_sincronizacion');
    }
};
