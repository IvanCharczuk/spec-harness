---
description: Corre scripts/rmaestro de forma interactiva, pidiéndote confirmación real en cada paso (nunca la asume por vos) — incluye new, editando el contenido real con vos por chat.
argument-hint: <id|ruta> | new "<título>" [--force A|B --reason "<texto>"] [--context-dir <path>] [-- <args>]
---

Vas a ejecutar `scripts/rmaestro $ARGUMENTS` (ver `spec 0012 (not in this snapshot)`)
como intermediario entre el proceso real y el operador. Reglas duras, sin
excepción:

- Nunca respondas un prompt `[s/N]` de `rmaestro` por tu cuenta. Cada
  confirmación la contesta el operador en el chat, no vos.
- `scripts/rmaestro` necesita una terminal real (tty) para abrir un editor de
  verdad (`$EDITOR`/`vi`, RF-02) — eso no existe en esta sesión de
  herramientas, y sigue sin existir. Lo que sí podés hacer, sin mentir sobre
  esa limitación: reemplazar el paso de edición por vos mismo, escribiendo
  el contenido real con tu herramienta de edición de archivos, sincronizado
  con `rmaestro` por un marker real (nunca un timing supuesto) — procedimiento
  completo abajo. Nunca dejes pasar el paso de edición en silencio ni
  apruebes una spec con contenido de template sin editar.
- Nunca agregues `--force`/`--reason`/`--context-dir` u otra flag que el
  operador no haya pedido explícitamente en `$ARGUMENTS` o en el chat.

## Preparación (siempre, sea `new` o resumir un id/ruta existente)

```bash
FIFO=$(mktemp -u); mkfifo "$FIFO"
LOG=$(mktemp)
DONE_MARKER=$(mktemp -u)
BRIDGE=$(mktemp)
cat > "$BRIDGE" <<'EOF'
#!/usr/bin/env bash
# Puente entre --editor de scripts/rmaestro y una edición real hecha acá,
# por chat. No es un editor de terminal: reemplaza esa edición, sincronizado
# por la existencia de $RMAESTRO_CHAT_DONE — nunca por un sleep a ciegas.
# El chequeo "[ ! -f ... ]" es idempotente a la creación temprana del
# marker: si ya existe cuando este script arranca, sale de inmediato.
while [ ! -f "$RMAESTRO_CHAT_DONE" ]; do
  sleep 0.2
done
EOF
chmod +x "$BRIDGE"
exec 3<>"$FIFO"
RMAESTRO_CHAT_DONE="$DONE_MARKER" scripts/rmaestro $ARGUMENTS --editor "$BRIDGE" <&3 >"$LOG" 2>&1 &
RPID=$!
SHOWN=0
```

`--editor "$BRIDGE"` se agrega siempre, al final — si el operador puso su
propio `--editor` en `$ARGUMENTS`, el tuyo gana (última flag repetida gana en
`scripts/rmaestro`), que es lo que corresponde: sin esto, cualquier editor
real fallaría por falta de tty.

## Loop principal

1. Poll corto (no un `sleep` largo) hasta que `$LOG` crezca o el proceso
   termine:
   ```bash
   while kill -0 "$RPID" 2>/dev/null; do
     size=$(wc -c < "$LOG")
     [ "$size" -gt "$SHOWN" ] && break
     sleep 0.2
   done
   ```
   (la necesidad de editar no la señaliza ningún archivo — la señaliza el
   propio contenido de `$LOG`, ver paso 3)
2. Si el proceso ya terminó (`kill -0 "$RPID"` falla) sin que `$LOG` haya
   crecido más: andá directo al cierre.
