# Manual de Usuario y Plan de Capacitación — SICOTRAZ

**[BORRADOR]** Este manual está basado en los wireframes en texto del documento maestro (sección 11.1), ya que todavía no existe la interfaz real construida. Cuando cada sprint entregue sus pantallas, las imágenes de este manual se reemplazan por capturas de pantalla reales — el contenido (pasos, reglas) ya no debería cambiar, salvo que también cambie en el documento maestro.

Este archivo es para el **personal del hospital** que usará la app — lenguaje simple, sin términos técnicos. Es un documento distinto del maestro (`Documento_Maestro_Requerimientos_Backlog.md`), que es para desarrollo.

---

## Plan de capacitación

- **Cuándo:** al cierre del Sprint 5, con el sistema ya funcionando completo (según Definition of Done, sección 9 del documento maestro).
- **Formato sugerido:** una sesión corta por rol (30–45 min), práctica y en el propio celular que van a usar — no una charla teórica larga.
- **Material de apoyo:** este manual, impreso o enviado por WhatsApp/PDF a cada trabajador.
- **[PROPUESTA — REQUIERE APROBACIÓN]** Sugerencia: grabar cada sesión con el celular como respaldo, por si algún trabajador falta ese día.
- **Orden sugerido de capacitación:** primero Ropera y Personal Manual (son quienes más usan la app día a día), luego Costura, y al final Encargado y Super Admin (roles administrativos, con menos urgencia de manejo diario).

---

## Antes de empezar (todos los roles)

### ¿Qué es SICOTRAZ?

Es la app donde vas a registrar la ropa que entra y sale de tu área, en vez de anotarlo solo en papel. El papel se sigue usando (lo lees con la cámara del celular), pero ahora queda guardado en el sistema.

### Cómo iniciar sesión

1. Abre la app.
2. Ingresa tu **número de ítem o contrato** (el mismo que usas en el hospital).
3. La primera vez, tu contraseña es tu **número de carnet de identidad**.
4. El sistema te va a pedir que **cambies esa contraseña** antes de dejarte entrar. La nueva contraseña debe tener:
   - Entre 8 y 30 caracteres.
   - Al menos una mayúscula, una minúscula, un número y un símbolo.
   - Ejemplo: `Pedro@1234`
   - La escribes 2 veces, para confirmar que no te equivocaste.

**Si te equivocas 5 veces seguidas, la cuenta se bloquea.** Avisa al Super Admin para que la desbloquee.

**Si olvidas tu contraseña:** pide al Super Admin que te la resetee — vuelve a ser tu número de carnet, y te pedirá crear una nueva otra vez.

### El ícono de arriba de la pantalla

Vas a ver un pequeño ícono en la parte de arriba, en todas las pantallas:
- **Normal / verde:** todo está sincronizado.
- **Rojo, "Sin conexión — X pendientes":** no tienes internet en este momento, pero **puedes seguir trabajando normal**. Todo se guarda en tu celular y se sube solo apenas vuelva la conexión — no tienes que hacer nada especial.

---

## Manual para: Ropera

Tu pantalla principal tiene 3 botones:

1. **Registrar Quirófano** — acceso directo, porque Quirófano trae ropa varias veces al día.
2. **Capturar formulario** — para las listas de Salas.
3. **Registro manual** — para cuando la hoja está dañada, ilegible, o no es el formato de siempre.

### Cómo registrar una lista con foto (Salas o Quirófano)

1. Presiona "Capturar formulario" (o "Registrar Quirófano" si corresponde).
2. Toma la foto de la hoja, o elige una que ya tengas en tu galería.
3. Espera un momento — el sistema va a leer la hoja solo y llenar el formulario digital por ti.
4. **Revisa los datos.** Si algo está mal (por ejemplo, el sistema leyó "3" pero en el papel dice "8"), corrígelo directamente con los botones `−` y `+`, o escribiendo el número correcto.
5. Si el número de ítem o el nombre del área no se leyeron bien, corrígelos ahí mismo.
6. Presiona "Guardar lote".

**Si la foto sale borrosa** y el sistema no puede leerla, te va a avisar para que la tomes de nuevo.

### Cómo hacer un registro manual

Úsalo si la hoja está rota, muy sucia para leerse, o no es el formato de siempre.

1. Presiona "Registro manual".
2. Elige el área.
3. Vas a ver la lista de prendas típicas de esa área, ya con los nombres puestos — solo escribe la cantidad al lado de cada una.
4. Presiona "Guardar lote".

**Importante:** puedes seguir corrigiendo tus listas hasta las **9:00 am**. Después de esa hora, ya no puedes editarlas (solo verlas) — si necesitas un cambio después de esa hora, pide ayuda al Encargado.

---

## Manual para: Personal Manual

Tu pantalla principal tiene 2 botones:

1. **Ver última lista** — para revisar el último registro.
2. **Reportar** — para avisar si algo no cuadra.

### Cómo hacer la verificación de turno

Esto lo haces **al entrar** a tu turno (no al salir):

- **Turno de mañana:** revisa cuánta ropa hay en tu área (salas) y cuánta hay en lavandería. Más tarde, revisa que la ropa que se llevó en la mañana regrese exactamente igual a como la entregaste.
- **Turno de noche:** recuerda que Lavandería no trabaja de noche, así que esta verificación aplica principalmente al turno de día.

