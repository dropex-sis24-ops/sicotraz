<?php

use App\Domain\Alertas\Http\Controllers\AlertaController;
use App\Domain\Auth\Http\Controllers\AuthController;
use App\Domain\Costura\Http\Controllers\BajaController;
use App\Domain\Movimientos\Http\Controllers\LoteController;
use App\Domain\OCR\Http\Controllers\PlantillaPdfController;
use App\Domain\Reportes\Http\Controllers\ReporteController;
use App\Domain\Stock\Http\Controllers\CatalogoController;
use App\Domain\Stock\Http\Controllers\StockController;
use App\Domain\Stock\Http\Controllers\VerificacionStockController;
use App\Domain\Sync\Http\Controllers\SyncController;
use App\Domain\Usuarios\Http\Controllers\UsuarioController;
use App\Http\Controllers\ArchivoController;
use Illuminate\Support\Facades\Route;

Route::post('/login', [AuthController::class, 'login']);

Route::middleware('auth:sanctum')->group(function (): void {
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::post('/cambiar-password', [AuthController::class, 'cambiarPassword']);
    Route::get('/catalogo/prendas', [CatalogoController::class, 'prendas']);
    Route::get('/catalogo/areas', [CatalogoController::class, 'areas']);
    Route::get('/catalogo/plantillas', [CatalogoController::class, 'plantillas']);
    Route::post('/archivos', [ArchivoController::class, 'store']);
    Route::post('/sync', [SyncController::class, 'store']);
    Route::get('/sync/conflictos', [SyncController::class, 'index']);
});

Route::middleware(['auth:sanctum', 'role:Super Admin,Encargado de Ropería y Lavandería'])
    ->patch('/sync/conflictos/{conflicto}/resolver', [SyncController::class, 'resolver']);

Route::middleware(['auth:sanctum', 'role:Super Admin'])->group(function (): void {
    Route::get('/usuarios', [UsuarioController::class, 'index']);
    Route::post('/usuarios', [UsuarioController::class, 'store']);
    Route::put('/usuarios/{usuario}', [UsuarioController::class, 'update']);
    Route::patch('/usuarios/{usuario}/desactivar', [UsuarioController::class, 'desactivar']);
    Route::patch('/usuarios/{usuario}/reactivar', [UsuarioController::class, 'reactivar']);
    Route::patch('/usuarios/{usuario}/desbloquear', [UsuarioController::class, 'desbloquear']);
    Route::post('/usuarios/{usuario}/resetear-password', [UsuarioController::class, 'resetearPassword']);
    Route::post('/catalogo/prendas', [CatalogoController::class, 'crearPrenda']);
    Route::patch('/catalogo/prendas/{prenda}', [CatalogoController::class, 'actualizarPrenda']);
    Route::post('/catalogo/areas', [CatalogoController::class, 'crearArea']);
    Route::patch('/catalogo/areas/{area}', [CatalogoController::class, 'actualizarArea']);
    Route::post('/catalogo/areas/{area}/alias', [CatalogoController::class, 'crearAlias']);
    Route::patch('/catalogo/alias/{alias}', [CatalogoController::class, 'actualizarAlias']);
    Route::patch('/catalogo/plantillas/{plantilla}', [CatalogoController::class, 'actualizarPlantilla']);
    Route::post('/stock/carga-inicial', [StockController::class, 'cargaInicial']);
    Route::get('/stock/area', [StockController::class, 'porArea']);
});

Route::middleware(['auth:sanctum', 'role:Personal manual'])->group(function (): void {
    Route::get('/stock/verificacion', [StockController::class, 'verificacion']);
    Route::post('/stock/verificacion', [VerificacionStockController::class, 'store']);
});

Route::middleware(['auth:sanctum', 'role:Ropera,Encargado de Ropería y Lavandería'])->group(function (): void {
    Route::get('/lotes/formulario', [LoteController::class, 'formulario']);
    Route::post('/lotes', [LoteController::class, 'store']);
    Route::patch('/lotes/{lote}/etapa', [LoteController::class, 'avanzarEtapa']);
    Route::post('/lotes/{lote}/entrega-limpia', [LoteController::class, 'entregaLimpia']);
});

Route::middleware(['auth:sanctum', 'role:Super Admin,Encargado de Ropería y Lavandería'])->get('/plantillas/pdf', [PlantillaPdfController::class, 'descargar']);

Route::middleware(['auth:sanctum', 'role:Costura'])->post('/bajas', [BajaController::class, 'store']);
Route::middleware(['auth:sanctum', 'role:Costura,Super Admin,Encargado de Ropería y Lavandería'])->get('/bajas', [BajaController::class, 'index']);

Route::middleware(['auth:sanctum', 'role:Super Admin,Encargado de Ropería y Lavandería'])->group(function (): void {
    Route::get('/dashboard', [ReporteController::class, 'dashboard']);
    Route::get('/stock/circulando', [ReporteController::class, 'circulando']);
});
Route::middleware(['auth:sanctum', 'role:Super Admin'])->group(function (): void {
    Route::get('/reportes/cantidad-peso', [ReporteController::class, 'cantidadPeso']);
    Route::get('/reportes/bajas-vs-faltantes', [ReporteController::class, 'bajasVsFaltantes']);
});

Route::middleware('auth:sanctum')->group(function (): void {
    Route::get('/lotes/{lote}', [LoteController::class, 'show']);
    Route::get('/historial', [LoteController::class, 'historial']);
});

Route::middleware(['auth:sanctum', 'role:Ropera,Encargado de Ropería y Lavandería,Super Admin'])->patch('/lotes/{lote}', [LoteController::class, 'actualizar']);

Route::middleware(['auth:sanctum', 'role:Personal manual,Ropera,Encargado de Ropería y Lavandería'])->post('/alertas', [AlertaController::class, 'store']);
Route::middleware(['auth:sanctum', 'role:Ropera,Encargado de Ropería y Lavandería,Super Admin'])->get('/alertas', [AlertaController::class, 'index']);
Route::middleware(['auth:sanctum', 'role:Ropera,Encargado de Ropería y Lavandería'])->patch('/alertas/{alerta}/resolver', [AlertaController::class, 'resolver']);
