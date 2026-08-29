<?php

namespace App\Domain\Stock\Models;

use Illuminate\Database\Eloquent\Model;

class Area extends Model
{
    protected $table = 'area';

    protected $fillable = ['nombre', 'activo'];

    protected function casts(): array
    {
        return ['activo' => 'boolean'];
    }

    public function aliases()
    {
        return $this->hasMany(AliasArea::class, 'area_id');
    }

    public function stocks()
    {
        return $this->hasMany(StockArea::class, 'area_id');
    }
}
