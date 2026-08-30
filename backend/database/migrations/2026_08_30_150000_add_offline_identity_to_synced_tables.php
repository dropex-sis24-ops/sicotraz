<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    private const TABLES = ['lote', 'alerta', 'baja', 'verificacion_stock'];

    public function up(): void
    {
        foreach (self::TABLES as $tableName) {
            Schema::table($tableName, function (Blueprint $table): void {
                $table->uuid('uuid_local')->nullable()->unique();
                $table->string('sync_payload_hash', 64)->nullable();
            });
        }
    }

    public function down(): void
    {
        foreach (self::TABLES as $tableName) {
            Schema::table($tableName, function (Blueprint $table): void {
                $table->dropUnique(['uuid_local']);
                $table->dropColumn(['uuid_local', 'sync_payload_hash']);
            });
        }
    }
};
