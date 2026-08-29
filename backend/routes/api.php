<?php

use App\Domain\Auth\Http\Controllers\AuthController;
use App\Domain\Stock\Http\Controllers\CatalogoController;
use App\Domain\Stock\Http\Controllers\StockController;
use App\Domain\Stock\Http\Controllers\VerificacionStockController;
use App\Domain\Usuarios\Http\Controllers\UsuarioController;
use Illuminate\Support\Facades\Route;

Route::post('/login', [AuthController::class, 'login']);

Route::middleware('auth:sanctum')->group(function (): void {
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::post('/cambiar-password', [AuthController::class, 'cambiarPassword']);
});

Route::middleware(['auth:sanctum', 'role:Super Admin'])->group(function (): void {
    Route::get('/usuarios', [UsuarioController::class, 'index']);
    Route::post('/usuarios', [UsuarioController::class, 'store']);
    Route::put('/usuarios/{usuario}', [UsuarioController::class, 'update']);
    Route::patch('/usuarios/{usuario}/desactivar', [UsuarioController::class, 'desactivar']);
    Route::patch('/usuarios/{usuario}/reactivar', [UsuarioController::class, 'reactivar']);
    Route::patch('/usuarios/{usuario}/desbloquear', [UsuarioController::class, 'desbloquear']);
    Route::post('/usuarios/{usuario}/resetear-password', [UsuarioController::class, 'resetearPassword']);
    Route::get('/catalogo/prendas', [CatalogoController::class, 'prendas']);
    Route::post('/catalogo/prendas', [CatalogoController::class, 'crearPrenda']);
    Route::patch('/catalogo/prendas/{prenda}', [CatalogoController::class, 'actualizarPrenda']);
    Route::get('/catalogo/areas', [CatalogoController::class, 'areas']);
    Route::post('/catalogo/areas', [CatalogoController::class, 'crearArea']);
    Route::patch('/catalogo/areas/{area}', [CatalogoController::class, 'actualizarArea']);
    Route::post('/catalogo/areas/{area}/alias', [CatalogoController::class, 'crearAlias']);
    Route::patch('/catalogo/alias/{alias}', [CatalogoController::class, 'actualizarAlias']);
    Route::get('/catalogo/plantillas', [CatalogoController::class, 'plantillas']);
    Route::patch('/catalogo/plantillas/{plantilla}', [CatalogoController::class, 'actualizarPlantilla']);
    Route::post('/stock/carga-inicial', [StockController::class, 'cargaInicial']);
    Route::get('/stock/area', [StockController::class, 'porArea']);
});

Route::middleware(['auth:sanctum', 'role:Personal manual'])->group(function (): void {
    Route::get('/stock/verificacion', [StockController::class, 'verificacion']);
    Route::post('/stock/verificacion', [VerificacionStockController::class, 'store']);
});
