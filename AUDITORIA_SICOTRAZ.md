# Auditoría técnica de SICOTRAZ

Fecha: 6 de octubre de 2026 · Alcance: `backend/` (Laravel 13 + Sanctum) y `mobile/` (Flutter, offline-first).

Estado de partida: 29 tests verdes, Pint y `flutter analyze` sin avisos. Los 34 problemas de este
informe no los detectaba ninguna de esas herramientas: son fallos de lógica, de concurrencia y de
reglas de negocio.

Estado final: **43 tests en el backend**, **11 en el móvil**, linters limpios.

---

## 1. Los cinco problemas más graves

### 1.1 El conteo de inventario se autoconfirmaba — RESUELTO
`mobile/lib/features/stock/presentation/stock_verification_screen.dart`

La pantalla de verificación de turno mostraba `Esperado: N` junto a cada casilla y, si el operario no
escribía nada, enviaba **ese mismo N** como cantidad contada. El control de inventario —el motivo por
el que existe la pantalla— quedaba anulado: nunca podía detectar un faltante.

Ahora el conteo es a ciegas, no se muestra la cantidad esperada, y el formulario exige un número por
prenda (0 incluido) antes de permitir el registro.

### 1.2 Toda la aplicación guardaba fechas en dos zonas horarias distintas — RESUELTO
`backend/config/app.php`, 18 llamadas en 6 controladores

`config/app.php` fijaba `timezone => 'UTC'`, pero los controladores escribían `now('America/La_Paz')`
en las columnas `datetime`. Al leerlas, Eloquent las interpretaba como UTC. Consecuencias medidas:

- **La Ropera no podía corregir ningún lote.** `autorizarCorreccion()` compara
  `$lote->fecha_hora > now()->subHour()`: con el desfase de 4 h, un lote recién creado daba `false`.
  La ventana de corrección de una hora era inalcanzable siempre.
- Las verificaciones de stock (`now()`, UTC) quedaban fuera del rango de los reportes mensuales
  durante 4 h, mientras los lotes (hora local) sí entraban.
- El horario automático de Quirófano (06:30–16:30) se evaluaba contra una hora desplazada.

Ahora la zona de la aplicación es `America/La_Paz` (vía `APP_TIMEZONE`) y todas las llamadas usan
`now()`. Una única fuente de verdad.

### 1.3 Un corte de red duplicaba lotes y descontaba el stock dos veces — RESUELTO
`mobile/lib/core/sync/sync_controller.dart`

El `uuid_local` se generaba **al encolar**, no al crear el registro. El camino en línea no enviaba
ninguno. Si el POST llegaba al servidor pero la respuesta se perdía (timeout, cosa habitual en una red
hospitalaria), el `catch` encolaba el registro con un uuid **nuevo**, el servidor no lo reconocía y
creaba un segundo lote con su segundo descuento de inventario.

Ahora el identificador se fija antes del primer intento y acompaña al registro en línea y en la cola,
de modo que el servidor reconoce el reenvío como el mismo registro.

### 1.4 Un doble toque creaba prendas de la nada — RESUELTO
`backend/app/Domain/Movimientos/Http/Controllers/LoteController.php`

`entregaLimpia()` comprobaba `etapa === 'en_lavado'` **fuera** de la transacción y no volvía a
comprobarlo dentro. Dos peticiones concurrentes ejecutaban `devolverAlArea()` dos veces: el stock
volvía al área duplicado. Lo mismo en `avanzarEtapa()`, que registraba el movimiento dos veces.

Ahora ambos releen el lote con `lockForUpdate()` y revalidan la etapa dentro de la transacción.
Test: `test_the_stage_cannot_be_advanced_twice_for_the_same_lote`.

### 1.5 Una baja dejaba el lote atascado para siempre — RESUELTO
`backend/app/Domain/Movimientos/Http/Controllers/LoteController.php`

Si Costura daba de baja una prenda que viajaba en un lote en lavandería, `devolverAlArea()` abortaba
con 422 al intentar la entrega limpia. El lote quedaba en `en_lavado` **de forma permanente**, con su
stock inmovilizado y sin ninguna vía de solución desde la aplicación.

