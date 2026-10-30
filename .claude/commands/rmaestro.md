---
description: Corre scripts/rmaestro de forma interactiva, pidiéndote confirmación real en cada paso (nunca la asume por vos) — incluye new, editando el contenido real con vos por chat.
argument-hint: <id|ruta> | new "<título>" [--force A|B --reason "<texto>"] [--context-dir <path>] [-- <args>]
---

Vas a ejecutar `scripts/rmaestro $ARGUMENTS` (ver `spec 0012 (not in this snapshot)`)
como intermediario entre el proceso real y el operador. Reglas duras:

- Nunca respondas un prompt `[s/N]` de `rmaestro` por tu cuenta: cada
  confirmación la contesta el operador en el chat (o sus palabras
  reenviadas por la orquestadora, regla I de `AGENTS.md`).
- `rmaestro` necesita una tty para abrir un editor real, y esta sesión no la
  tiene. El paso de edición lo reemplazás vos, escribiendo el contenido real
  con tu herramienta de edición, sincronizado por un marker real (nunca un
  timing supuesto). Nunca lo dejes pasar en silencio ni apruebes una spec con
  contenido de template.
- Nunca agregues `--force`/`--reason`/`--context-dir` u otra flag que el
  operador no haya pedido en `$ARGUMENTS` o en el chat.

## Preparación

```bash
FIFO=$(mktemp -u); mkfifo "$FIFO"
LOG=$(mktemp)
DONE_MARKER=$(mktemp -u)
BRIDGE=$(mktemp)
cat > "$BRIDGE" <<'EOF'
#!/usr/bin/env bash
# Puente entre --editor de scripts/rmaestro y la edición hecha por chat:
# espera a que exista $RMAESTRO_CHAT_DONE, nunca un sleep a ciegas.
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

`--editor "$BRIDGE"` va siempre al final: la última flag repetida gana, y sin
tty cualquier editor real fallaría. Si el shell no persiste entre llamadas,
guardá las rutas en archivos fijos y mantené el FIFO abierto con un proceso
que escriba en él (`sleep` largo); las respuestas van con
`printf 's\n' > "$FIFO"`.

## Loop principal

1. Poll corto hasta que `$LOG` crezca o el proceso termine:
   ```bash
   while kill -0 "$RPID" 2>/dev/null; do
     [ "$(wc -c < "$LOG")" -gt "$SHOWN" ] && break
     sleep 0.2
   done
   ```
2. Si el proceso terminó sin salida nueva, andá al cierre.
3. Mostrale al operador, tal cual, sólo lo nuevo
   (`tail -c +$((SHOWN+1)) "$LOG"`) y actualizá `SHOWN`. Según cómo termina:
   - **`Spec creada: <ruta>`** (sólo con `new`): guardá la ruta y andá al
     "Procedimiento de edición".
   - **"¿Reabrir el editor para corregir? [s/N]"**: el `lint` falló (el
     detalle ya se mostró). Preguntale si lo corregís vos (sugerido) o
     cancela. Si corregís: `s` al FIFO y al "Procedimiento de edición". Si
     cancela: `n` y seguí el loop (termina en 130).
   - **`APROBAR_DESDE_MAIN SPEC=<id> RUTA=<ruta> HASH=<hash>`** (sesión de
     spec, worktree vinculado; RF-03 de 0102, aprobar desde main):
     `rmaestro` no pregunta y deja la spec en `draft`. Mostrale la salida,
     avisá a la orquestadora de main con la ruta y el `HASH=` (main corre
     `scripts/spec approve <id> --por-main "<palabras textuales>"` en este
     worktree), no escribas nada al FIFO y andá al cierre (exit 0). Cuando
     main avise que aprobó, corré `scripts/rmaestro <id>` para adoptar el
     modo ("Adoptar el modo").
   - **El prompt de aprobar `[s/N]`** (sólo en el checkout principal): corré
     `scripts/rutas perfiles --spec <ruta>` (RF-07 de 0023) y mostrale
     banda, score, panel y `estimado` (agentes y tokens, o "sin corridas
     base" si `estimado.tokens` es `null`); si hay §5.3, recordale el `HTML=`
     que ya le pasaste. Si en el paso 3 de edición ya respondió con la
     palabra `apruebo` a este mismo contenido y costo, y no hubo una
     corrección por lint desde entonces, escribí `s` directo (RF-08 de
     `spec 0039 (not in this snapshot)`, CA-11); la
     excepción vale sólo para este prompt, en el checkout principal. Si no, esperá su respuesta,
     traducila a `s` o a otra cosa, escribila al FIFO y volvé al paso 1.
   - **Cualquier otra salida** (p. ej. la de `scripts/route`): paso 1.
4. Repetí hasta que el proceso termine.

## Procedimiento de edición (reemplaza al editor real)

`rmaestro` está bloqueado en `run_editor`: no hay apuro del proceso, sí de
no dejar esperando al operador.

1. Leé la spec.
2. Si es template sin tocar (camino `new`), primero el brainstorm (RF-01..03
   de `specs/0055-todo-worktree-nuevo-arranca-con-un-brainstorm-de-alternativas.md`):
   el problema en una o dos líneas, tres enfoques distintos (uno lo nativo
   de donde ya viven los datos, otro el mínimo que resuelve el pedido) con
   qué es, a favor, en contra y costo, y tu recomendación con el porqué. No
   escribas archivos hasta que el operador elija; si pide saltearlo, se
   saltea, pero no por tu cuenta. Lo elegido va en §7 como
   `D-n — Alternativas consideradas`, una línea por enfoque descartado.
   Después redactá con el operador Objetivo, Alcance, RF/RNF y CA reales
   (cada CA con `check:` o `manual: true`), con el formato de
   `templates/spec.md`: la forma la valida `scripts/spec lint`, no hace
   falta repetirla acá. Sin placeholders para pasar lint de casualidad.
   Si venís de un `lint` en rojo, mostrale qué falló y corregí sólo eso.
3. Escribí el contenido acordado en el archivo sólo después de que el
   operador vio y avaló el contenido final. Al pedir el aval, mostrale el
   costo de `scripts/rutas perfiles --spec <ruta>` junto con el resumen
   (eso habilita la excepción del prompt de aprobar). En una spec nueva,
   incluí `### 5.3 Secuencia` con un fence `archify` que lleve la JSON IR
   `sequence` del flujo que la spec implementa, como muestra
   `templates/spec.md` (RF-08 de 0051). Las specs con el fence `diagrama`
   de 0025 no se migran; las existentes sin §5.3 no lo necesitan.
