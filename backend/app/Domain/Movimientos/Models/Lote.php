<?php

namespace App\Domain\Movimientos\Models;

use App\Domain\Stock\Models\Area;
use App\Domain\Stock\Models\PlantillaFormulario;
use App\Domain\Usuarios\Models\Usuario;
use Illuminate\Database\Eloquent\Model;

class Lote extends Model
{
    protected $table = 'lote';

    protected $fillable = [
        'area_id', 'etapa', 'fecha_hora', 'peso_kg', 'usuario_entrega_id',
        'usuario_registra_id', 'usuario_recibe_id', 'origen_registro',
        'plantilla_id', 'nombre_quien_trae', 'sincronizado',
        'fecha_ultima_modificacion', 'uuid_local', 'sync_payload_hash',
    ];

    protected function casts(): array
    {
        return [
            'fecha_hora' => 'datetime',
            'peso_kg' => 'decimal:2',
            'sincronizado' => 'boolean',
            'fecha_ultima_modificacion' => 'datetime',
        ];
    }

    public function area()
    {
        return $this->belongsTo(Area::class, 'area_id');
    }

    public function detalles()
    {
        return $this->hasMany(DetalleLote::class, 'lote_id');
    }

    public function movimientos()
    {
        return $this->hasMany(MovimientoLote::class, 'lote_id');
    }

    public function registra()
    {
        return $this->belongsTo(Usuario::class, 'usuario_registra_id');
    }

    public function entrega()
    {
        return $this->belongsTo(Usuario::class, 'usuario_entrega_id');
    }

    public function recibe()
    {
        return $this->belongsTo(Usuario::class, 'usuario_recibe_id');
    }

    public function plantilla()
    {
        return $this->belongsTo(PlantillaFormulario::class, 'plantilla_id');
    }
}
