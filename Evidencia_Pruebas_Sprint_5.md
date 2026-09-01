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
- Android físico: APK arm64 build 2006 instalada en el dispositivo `a3fd45f0`; actividad principal abierta y mantenida en primer plano sin excepción fatal. Build 2008 compilada con filtrado de prendas por plantilla, edición de carnet y eliminación controlada de usuarios; instalación pendiente porque el dispositivo se desconectó de ADB.
- API de desarrollo: respuesta HTTP 200 mediante el dominio ngrok configurado.
- Artefacto: `mobile/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`, build 2008, 28.4 MB.
- SHA-256: `acc9dc32e5b07ddc8e80c550052d8903fc122e1bb4aebc5bfdcaaf846fc6d895`.

La prueba operativa con usuarios reales y datos institucionales queda para la validación de campo; no modifica el cierre técnico del sprint.