3. Mostrale al operador, tal cual, sólo lo nuevo desde la última vez
   (`tail -c +$((SHOWN+1)) "$LOG"`), y actualizá `SHOWN` al tamaño actual. No
   resumas ni reformules la salida de `rmaestro`. Después, revisá qué
   apareció:
   - **Termina en `Spec creada: <ruta>`** (sólo pasa una vez, con `new`): la
     spec recién creada tiene contenido de template — vas a entrar al paso
     de edición ni bien `rmaestro` llegue a abrirlo (siempre, sin excepción,
     para `new`). Guardá `<ruta>` y andá al "Procedimiento de edición" ahora
     mismo, sin esperar ninguna otra señal — es el único paso que sigue.
   - **Termina en el prompt "¿Reabrir el editor para corregir? [s/N]"**: el
     `lint` sobre el contenido actual falló (el detalle ya se mostró arriba
     en el mismo bloque de salida). Preguntale al operador si quiere que lo
     corrijas vos (sugerido) o prefiere cancelar. Si corrige: escribí `s` al
     FIFO (`printf 's\n' >&3`) y andá al "Procedimiento de edición" apenas
     confirmes eso (`rmaestro` va a abrir el editor de nuevo de inmediato).
     Si cancela: escribí `n` al FIFO, seguí el loop normal (va a terminar en
     130).
   - **Termina en el prompt de aprobar `[s/N]`** (el único otro prompt):
     antes de pedirle la respuesta al operador, corré
     `scripts/rutas perfiles --spec <ruta de la spec>` (RF-07 de
     `spec 0023 (not in this snapshot)`)
     y mostrale banda, score, panel y `estimado` (agentes y tokens, o el
     texto "sin corridas base" cuando `estimado.tokens` sea `null`) — así
     aprueba sabiendo qué va a costar y puede achicar la spec antes en vez de
     después. Si la spec tiene `### 5.3 Secuencia`, recordale junto con el
     costo que el diagrama de §5.3 ya se lo mostraste (la ruta del `HTML=`
     del paso 4 del "Procedimiento de edición") — no hace falta repetirlo.
     **Excepción acotada (RF-08 de
     `spec 0039 (not in this snapshot)`, CA-11):** si en el
     paso 3 del "Procedimiento de edición" el operador ya avaló este mismo
     contenido con la palabra `apruebo` — habiendo visto ahí ese mismo costo
     de `scripts/rutas perfiles` junto con el resumen del borrador — y no
     volviste a pasar por ese paso 3 desde entonces (es decir, no hubo una
     corrección por lint en el medio que te haya mandado de nuevo al
     editor), no se lo vuelvas a preguntar acá: escribí `s` directo al FIFO
     (`printf 's\n' >&3`) y volvé al paso 1. Esta excepción es sólo para
     este prompt puntual — nunca para "¿Reabrir el editor para corregir?"
     ni para ninguna otra confirmación. Si no se cumplen esas condiciones,
     seguí como siempre: recién ahí esperá la respuesta real del operador en
     el chat, traducila a `s` o a cualquier otra cosa según lo que haya
     dicho, escribila al FIFO (`printf '%s\n' "<respuesta>" >&3`) y volvé al
     paso 1.
   - **No termina en ningún prompt reconocible**: volvé al paso 1 (puede ser
     salida intermedia, p. ej. la de `scripts/route`).
4. Repetí 1-3 hasta que el proceso termine — ahí andá al cierre.

## Procedimiento de edición (reemplaza al editor real)

Se activa cada vez que el loop principal detecta que hay que editar (arriba).
`rmaestro` está bloqueado de verdad en `run_editor` en este momento — no hay
apuro por el lado del proceso, el apuro es no dejar al operador esperando.

1. Leé el archivo de la spec (la ruta que ya tenés de `Spec creada: ...`, o
   la que resolviste vos si veniás de un `id|ruta` existente) con tu
   herramienta de lectura.
