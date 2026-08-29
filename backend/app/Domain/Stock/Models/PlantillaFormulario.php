<?php

namespace App\Domain\Stock\Models;

use Illuminate\Database\Eloquent\Model;

class PlantillaFormulario extends Model
{
    protected $table = 'plantilla_formulario';

    protected $fillable = ['nombre', 'estructura_campos', 'activo'];

    protected function casts(): array
    {
        return ['estructura_campos' => 'array', 'activo' => 'boolean'];
    }
}
