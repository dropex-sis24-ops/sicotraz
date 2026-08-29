<?php

namespace App\Domain\Alertas\Models;

use App\Domain\Stock\Models\Area;
use App\Domain\Stock\Models\TipoPrenda;
use App\Domain\Usuarios\Models\Usuario;
use Illuminate\Database\Eloquent\Model;

class Alerta extends Model
{
    protected $table = 'alerta';

    protected $fillable = [
        'area_id', 'tipo_prenda_id', 'usuario_reporta_id', 'fecha_hora_reporte',
        'descripcion', 'foto_evidencia_url', 'estado', 'usuario_resuelve_id',
        'fecha_resolucion', 'nota_resolucion', 'sincronizado',
        'fecha_ultima_modificacion',
    ];

    protected function casts(): array
    {
        return [
            'fecha_hora_reporte' => 'datetime',
            'fecha_resolucion' => 'datetime',
            'sincronizado' => 'boolean',
            'fecha_ultima_modificacion' => 'datetime',
        ];
    }

    public function area()
    {
        return $this->belongsTo(Area::class, 'area_id');
    }

    public function tipoPrenda()
    {
        return $this->belongsTo(TipoPrenda::class, 'tipo_prenda_id');
    }

    public function reporta()
    {
        return $this->belongsTo(Usuario::class, 'usuario_reporta_id');
    }

    public function resuelve()
    {
        return $this->belongsTo(Usuario::class, 'usuario_resuelve_id');
    }
}
