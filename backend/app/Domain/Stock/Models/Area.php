<?php

namespace App\Domain\Stock\Models;

use Illuminate\Database\Eloquent\Model;

class Area extends Model
{
    protected $table = 'area';

    protected $fillable = ['nombre', 'activo'];
}