Ahora la entrega devuelve lo que queda, informa de las prendas dadas de baja en el campo `aviso` de
la respuesta, y la app lo muestra. Test: `test_a_lote_can_be_closed_even_if_its_clothes_were_written_off`.

---

## 2. Seguridad y autorización

| # | Problema | Estado |
|---|---|---|
| 2.1 | **Cambio de contraseña sin la contraseña actual.** Un token robado permitía apropiarse de la cuenta de forma permanente, y las sesiones de otros equipos seguían vivas. | Resuelto: se exige `password_actual`, debe ser distinta de la nueva, y se revocan los demás tokens |
| 2.2 | **Login sin límite de peticiones.** El N° de ítem es público en el hospital; el bloqueo por cuenta no impedía enumerar cuentas ni atacar en paralelo. | Resuelto: `throttle:10,1` en login, `throttle:30,1` en subida de archivos |
| 2.3 | **`GET /stock/verificacion?area_id=N` filtraba stock entre áreas.** El POST sí validaba el área del usuario; el GET no. Cualquier Personal manual veía el inventario de cualquier servicio. | Resuelto |
| 2.4 | **`GET /historial` sin filtro de área.** El Personal manual accede a esta pantalla ("Ver última lista") y veía el movimiento de todo el hospital. | Resuelto: quien tiene área asignada solo ve la suya |
| 2.5 | **`GET /sync/conflictos` exponía el contenido completo** (`version_local_json`) de los registros en conflicto de todas las áreas a cualquier usuario autenticado, sin paginar. | Resuelto: cada usuario ve solo los conflictos de sus registros; los roles responsables, todos |
| 2.6 | **`foto_evidencia_url` era texto libre de 2048 caracteres.** Se podía almacenar cualquier URL externa y hacer que la app la mostrara. | Resuelto: solo se aceptan rutas emitidas por la propia API |
| 2.7 | **`per_page` sin tope** en 4 listados: `per_page=1000000` agotaba la memoria del servidor. | Resuelto: máximo 100 |
| 2.8 | **El sistema se podía quedar sin administrador.** `desactivar` permitía autodesactivarse (borrando los tokens), `update` permitía quitarse el propio rol, y el comando de creación se niega a crear un segundo Super Admin: recuperación solo por SQL manual. | Resuelto: se exige al menos un Super Admin activo |
| 2.9 | **La sesión guardada no se validaba al arrancar.** Con un token revocado la app arrancaba "autenticada" y todo fallaba, sin manejo de 401 ni vuelta al login. | Resuelto: se valida al restaurar y un 401 cierra la sesión desde cualquier pantalla |
| 2.10 | **Cerrar sesión no limpiaba el dispositivo.** En una tablet compartida, la cola pendiente del turno anterior se sincronizaba **con el token del usuario siguiente**, atribuyéndole registros ajenos; la caché filtraba datos de otras áreas. | Resuelto: `clearDeviceData()` al cerrar o perder la sesión |

**Nota sobre las evidencias fotográficas:** se guardan en el disco `public` y se sirven en
`/storage/...` sin autenticación. Quien tenga la URL puede verlas. Mitigado (solo se aceptan rutas
propias), pero el acceso sigue siendo público: ver propuesta 5.4.

---

## 3. Integridad de datos

