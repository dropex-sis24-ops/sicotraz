<?php

namespace App\Domain\Stock\Models;

use Illuminate\Database\Eloquent\Model;

class TipoPrenda extends Model
{
    protected $table = 'tipo_prenda';

    protected $fillable = ['nombre', 'activo'];

    protected function casts(): array
    {
        return ['activo' => 'boolean'];
    }

    public function stocks()
    {
        return $this->hasMany(StockArea::class, 'tipo_prenda_id');
    }
}
