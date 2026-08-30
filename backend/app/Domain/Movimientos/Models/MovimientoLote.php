<?php

namespace App\Domain\Movimientos\Models;

use App\Domain\Usuarios\Models\Usuario;
use Illuminate\Database\Eloquent\Model;

class MovimientoLote extends Model
{
    protected $table = 'movimiento_lote';

    protected $fillable = ['lote_id', 'etapa', 'fecha_hora', 'usuario_id'];

    protected function casts(): array
    {
        return ['fecha_hora' => 'datetime'];
    }

    public function usuario()
    {
        return $this->belongsTo(Usuario::class, 'usuario_id');
    }

    public function lote()
    {
        return $this->belongsTo(Lote::class, 'lote_id');
    }
}
