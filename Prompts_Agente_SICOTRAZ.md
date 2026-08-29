# Prompts para trabajar con un agente de IA — SICOTRAZ

Cómo usar este archivo: envía el **Prompt 0 una sola vez**, al principio. Después, para cada sprint, usa el **Prompt 1**, rellenando los `[PEGAR AQUÍ...]` con las partes correspondientes de `Documento_Maestro_Requerimientos_Backlog.md` (v1.1). Al cerrar cada sprint, usa el **Prompt 2**. Si en cualquier momento sospechas que el agente inventó algo, usa el **Prompt 3**.

---

## Prompt 0 — Reglas base (enviar UNA SOLA VEZ, antes de pedir cualquier código)

```
Vas a actuar como desarrollador del sistema SICOTRAZ, siguiendo EXCLUSIVAMENTE las
especificaciones del documento que te voy a compartir por partes
(Documento_Maestro_Requerimientos_Backlog.md, versión 1.1).

Reglas que debes seguir sin excepción:

1. NO inventes campos, validaciones, pantallas, nombres de rutas, ni reglas de
   negocio que no estén explícitamente en lo que te comparto. Si crees que falta
   algo o que algo podría mejorarse, NO lo implementes — dímelo como sugerencia y
   espera mi aprobación antes de tocar código.

2. Si encuentras algo ambiguo, incompleto, o contradictorio, DETENTE y pregúntame.
   No asumas ni "rellenes el hueco" con tu propio criterio. Marca tu pregunta como
   [POR CONFIRMAR] o [CONTRADICCIÓN], igual que en el documento.

3. Antes de escribir cualquier código, muéstrame tu plan: qué archivos vas a crear
   o modificar, y en qué parte exacta del documento (número de sección, código de
   RF o HU) te basas cada decisión. Espera mi confirmación antes de ejecutar.

4. Usa exactamente los nombres de rutas, campos y formatos de respuesta definidos
   en la sección 27 (Contrato de API). No cambies un nombre de endpoint aunque te
   parezca "más correcto" o "más estándar".

5. Respeta los límites exactos definidos (ej. máximo 999 en cantidades, máximo 8
   dígitos en número de ítem, etc.) e impleméntalos como validación real en el
   código, no solo como comentario.

6. Al terminar una Historia de Usuario (HU), no digas solo "listo": revisa uno por
   uno los "Criterios de aceptación" de esa HU (sección 8) y confírmame
   explícitamente cuál cumples y cómo.

7. Trabajaremos un sprint a la vez, en el orden de la sección 9. No adelantes
   trabajo de un sprint futuro aunque veas que "de una vez" podrías hacerlo.

Confírmame que aplicarás estas reglas antes de que te comparta el Sprint 0.
```

---

## Prompt 1 — Inicio de cada sprint (plantilla — usar una vez por sprint)

```
Vamos a trabajar el Sprint [N]: [nombre del sprint].

Te comparto las partes relevantes del documento maestro para este sprint:

[PEGAR AQUÍ: la fila de la sección 9 de este sprint — HU/RF exactos y
Definition of Done]

[PEGAR AQUÍ: las Historias de Usuario de la sección 8 correspondientes a este
sprint, con sus criterios de aceptación]

[PEGAR AQUÍ: las pantallas de wireframes de la sección 11.1 correspondientes]

[PEGAR AQUÍ: los endpoints de la sección 27 correspondientes]

[PEGAR AQUÍ: cualquier regla de negocio (sección 5) o entidad del modelo de
datos (sección 13) que aplique a este sprint]

Antes de programar, dime:
1. Tu plan de archivos a crear o modificar.
2. En qué parte del texto de arriba basas cada decisión.
3. Cualquier duda o ambigüedad que encuentres — no asumas nada.

Espero tu confirmación antes de que empieces a escribir código.
```

---

## Prompt 2 — Verificación de cierre de sprint (usar al terminar cada sprint)

```
Antes de dar este sprint por terminado, revisa uno por uno:

1. Cada punto del Definition of Done del Sprint [N] (te lo compartí al inicio) —
   indícame cuál cumples y cómo lo verificaste.
2. Cada Criterio de aceptación de las HU de este sprint — indícame, HU por HU,
   cuál cumples y cómo.
3. ¿Agregaste algo que no estaba explícitamente pedido? Si sí, dime qué y por
   qué, para que yo decida si se queda o se quita.

No des el sprint por completo hasta que yo confirme cada punto.
```

Cuando el agente confirme todo, marca el sprint como completo en `Seguimiento_Sprints_SICOTRAZ.md`.

---

## Prompt 3 — Auditoría (usar si sospechas que se inventó algo)

```
Quiero que audites lo que llevas programado del Sprint [N] contra el documento
maestro que te compartí. Dime específicamente:

- ¿Hay algo que programaste que NO está explícitamente en el documento?
- ¿Hay algo del documento para este sprint que no se implementó?

Sé honesto aunque implique admitir que agregaste algo por tu cuenta sin
avisarme.
```

---

## Notas de uso

- Si el agente responde con código antes de mostrarte el plan (Prompt 1, paso 1-3), detente y pídeselo explícitamente — no continúes revisando el código directamente.
- Si usas **Claude Code**, estas mismas reglas del Prompt 0 puedes ponerlas en un archivo `CLAUDE.md` en la raíz del proyecto, para no tener que reenviarlas cada sesión — pídemelo si quieres que te lo arme.
- Estos prompts asumen que tú copias y pegas las secciones relevantes a mano. Si en algún momento el agente puede leer el archivo `.md` completo directamente (por ejemplo, subiéndolo o dándole acceso al repositorio), puedes simplificar el Prompt 1 a: *"Lee Documento_Maestro_Requerimientos_Backlog.md completo, sección 9, y trabajemos el Sprint [N] tal como está ahí."*