Para cada prenda, el sistema te muestra cuánto se espera y tú ingresas cuánto contaste realmente.

**Si algo no coincide:**
1. Primero, intenta resolverlo tú mismo: busca en otras áreas cercanas, revisa si no se fue a Costura por error.
2. Si no lo encuentras, anota en observaciones qué pasó (por ejemplo, "se recibieron 50 prendas pero 1 era de otra sala").
3. Guarda el registro — **siempre se guarda**, haya o no problema.

### Cómo reportar una alerta

1. Presiona "Reportar".
2. Escribe qué pasó (obligatorio — no basta con decir "falta una sábana", explica qué intentaste antes de reportar).
3. Si quieres, adjunta o toma una foto (opcional).
4. Presiona "Registrar".

---

## Manual para: Costura

Tu pantalla principal tiene 2 botones:

1. **Dar de baja prenda** — tu función principal.
2. **Mis bajas recientes** — para revisar lo que registraste antes.

### Cómo dar de baja una prenda

1. Presiona "Dar de baja prenda".
2. Elige qué prenda es.
3. Elige el motivo de una lista:
   - Rota / rasgada
   - Manchada sin arreglo
   - Desgastada por uso
   - Costura descosida sin reparación
   - Perdida
   - Quemada
   - Otro (si eliges esta, tienes que escribir qué pasó)
4. Toma una foto o adjunta una como evidencia.
5. Presiona "Confirmar baja".

El sistema descuenta esa prenda del stock automáticamente — no tienes que avisarle a nadie más.

---

## Manual para: Encargado de Ropería y Lavandería

Tu pantalla principal tiene 5 accesos:

1. **Lista del día** — todo lo que registró la Ropera hoy. A diferencia de la Ropera, **tú puedes editar estas listas en cualquier momento**, sin límite de horario.
2. **Alertas pendientes** — para resolver los problemas reportados.
3. **Seguimiento de lotes** — para ver en qué etapa está cada lote (sucio recibido → en lavado → limpio entregado).
4. **Dashboard** — vista general con números del servicio.
5. **Historial** — para buscar movimientos pasados por trabajador o por área.

### Cómo resolver una alerta

1. Entra a "Alertas pendientes" y elige una.
2. Si encontraste la causa, puedes escribirla (opcional).
3. Presiona "Marcar resuelto" — puedes hacerlo con o sin explicación.

### Cómo leer el Dashboard

- **Alertas pendientes hoy:** cuántos problemas siguen sin resolver.
- **Lavado esta semana / este mes:** cuánta ropa se procesó.
- **Total de ropa circulando:** cuánta ropa está en proceso de lavado en este momento, sumando todas las áreas (este dato no lo ve la Ropera, solo tú y el Super Admin).
- **Área con más alertas del mes / prenda con más bajas del mes:** para saber dónde investigar primero.

---

## Manual para: Super Admin

Tu pantalla principal tiene 3 accesos directos (y otros secundarios, un nivel más adentro):

1. **Dashboard**
2. **Gestión de usuarios**
3. **Gestión de catálogo**
4. *(Secundarios)*: Carga de stock inicial, Reportes, Impresión de plantilla en blanco.

### Cómo crear o desactivar un usuario

1. Entra a "Gestión de usuarios" → "Nuevo usuario".
2. Completa los datos. La contraseña inicial siempre es el número de carnet del trabajador.
3. Para dar de baja a alguien, **nunca se borra la cuenta** — se desactiva. Así se conserva su historial por si hace falta revisarlo después.

### Cómo resetear una contraseña

Entra a la cuenta del usuario → "Resetear contraseña". Vuelve a ser su número de carnet, y se le pedirá crear una nueva la próxima vez que entre.

### Cómo agregar un tipo de prenda o área nueva

Entra a "Gestión de catálogo" → elige la pestaña (Tipos de prenda o Áreas) → "Nuevo". Si desactivas algo que ya tiene historial, ese historial se sigue viendo igual — solo que ya no se puede usar para registros nuevos.

### Cómo cargar stock

Entra a "Carga de stock inicial", elige área y prenda, e ingresa la cantidad a **agregar**. **Recuerda: se suma al stock actual, no lo reemplaza.**

### Cómo imprimir la plantilla en blanco

Entra a esa opción, elige si es plantilla de Salas o de Quirófano, y genera el PDF para imprimir y plastificar.

---

## Preguntas frecuentes

**No tengo internet, ¿puedo seguir trabajando?**
Sí. Todo se guarda en tu celular y se sube solo cuando vuelva la conexión.

**El sistema leyó mal un dato de la hoja de papel.**
Corrígelo directamente en el campo, con los botones `−`/`+` o escribiendo encima.

**Olvidé mi contraseña.**
Pide al Super Admin que te la resetee — vuelve a ser tu número de carnet.

**Veo un aviso de "conflicto de sincronización".**
Significa que 2 personas registraron algo distinto para lo mismo, al mismo tiempo, sin internet. No se pierde ninguno de los dos registros — un Encargado o Super Admin lo va a revisar y decidir cuál es el correcto.

**Ya pasaron las 9:00 am y necesito corregir algo que registré mal.**
Pide ayuda al Encargado o al Super Admin — ellos sí pueden editar en cualquier momento.