| # | Problema | Estado |
|---|---|---|
| 3.1 | **`usuario.numero_item` sin índice único en MySQL** (solo validación de aplicación). Dos usuarios con el mismo número hacen que el login devuelva uno arbitrario. | Resuelto |
| 3.2 | **`stock_area` sin clave única `(area_id, tipo_prenda_id)`.** `firstOrNew` en concurrencia crea dos filas para el mismo par: el stock se parte y las validaciones dejan de ser fiables. | Resuelto |
| 3.3 | **`alias_area.alias_normalizado` sin unicidad.** Dos áreas con el mismo alias vuelven ambigua la resolución del OCR. | Resuelto (clave única + validación con mensaje claro) |
| 3.4 | **`foto_evidencia_url` validada a 2048 caracteres contra una columna `VARCHAR(255)`:** error SQL 1406 → respuesta 500. | Resuelto: columna a 2048 |
| 3.5 | **`rol.nombre`, `area.nombre`, `tipo_prenda.nombre` sin unicidad**, pese a que toda la lógica de permisos y de plantillas los compara por texto. | Resuelto |
| 3.6 | **Sin índices** en `lote.fecha_hora`, `lote.etapa`, `movimiento_lote(etapa, fecha_hora)`, `alerta(estado, …)`, `baja.fecha_hora`: los reportes recorren la tabla completa. | Resuelto |
| 3.7 | **Renombrar una prenda la sacaba de los formularios.** Las plantillas referencian las prendas por **nombre** en `estructura_campos`; al renombrar, desaparecía del formulario de ingreso sin aviso. | Resuelto: el cambio se propaga a las plantillas |
| 3.8 | **Renombrar el área "Quirófano" anulaba sus reglas.** El ingreso automático en horario, la plantilla y la ventana de corrección se deciden comparando `$area->nombre === 'Quirófano'`. | Resuelto: se bloquea el renombrado con un mensaje que explica por qué |
| 3.9 | **`estructura_campos` aceptaba cualquier forma.** Una plantilla sin la clave `tipos_prenda` dejaba el formulario de ingreso vacío, sin ningún error. Un test existente consolidaba precisamente un formato (`campos`) que ningún código lee. | Resuelto: se valida `tipos_prenda` y que las prendas existan; **se corrigió ese test** |
| 3.10 | **Se podía desactivar un área o una prenda con stock en circulación.** | Resuelto |
| 3.11 | **`GET /catalogo/prendas` devolvía las prendas inactivas**, al contrario que el formulario de lotes. | Resuelto |
| 3.12 | **Un N° de ítem inexistente devolvía `404 No query results`**, un mensaje de Eloquent sin sentido para el usuario; además admitía cuentas desactivadas. | Resuelto: 422 con el número concreto |

---

## 4. Sincronización offline

| # | Problema | Estado |
|---|---|---|
| 4.1 | **Un registro inválido abortaba el lote entero.** `abort_unless(rol permitido)` dentro del bucle lanzaba 403 y descartaba la respuesta de los registros ya guardados; el dispositivo no sabía qué se había persistido y reintentaba todo. | Resuelto: rechazo por registro en un nuevo array `rechazados`, una transacción por registro |
| 4.2 | **Bucle infinito de conflictos.** Al resolver quedándose con la versión del servidor, el `sync_payload_hash` seguía siendo el antiguo: el dispositivo reenviaba su versión, el hash seguía difiriendo y se creaba **otro conflicto idéntico en cada sincronización**. | Resuelto: se sella el hash de la versión descartada. Test incluido |
| 4.3 | **Cola envenenada.** Un registro que el servidor siempre rechaza se reintentaba cada 15 s indefinidamente, bloqueando los demás. La columna `intentos` existía pero **nunca se incrementaba**. | Resuelto: máximo 5 intentos, aviso en el banner y reintento manual |
| 4.4 | **La versión local se escribía sin validar.** `actualizarBasico()` hacía `UPDATE` con `Arr::only()` del JSON del dispositivo: se podía grabar un peso negativo o un `area_id` inexistente. | Resuelto: reglas de validación por tipo de entidad |
| 4.5 | **Reordenar los detalles generaba un conflicto falso.** El hash ordenaba las claves de los objetos pero no los elementos de las listas. | Resuelto. Test incluido |
| 4.6 | **Fotos huérfanas.** Si la subida tenía éxito y el POST fallaba, al sincronizar se volvía a subir la misma foto, acumulando copias en el servidor. | Resuelto: se reutiliza la URL ya obtenida |
| 4.7 | **La fecha de modificación la ponía el dispositivo.** Un reloj desajustado dejaba registros fechados en el futuro. | Resuelto: la pone el servidor |
| 4.8 | **`aplicarVerificacion` no bloqueaba la fila**, al contrario que `aplicarLote` y `aplicarBaja`. | Resuelto |
| 4.9 | **Sin timeout en las peticiones HTTP:** en una red mala, la pantalla se quedaba colgada en lugar de pasar al modo sin conexión. | Resuelto: 20 s (60 s en subidas) |
| 4.10 | **Los errores 422 llegaban como un mensaje genérico.** Laravel pone el detalle en `errors`, que la app descartaba, y varias pantallas mostraban el `toString()` de la excepción. | Resuelto: `ApiException.fromBody` prioriza el error del campo |
| 4.11 | **`_refreshConflicts` lanzaba y marcaba la sesión como desconectada** aun estando en línea. | Resuelto |
| 4.12 | **`conflicts()` y `resolveConflict()` usaban `_token!`**: la app rompía si la sesión había terminado. | Resuelto |
| 4.13 | **Mensajes de validación en inglés** en una aplicación en español, porque `APP_LOCALE=en` y no existía `lang/`. | Resuelto: `lang/es` con los atributos del dominio |