2. Si es contenido de template sin tocar (primera vez, camino `new`):
   antes de redactar, hacé un brainstorm de alternativas (RF-01..03 de
   `specs/0055-todo-worktree-nuevo-arranca-con-un-brainstorm-de-alternativas.md`),
   para no construir primero sobre la primera idea y girar el rumbo después.
   Mostrale al operador el problema tal como lo entendiste (una o dos líneas),
   al menos tres enfoques distintos (tres enfoques: uno es lo nativo de donde
   ya viven los datos o la herramienta que ya existe, otro el mínimo que
   resuelve el pedido) y, de cada uno, qué es, a favor, en contra y costo o
   riesgo; cerrá con tu recomendación y el porqué. Podés leer el repo y la
   carpeta de contexto para armarlo, pero no escribas archivos ni código hasta
   que el operador elija, combine o descarte enfoques; esperá su respuesta.
   Si el operador pide saltear el brainstorm, se saltea; vos no lo salteás
   por tu cuenta. Con lo elegido, la spec anota en §7 un
   `D-n — Alternativas consideradas` con los enfoques descartados y por qué,
   una línea cada uno.
   Recién ahí conversá con el operador — Objetivo, Alcance (IN/OUT), Requerimientos
   funcionales/no funcionales numerados, Criterios de aceptación (cada uno
   con `check:`/`expect_exit` o `manual: true`) — con la misma seriedad que
   si estuvieras redactando cualquier spec hija de este repo (mismo formato
   que las specs existentes en `specs/`, front-matter y las 8 secciones de
   `templates/spec.md`). No rellenes con placeholders para que pase `lint`
   de pura casualidad estructural — el contenido tiene que ser real.
   Si veniás de un `lint` en rojo sobre una spec ya con contenido real:
   mostrale al operador el detalle exacto que falló (ya lo tenés del `$LOG`)
   y corregí eso puntualmente, no reescribas todo de nuevo.