4. Si escribiste §5.3: `scripts/diagrama <ruta>` hasta exit 0 (con exit 2,
   corregí la IR según los diagnósticos). Pasale la ruta del `HTML=` (en
   `.state/diagramas/`, fuera de git) como link clickeable antes de liberar
   a `rmaestro`. Sin Artifact. Si corrige el flujo, corregí la IR y volvé
   a correrlo.
5. Liberá a `rmaestro`:
   ```bash
   rm -f "$DONE_MARKER"; : > "$DONE_MARKER"
   ```
6. Esperá evidencia de que siguió (no timing supuesto):
   ```bash
   i=0
   while [ "$(wc -c < "$LOG")" -eq "$SHOWN" ] && [ "$i" -lt 50 ]; do
     sleep 0.2; i=$((i+1))
   done
   ```
7. `rm -f "$DONE_MARKER"`, por si hay otra vuelta de lint (RF-03 de 0012 no
   limita los reintentos).
8. Volvé al paso 3 del loop principal con lo nuevo del `$LOG`.

## Cierre

`wait "$RPID"` para el exit real; mostrale el resto del `$LOG` y el exit
(130 = cancelación; el resto según RF-11 de 0012). Limpieza:
```bash
exec 3>&- 2>/dev/null || true
rm -f "$FIFO" "$LOG" "$DONE_MARKER" "$BRIDGE"
```

## Adoptar el modo (RF-07 de `spec 0014 (not in this snapshot)`)

Si el exit fue 0 y la última línea es
`MODO=<directo|exhaustivo> CONTRATO=<ruta> SPEC=<id>`, el agente sos vos, en
esta conversación:

1. Leé `AGENTS.md`, `templates/MODE.md.comun` y el `CONTRATO=` completos.
2. Decile al operador en una línea qué modo quedó y por qué (`SCORE=`/`RULE=`
   de la línea de `route`, o `manual-override`).
3. Adoptá ese contrato para el resto de la conversación, desde su "Primera
   acción". En `exhaustivo`, lo primero es el plan y su aprobación, no
   código.
4. La ruta agéntica está en `MODE.md.comun`: `scripts/rutas <modo>`,
   perfiles, `Workflow` (este paso es el opt-in explícito del operador),
   `scripts/diagrama --json` sobre `plan.diagrama`, `scripts/rutas log`
   después de cada workflow, y `scripts/ruta <modo> <id> [--agent <agente>]`
   desde terminal.

No inventes pasos fuera de este procedimiento ni de lo que `scripts/rmaestro`
ya hace: sos un intermediario del proceso real y, en la edición, un
reemplazo declarado del editor, nunca uno disimulado.