---

## 5. Cuestiones que no tienen lógica, y propuestas

Estas son decisiones de producto: las documento con su razonamiento, no las he implementado.

### 5.1 El reporte "bajas vs faltantes" compara cosas que no son comparables — IMPORTANTE
`ReporteController::bajasVsFaltantes` devuelve `bajas_confirmadas` en **prendas** y
`faltantes_pendientes` en **número de alertas**. Y la causa de fondo es que **`alerta` no tiene
columna `cantidad`**: el modelo no permite expresar "faltan 3 sábanas", solo "hay un problema con las
sábanas". El reporte comparativo que pide el RF27 no se puede construir con este modelo.

Hay un segundo defecto: solo cuenta las alertas en estado `pendiente`, así que **resolver una alerta
la borra del histórico**. Un reporte de agosto cambia según lo que se resuelva en octubre.

> **Propuesta:** añadir `cantidad` a `alerta` (y un tipo: faltante / deterioro / otro), y que el
> reporte cuente **todas** las alertas del período con su estado como dimensión, no como filtro.

### 5.2 "Perdida" no es una baja
`BajaController::MOTIVOS` incluye `'Perdida'` junto a `'Rota / rasgada'` y `'Quemada'`. Las tres
descuentan de `cantidad_total` por igual. Pero una prenda perdida puede reaparecer, y mezclarla con
las bajas por deterioro distorsiona justamente el indicador de 5.1: una pérdida se registra como
"baja confirmada" cuando conceptualmente es un faltante.

> **Propuesta:** separar "extravío" de "baja por deterioro", con un flujo de reaparición que
> reincorpore el stock. Si se mantienen juntos, al menos distinguirlos en el reporte.

### 5.3 El inventario no se puede corregir
`StockController::cargaInicial` solo **suma**. Si el administrador carga 100 en lugar de 10, no existe
ningún endpoint para corregirlo: ni ajuste, ni resta, ni traslado entre áreas. La única salida es SQL
manual. Y el límite de 999 por par área/prenda es arbitrario y no está documentado.

> **Propuesta:** un endpoint de ajuste de inventario con motivo obligatorio y registro de auditoría
> (quién, cuándo, de cuánto a cuánto). Es el complemento natural de la verificación de turno: hoy el
> sistema detecta una diferencia pero no ofrece forma de regularizarla.

### 5.4 Las fotos de evidencia de un hospital son públicas
Se guardan en el disco `public` y se sirven en `/storage/...` sin autenticación.

> **Propuesta:** disco privado y un endpoint autenticado que valide el rol antes de servir el
> archivo. En un entorno hospitalario conviene además una política de retención.

### 5.5 El 88 % del esquema local es código muerto
`DatabaseSchema` define 17 tablas espejo del esquema de Laravel, pero el código solo usa dos:
`pendiente_sincronizacion` y `cache_api`. Las otras 15 se crean en cada dispositivo y nunca se leen ni
se escriben. Esto tiene una consecuencia funcional: **sin conexión, el usuario no puede consultar lo
que registró**, porque el historial depende de `cachedGet` contra el servidor. El "offline-first" es
en realidad una cola de envío más una caché de lecturas.

Detalles asociados: el espejo no tiene las columnas `uuid_local`/`sync_payload_hash` que el backend
añadió (pese al comentario "debe mantenerse alineado"), su `CHECK (… BETWEEN 0 AND 999)` es más
estricto que MySQL, e incluye una columna `password_hash` en `usuario` que sugiere una intención de
login offline nunca implementada —algo que conviene no implementar así.

