<?php

namespace App\Domain\Stock\Models;

use Illuminate\Database\Eloquent\Model;

class StockArea extends Model
{
    protected $table = 'stock_area';

    public $timestamps = false;

    protected $fillable = [
        'area_id',
        'tipo_prenda_id',
        'cantidad_total',
        'cantidad_en_area',
        'cantidad_en_lavanderia',
    ];
}
