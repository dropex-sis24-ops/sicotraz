<!doctype html>
<html lang="es">
<head><meta charset="utf-8"><style>
@page { margin: 18mm; } body { font-family: DejaVu Sans, sans-serif; font-size: 10pt; color: #14213d; }
h1 { font-size: 16pt; text-align: center; margin: 0; } h2 { font-size: 11pt; text-align: center; margin: 6px 0 18px; }
.meta { width: 100%; margin-bottom: 16px; } .meta td { padding: 5px 0; } .line { border-bottom: 1px solid #222; min-width: 220px; display: inline-block; }
table { width: 100%; border-collapse: collapse; } th { background: #1f5d7a; color: white; padding: 8px; text-align: left; } td { border: 1px solid #3c4a56; padding: 8px; height: 21px; } .quantity { width: 27%; }
.footer { margin-top: 28px; font-size: 8pt; color: #555; text-align: center; }
.compact h2 { margin-bottom: 10px; }
.compact .meta { margin-bottom: 9px; }
.compact .meta td { padding: 3px 0; }
.compact th { padding: 5px 8px; }
.compact td { padding: 4px 8px; height: 15px; }
.compact .footer { margin-top: 10px; }
</style></head>
<body class="{{ $plantilla->nombre === 'Quirófano' ? 'compact' : '' }}">
<h1>SICOTRAZ</h1><h2>Formulario de entrega de ropa - {{ $plantilla->nombre }}</h2>
<table class="meta"><tr><td>Servicio: <span class="line">{{ $area?->nombre }}</span></td><td>Fecha: <span class="line">&nbsp;</span></td></tr><tr><td>Código / ítem: <span class="line">&nbsp;</span></td><td>Nombre: <span class="line">&nbsp;</span></td></tr></table>
<table><thead><tr><th>Prenda / artículo</th><th class="quantity">Cantidad</th></tr></thead><tbody>@foreach($prendas as $prenda)<tr><td>{{ $prenda }}</td><td></td></tr>@endforeach</tbody></table>
<p class="footer">Formato de uso interno - completar legiblemente antes de entregar la ropa.</p>
</body></html>