> **Propuesta:** decidir. O se usan esas tablas para un modo offline real (y entonces hay que
> alinearlas y migrarlas), o se eliminan. Mantenerlas a medias es el peor de los dos mundos.
>
> Nota: durante esta auditoría cambié `onUpgrade` para crear las tablas **por nombre** en lugar de por
> índice posicional (`statements[15]`, `statements[16]`), que se rompía en silencio al insertar
> cualquier tabla en medio de la lista.

### 5.6 El OCR asignaba cantidades a la prenda equivocada — MITIGADO
`OcrCatalogMatcher.clothes` aceptaba `base.contains(value)` y se quedaba con la **primera**
coincidencia del catálogo. "Sábanas" casaba con "Sábanas Superiores" y "Sábanas Inferiores", y se
asignaba a cualquiera de las dos sin avisar. Dos líneas de la misma prenda se sobrescribían en lugar
de sumarse. En las áreas, "Sala 1" casaba con "Sala 10". Y el separador de filas incluía el guion, así
que "Cubre-camas 7" se leía como la prenda "Cubre".

Resuelto: la coincidencia parcial solo se acepta si apunta a una sola prenda; lo ambiguo se muestra en
la pantalla de revisión para que lo confirme la persona; las cantidades se suman; los alias se
comparan por segmento de línea; y los nombres con guion se conservan. Cinco tests nuevos.

> **Propuesta pendiente:** el emparejamiento sigue siendo por texto. Si el OCR va a sostener el
> ingreso de datos, conviene un umbral de confianza explícito (distancia de edición) y guardar el
> texto crudo junto al lote para poder auditar una lectura dudosa después.

### 5.7 Las reglas de negocio viven en cadenas de texto
`'Quirófano'`, `'Super Admin'`, `'Personal manual'`, `'Ropera'` se comparan literalmente en el
backend, en el móvil y en el OCR. El horario de 06:30–16:30 está escrito en el código. La ventana de
corrección de una hora, también.

> **Propuesta:** mover el horario y la ventana a configuración, y las áreas/roles a identificadores
> estables con el nombre como etiqueta editable. Hoy, cambiar un nombre en la base de datos rompe los
> permisos en silencio.

### 5.8 El menú y los permisos de la API no coinciden
`role_home_screen.dart` define el menú por rol a mano. Hay desajustes:

- El **Encargado de Ropería y Lavandería** puede registrar lotes, avanzar etapas y entregar limpio
  según la API, pero su menú no ofrece "Registro manual".
- El **Super Admin** puede consultar y resolver alertas y corregir lotes, pero no tiene esas entradas.
- `'Lista del día'`, `'Seguimiento de lotes'` y `'Ver última lista'` son **tres nombres para la misma
  pantalla** (`HistoryScreen`).
- `PATCH /lotes/{lote}` (corregir un lote, con su lógica de ventana de una hora) **no es accesible
  desde ninguna pantalla**: funcionalidad implementada y probada en el backend, inalcanzable en la app.

> **Propuesta:** derivar el menú de una única tabla de capacidades por rol, compartida con la
> definición de rutas, y añadir la pantalla de corrección de lotes que falta.

### 5.9 El historial solo mostraba 20 lotes — RESUELTO
`HistoryScreen` leía únicamente la primera página y no ofrecía filtros, aunque el backend los
soportaba. Pasado un mes de uso, un lote antiguo sin cerrar quedaba fuera de la lista y su stock
inmovilizado sin forma de recuperarlo. Añadidos paginación ("cargar lotes anteriores") y filtro por
etapa.

### 5.10 Los reportes cargan todo en memoria
`ReporteController::movimientosLavado()` hace `->get()` de todos los movimientos del período y luego
agrupa y suma en PHP. Con unos años de datos esto se vuelve insostenible; el dashboard además no tiene
caché y recalcula los siete indicadores en cada petición.

> **Propuesta:** agregación en SQL (`selectRaw` con `SUM`/`GROUP BY`) y caché corta en el dashboard.
> Los índices del punto 3.6 ya están puestos para ello.

### 5.11 La contraseña inicial es el carnet de identidad
`UsuarioController::store` y `resetearPassword` usan el carnet como contraseña temporal. Es un dato
semipúblico dentro del hospital y es el mismo valor tras cada restablecimiento. El cambio obligatorio
en el primer ingreso lo mitiga, pero la ventana existe y es predecible.

> **Propuesta:** contraseña temporal aleatoria de un solo uso, entregada por el canal que
> corresponda, con caducidad.

