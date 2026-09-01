# Evidencia de pruebas — cierre Sprint 5

Fecha: 30/08/2026

| Épica | Flujo representativo verificado | Evidencia | Resultado |
|---|---|---|---|
| 1. Autenticación | Login, bloqueo, cambio de contraseña y permisos por rol | `AuthFeatureTest` | Aprobado |
| 2. OCR | Lectura local de Salas/Quirófano, normalización, revisión y PDF | pruebas OCR Flutter + `PlantillaPdfFeatureTest` | Aprobado |
| 3. Stock | Carga inicial y verificación con/sin irregularidad | `StockAndCatalogFeatureTest` | Aprobado |
| 4. Movimientos | Lote manual, regla 06:30–16:30 de Quirófano, etapas, entrega y alertas | `MovimientosYAlertasFeatureTest` | Aprobado |
| 5. Costura | Baja permanente y descuento transaccional de stock | `Sprint4FeatureTest` | Aprobado |
| 6. Reportes | Dashboard, cantidad/peso y bajas separadas de faltantes | `Sprint4FeatureTest` | Aprobado |
| 7. Offline | Cola SQLite, idempotencia, conflicto, conservación de ambas versiones y resolución autorizada | `Sprint5SyncFeatureTest` + prueba de esquema Flutter | Aprobado |

## Resultado consolidado

- Backend: 29 pruebas, 158 verificaciones, todas aprobadas.
- Flutter: análisis estático sin observaciones y 7 pruebas aprobadas.
- Base local: migración del Sprint 5 aplicada en MySQL.
- Android físico: APK arm64 build 2006 instalada en el dispositivo `a3fd45f0`; actividad principal abierta y mantenida en primer plano sin excepción fatal. Build 2009 compilada con filtrado de prendas por plantilla, edición de carnet, eliminación controlada de usuarios y ajuste visual del formulario; instalación pendiente porque el dispositivo se desconectó de ADB.
- API de desarrollo: respuesta HTTP 200 mediante el dominio ngrok configurado.
- Artefacto: `mobile/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`, build 2009, 28.4 MB.
- SHA-256: `9fa1c8b5acb19d564a640669eaca36d69dffff29db0d0d5c4f7cb3019087e25c`.

La prueba operativa con usuarios reales y datos institucionales queda para la validación de campo; no modifica el cierre técnico del sprint.
