<?php

namespace App\Domain\Stock\Models;

use Illuminate\Database\Eloquent\Model;

class TipoPrenda extends Model
{
    protected $table = 'tipo_prenda';

    protected $fillable = ['nombre', 'activo'];
}