### 5.12 Detalles menores pendientes
- `Usuario` no sobreescribe `getAuthPassword()`, que devuelve `$this->password` (la columna es
  `password_hash`). Sanctum no lo usa, pero cualquier uso futuro de `Auth::attempt` fallaría.
- `StockPilotoSeeder` carga 21 registros de stock piloto; conviene comprobar que no llegue a producción.
- `backend/.env` tiene `APP_DEBUG=true` y `APP_ENV=local`: correcto en desarrollo, bloqueante para
  el despliegue.
- Los tests corren en SQLite en memoria y producción es MySQL. Las diferencias de tipos y de
  `CHECK` entre ambos motores pueden ocultar fallos (el de 3.4 era uno de ellos).
- `CreateSuperAdminCommand` se niega a crear una segunda cuenta de administración incluso si la única
  existente está desactivada o bloqueada.

---

## 6. Cambios aplicados

33 archivos, +1801 / −342 líneas.

**Archivos nuevos**
- `backend/database/migrations/2026_10_06_120000_add_integrity_constraints_and_indexes.php`
- `backend/lang/es/validation.php`, `backend/lang/es/auth.php`

**Tests añadidos (14 nuevos en backend, 5 en móvil)**

Backend: `test_password_change_requires_the_current_password`,
`test_password_change_closes_the_sessions_opened_on_other_devices`,
`test_failed_attempts_reset_once_the_lock_expires`,
`test_a_record_the_role_cannot_sync_is_rejected_without_losing_the_rest`,
`test_keeping_the_server_version_stops_the_conflict_from_coming_back`,
`test_reordering_the_details_is_not_treated_as_a_change`,
`test_a_user_only_sees_the_conflicts_of_their_own_records`,
`test_a_lote_can_be_closed_even_if_its_clothes_were_written_off`,
`test_the_stage_cannot_be_advanced_twice_for_the_same_lote`,
`test_an_unknown_item_number_explains_itself_instead_of_returning_a_404`,
`test_personal_manual_only_sees_the_history_of_its_own_area`,
`test_renaming_a_clothing_type_keeps_it_in_the_area_template`,
`test_an_alias_cannot_be_shared_by_two_areas`,
`test_quirofano_cannot_be_renamed_because_its_rules_depend_on_the_name`.

Móvil: ambigüedad del OCR, suma de líneas repetidas, nombres con guion, desempate de áreas.

**Dos tests existentes modificados** (cambio de contrato intencional)
- `test_authenticated_user_can_change_initial_password_when_it_meets_policy`: ahora envía
  `password_actual`.
- `test_super_admin_can_manage_catalog_and_update_a_template`: usaba `estructura_campos.campos`, una
  forma que ningún código del sistema lee; se alineó con `tipos_prenda`.

---

## 7. Antes de desplegar

La migración `2026_10_06_120000` **añade claves únicas sobre datos existentes**. Si la base de
producción ya tiene duplicados (dos usuarios con el mismo N° de ítem, dos filas de `stock_area` para
el mismo par área/prenda, alias repetidos), la migración fallará. Hay que revisarlo antes:

```sql
SELECT numero_item, COUNT(*) FROM usuario GROUP BY numero_item HAVING COUNT(*) > 1;
SELECT area_id, tipo_prenda_id, COUNT(*) FROM stock_area GROUP BY area_id, tipo_prenda_id HAVING COUNT(*) > 1;
SELECT alias_normalizado, COUNT(*) FROM alias_area GROUP BY alias_normalizado HAVING COUNT(*) > 1;
SELECT nombre, COUNT(*) FROM rol GROUP BY nombre HAVING COUNT(*) > 1;
SELECT nombre, COUNT(*) FROM area GROUP BY nombre HAVING COUNT(*) > 1;
SELECT nombre, COUNT(*) FROM tipo_prenda GROUP BY nombre HAVING COUNT(*) > 1;
```

El cambio de zona horaria **no convierte los datos ya guardados**. Las filas escritas antes con
`now('America/La_Paz')` ya están en hora local y quedan correctas; las de `verificacion_stock`
(escritas en UTC) están 4 h adelantadas y necesitan un `UPDATE` de corrección si ese histórico importa.
