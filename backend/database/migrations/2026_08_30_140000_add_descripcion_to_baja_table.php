<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('baja', function (Blueprint $table): void {
            $table->text('descripcion')->nullable()->after('motivo');
        });
    }

    public function down(): void
    {
        Schema::table('baja', function (Blueprint $table): void {
            $table->dropColumn('descripcion');
        });
    }
};
