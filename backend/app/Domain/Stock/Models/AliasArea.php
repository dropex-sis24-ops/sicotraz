<?php

namespace App\Domain\Stock\Models;

use Illuminate\Database\Eloquent\Model;

class AliasArea extends Model
{
    protected $table = 'alias_area';

    protected $fillable = ['area_id', 'alias_normalizado', 'activo'];

    protected function casts(): array
    {
        return ['activo' => 'boolean'];
    }
}
