<?php

namespace App\Domain\Costura\Models;

use App\Domain\Stock\Models\Area;
use App\Domain\Stock\Models\TipoPrenda;
use App\Domain\Usuarios\Models\Usuario;
use Illuminate\Database\Eloquent\Model;

class Baja extends Model
{
    protected $table = 'baja';

    protected $fillable = [
        'tipo_prenda_id', 'area_id', 'usuario_costura_id', 'cantidad',
        'motivo', 'descripcion', 'foto_evidencia_url', 'fecha_hora',
        'sincronizado', 'fecha_ultima_modificacion', 'uuid_local', 'sync_payload_hash',
    ];

    protected function casts(): array
    {
        return [
            'fecha_hora' => 'datetime',
            'sincronizado' => 'boolean',
            'fecha_ultima_modificacion' => 'datetime',
        ];
    }

    public function area()
    {
        return $this->belongsTo(Area::class, 'area_id');
    }

    public function tipoPrenda()
    {
        return $this->belongsTo(TipoPrenda::class, 'tipo_prenda_id');
    }

    public function usuarioCostura()
    {
        return $this->belongsTo(Usuario::class, 'usuario_costura_id');
    }
}
