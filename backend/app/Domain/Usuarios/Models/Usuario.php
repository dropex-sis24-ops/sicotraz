<?php

namespace App\Domain\Usuarios\Models;

use App\Domain\Stock\Models\Area;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class Usuario extends Authenticatable
{
    use HasApiTokens;
    use Notifiable;

    protected $table = 'usuario';

    protected $fillable = [
        'nombre',
        'numero_item',
        'carnet_identidad',
        'password_hash',
        'rol_id',
        'area_id',
        'activo',
        'debe_cambiar_password',
        'intentos_fallidos',
        'bloqueado_hasta',
    ];

    protected $hidden = [
        'password_hash',
        'carnet_identidad',
        'remember_token',
    ];

    protected function casts(): array
    {
        return [
            'activo' => 'boolean',
            'debe_cambiar_password' => 'boolean',
            'bloqueado_hasta' => 'datetime',
        ];
    }

    public function rol()
    {
        return $this->belongsTo(Rol::class, 'rol_id');
    }

    public function area()
    {
        return $this->belongsTo(Area::class, 'area_id');
    }
}
