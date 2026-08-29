<?php

namespace App\Domain\Movimientos\Models;

use App\Domain\Stock\Models\TipoPrenda;
use Illuminate\Database\Eloquent\Model;

class DetalleLote extends Model
{
    protected $table = 'detalle_lote';

    protected $fillable = ['lote_id', 'tipo_prenda_id', 'cantidad'];

    public function tipoPrenda()
    {
        return $this->belongsTo(TipoPrenda::class, 'tipo_prenda_id');
    }
}