3. Escribí el contenido acordado en el archivo con tu herramienta de
   edición — nunca lo hagas sin que el operador haya visto y avalado el
   contenido final, aunque lo hayas redactado vos. Al pedirle ese aval,
   mostrale también el costo de `scripts/rutas perfiles --spec <ruta de la
   spec>` junto con el resumen del borrador (RF-08 de
   `spec 0039 (not in this snapshot)`): si responde con la
   palabra `apruebo`, ese aval ya cubre por adelantado el prompt de
   aprobación `[s/N]` que `rmaestro` va a mostrar más adelante en el "Loop
   principal" (ver la excepción ahí) — vale mientras no vuelvas a pasar por
   este paso 3 con el mismo contenido antes de llegar a ese prompt; si hay
   una corrección por lint en el medio (paso "¿Reabrir el editor para
   corregir?"), ese aval queda viejo y hay que volver a pedirlo. Si estás
   redactando una spec nueva (camino `new`, contenido de template sin tocar
   todavía), incluí también en el borrador la subsección `### 5.3 Secuencia`
   con un fence ```` ```archify ```` que lleve la JSON IR `sequence` de
   archify del flujo que esa spec va a implementar (RF-08 de
   `spec 0051 (not in this snapshot)`):
   - `participants` con `id`/`type`/`label`/`sublabel`; el `sublabel` dice
     qué hace y dónde vive (los archivos que ya acordaste en §5.1).
   - `messages` con `id`/`from`/`to`/`label`/`variant`, según la tabla de
     convenciones de la plantilla.
   - `alt`/`else`/`loop` como `segments` anclados con `from_msg`/`to_msg`.
   - Sin `y` ni `meta.output`: los completa `scripts/diagrama`.

   Las specs existentes con el ```` ```diagrama ```` YAML de 0025 no se
   migran. Para specs existentes sin §5.3 (edición sobre un `id|ruta` que
   ya tenía contenido real antes de este procedimiento), no se exige nada.
4. Si acabás de escribir `### 5.3 Secuencia` (paso anterior): corré
   `scripts/diagrama <ruta>` sobre el archivo recién escrito. Si da exit 2,
   corregí la IR según los diagnósticos y volvé a correrlo. Cuando dé exit
   0, pasale al operador la ruta del `HTML=` que imprimió (en
   `.state/diagramas/`, fuera de git) como link clickeable junto con el
   resumen del borrador, **antes** de escribir la spec definitiva y liberar
   a `rmaestro`. No se publica Artifact. Si el operador corrige el flujo,
   corregí la IR de §5.3 y volvé a correr `scripts/diagrama <ruta>`.
5. Recién ahí, señalizá que terminaste:
   ```bash
   rm -f "$DONE_MARKER"
   : > "$DONE_MARKER"
   ```
6. Esperá evidencia real (no timing supuesto) de que `rmaestro` salió del
   editor y siguió — pollear `$LOG` hasta que crezca:
   ```bash
   i=0
   while [ "$(wc -c < "$LOG")" -eq "$SHOWN" ] && [ "$i" -lt 50 ]; do
     sleep 0.2; i=$((i+1))
   done
   ```
7. Limpiá el marker para dejarlo listo por si hay una vuelta más del bucle
   de lint (RF-03 de 0012 no tiene límite de reintentos):
   ```bash
   rm -f "$DONE_MARKER"
   ```
8. Volvé al paso 3 del loop principal con el `$LOG` ya crecido — mostrale al
   operador lo nuevo (va a ser el resultado de `lint`) y seguí desde ahí.

## Cierre

Cuando el proceso terminó (loop principal, paso 2, o al final natural del
loop): `wait "$RPID"` para el exit code real, mostrale al operador el resto
de `$LOG` que no le hayas mostrado todavía, decile el exit code y qué
significa (130 = cancelación, propia o del operador; el resto según §RF-11
de 0012), y limpiá todo:
```bash
exec 3>&- 2>/dev/null || true
rm -f "$FIFO" "$LOG" "$DONE_MARKER" "$BRIDGE"
```

## Adoptar el modo (RF-07 de `spec 0014 (not in this snapshot)`)

Si el exit fue 0 y la última línea de `$LOG` es
`MODO=<directo|exhaustivo> CONTRATO=<ruta> SPEC=<id>`: esto es el "rutear
cómo actuar" — `rmaestro` no abre ninguna sesión; el agente sos vos, en esta
misma conversación.

1. Leé el archivo de `CONTRATO=` completo (`templates/MODE.md.directo` o
   `.exhaustivo`) y `AGENTS.md`.
2. Decile al operador, en una línea, qué modo quedó y por qué — usá el
   `SCORE=`/`RULE=` de la línea de `route` que ya mostraste (o
   `manual-override` si vino forzado).
3. **Adoptá ese contrato para el resto de la conversación**, empezando por su
   sección "Primera acción" (leer la spec entera; `scripts/spec start <id>`
   si está `approved`; leer la carpeta de contexto si `rmaestro` imprimió
   una). Si el modo es `exhaustivo`, lo primero que producís después es el
   plan explícito que el contrato exige y su aprobación — no código.
4. Sus secciones "Verificaciones" y "Si aparece un disparador" rigen todo lo
   que sigue, aunque la conversación se alargue.
5. **Ruta agéntica** (RF-06 de `specs/0021-rutas-agenticas-route-elige-un-workflow-de-subagentes-por-modo.md`):
   antes de lanzar, `PERFILES=$(scripts/rutas perfiles --spec <id>)` (RF-07
   de `spec 0023 (not in this snapshot)`)
   y corré `scripts/rutas <modo>` para saber qué workflows imprime, en ese
   orden. Lanzalos con la herramienta `Workflow` (este paso es el opt-in
   explícito del operador para usarla), pasando `$PERFILES` como
   `args.perfiles` a cada uno. Para `exhaustivo`, entre el primero (plan) y
   el segundo (impl) va la aprobación del plan por el operador, como dice
   la sección "Ruta agéntica" del contrato. Al recibir el plan del primer
   workflow: guardá `plan.diagrama` (JSON IR de archify) en un archivo
   temporal y corré `scripts/diagrama --json <tmp>`. Mostrale el plan
   (grupos, supuestos) junto con la ruta del `HTML=` como link clickeable,
   sin Artifact, antes de pedirle la aprobación. Si `plan.diagrama` no
   valida, mostrale el plan igual, con el error que devolvió
   `scripts/diagrama --json`, sin frenar el flujo. Si el
   operador prefiere que implementes vos sin la ruta, lo dice él; no lo
   asumas. Al terminar cada
   workflow, correr `scripts/rutas log` con los números del bloque de uso
   (agentes, errores, tokens, duración, herramientas), los campos del
   objeto devuelto (`pasa`, `ca_total`, `ca_pass`, `segunda_vuelta`) y
   `--perfiles "$PERFILES"`; mostrarle al operador la línea escrita.

No inventes ningún paso fuera de este procedimiento ni de lo que
`scripts/rmaestro` ya hace — sos un intermediario del proceso real (y, en el
paso de edición, un reemplazo declarado y visible del editor, nunca uno
disimulado), no un reemplazo de sus confirmaciones.
