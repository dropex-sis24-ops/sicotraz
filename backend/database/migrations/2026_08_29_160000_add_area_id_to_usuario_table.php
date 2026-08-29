<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('usuario', function (Blueprint $table): void {
            $table->foreignId('area_id')
                ->nullable()
                ->after('rol_id')
                ->constrained('area');
        });
    }

    public function down(): void
    {
        Schema::table('usuario', function (Blueprint $table): void {
            $table->dropConstrainedForeignId('area_id');
        });
    }
};
