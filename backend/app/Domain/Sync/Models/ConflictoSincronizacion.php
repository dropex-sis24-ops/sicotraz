<?php

namespace App\Domain\Sync\Models;

use App\Domain\Usuarios\Models\Usuario;
use Illuminate\Database\Eloquent\Model;

class ConflictoSincronizacion extends Model
{
    protected $table = 'conflicto_sincronizacion';

    protected $fillable = [
        'entidad_tipo', 'entidad_id', 'version_local_json',
        'version_servidor_json', 'estado', 'version_elegida',
        'resuelto_por_id', 'fecha_resolucion',
    ];

    protected function casts(): array
    {
        return [
            'version_local_json' => 'array',
            'version_servidor_json' => 'array',
            'fecha_resolucion' => 'datetime',
        ];
    }

    public function resueltoPor()
    {
        return $this->belongsTo(Usuario::class, 'resuelto_por_id');
    }
}
