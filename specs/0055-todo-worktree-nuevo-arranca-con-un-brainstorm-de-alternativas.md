# SPEC — Todo worktree nuevo arranca con un brainstorm de alternativas

**Spec madre:** `specs/0001-repo-maestro.md`. Hija de 0012 (`/rmaestro`,
procedimiento de edición) y de 0039/0044 (`orca-spec new` y `tmux-spec new`
abren el worktree con `/rmaestro new`). Hoy, en el camino `new`, el agente
pasa directo a redactar Objetivo, Alcance, RF y CA sobre la primera idea.
Varias veces hubo que rehacer después: la 0020 quedó obsoleta frente al
canvas de Sheets, la 0024 y la 0049 se rehicieron y la 0048 se descartó. El
2026-10-07 el operador pidió que todo worktree nuevo arranque con un
brainstorm de alternativas, para no construir primero y girar el rumbo
después. Ante conflicto, gana la madre.

**Destinatario:** subagente implementador supervisado por la sesión
orquestadora, en el checkout principal.

**Idioma:** documentación y comentarios en español rioplatense;
identificadores, paths y claves de config en inglés.

---

```yaml
id: "0055"
title: "Todo worktree nuevo arranca con un brainstorm de alternativas"
version: 1
status: verified
created_at: 2026-10-07
updated_at: 2026-10-07
schema_change: false
arch_decision: false
target_branch: "spec/0055-brainstorm-inicial"
loc_estimate: 30
tier_locked: null
supersedes: null
```

---

## 1. Objetivo

Que toda spec nueva que se abra con `/rmaestro new` (y por lo tanto todo
worktree que abren `orca-spec new` y `tmux-spec new`) empiece con un
brainstorm de enfoques que elige el operador, antes de redactar una línea
de la spec.

---

## 2. Alcance

### 2.1 Dentro de alcance (IN)

- `.claude/commands/rmaestro.md`, "Procedimiento de edición", paso 2,
  camino `new`: un paso de brainstorm antes de redactar.
- `docs/orca.md`: una línea que diga que un worktree nuevo arranca con el
  brainstorm.

### 2.2 Fuera de alcance (OUT)

- `scripts/rmaestro`, `the worktree helper (not in this snapshot)`, `scripts/tmux-spec`: el prompt
  sigue siendo `/rmaestro new …`. El brainstorm vive en el comando, así lo
  heredan los dos caminos.
- Specs existentes (camino `<id>|ruta`) y correcciones por lint: no hay
  brainstorm.
- `templates/spec.md`: las alternativas se anotan en §7 como texto, sin
  sección nueva.

---

## 3. Requerimientos funcionales

**RF-01 — Brainstorm antes de redactar.** En el camino `new`, con contenido
de template sin tocar, lo primero que hace el agente, antes de proponer
Objetivo, Alcance, RF o CA, es mostrarle al operador:
- el problema tal como lo entendió, en una o dos líneas;
- al menos tres enfoques distintos. Uno tiene que ser lo nativo de donde ya
  viven los datos o la herramienta que ya existe, y otro el mínimo que
  resuelve el pedido;
- para cada uno: qué es, a favor, en contra, y costo o riesgo;
- su recomendación, con el porqué.

Puede leer el repo y la carpeta de contexto para armarlo. No escribe ningún
archivo ni código hasta que el operador elige.

**RF-02 — El operador elige.** El agente espera a que el operador elija,
combine o descarte enfoques, y recién ahí redacta la spec sobre lo elegido.
Si el operador pide saltear el brainstorm, se saltea; el agente no lo
saltea por su cuenta.

**RF-03 — Queda registrado.** La spec redactada anota en §7 un `D-n —
Alternativas consideradas` con los enfoques descartados y por qué, en una
línea cada uno.

---

## 4. Requerimientos no funcionales

**RNF-01 — Compatibilidad.** El resto de `rmaestro.md` no cambia. Los CA
que miran ese archivo siguen dando lo mismo: 0023 CA-08, 0039 CA-11 y los
de 0051. Comparar `scripts/verify` antes y después.

---

## 5. Estructura del entregable

### 5.1 Archivos nuevos o reemplazados

```
.claude/commands/rmaestro.md     # RF-01..03: paso de brainstorm en el camino new
docs/orca.md                     # una línea: el worktree nuevo arranca con brainstorm
```

### 5.3 Secuencia

```archify
{
  "diagram_type": "sequence",
  "meta": { "title": "Arranque de un worktree nuevo" },
  "participants": [
    { "id": "op", "type": "frontend", "label": "Operador", "sublabel": "pide la spec" },
    { "id": "ag", "type": "backend", "label": "Agente del worktree", "sublabel": "/rmaestro new" },
    { "id": "sp", "type": "backend", "label": "Spec", "sublabel": "specs/NNNN-*.md" }
  ],
  "messages": [
    { "id": "pide", "from": "op", "to": "ag", "label": "orca-spec new / tmux-spec new", "variant": "emphasis" },
    { "id": "brain", "from": "ag", "to": "op", "label": "problema + 3 enfoques + recomendación", "variant": "return" },
    { "id": "elige", "from": "op", "to": "ag", "label": "elige / combina / descarta", "variant": "emphasis" },
    { "id": "redacta", "from": "ag", "to": "sp", "label": "redacta sobre lo elegido; §7 D-n alternativas", "variant": "default" }
  ]
}
```

Renderizar con `scripts/diagrama <id>`: escribe `.state/diagramas/<id>.html`, fuera de git.

---

## 6. Criterios de aceptación

Binarios. La spec está cumplida si y sólo si los 4 pasan.

- **CA-01** — `rmaestro.md` tiene el paso de brainstorm con sus piezas:
  tres enfoques, lo nativo, el mínimo, la recomendación y la espera a que
  el operador elija.
  ```yaml
  check:
    cmd: |
      f=.claude/commands/rmaestro.md
      grep -qi 'brainstorm' "$f" && grep -qi 'tres enfoques' "$f" && grep -qi 'nativo' "$f" &&
      grep -qi 'mínimo' "$f" && grep -qi 'recomendación' "$f" && grep -q 'Alternativas consideradas' "$f"
    expect_exit: 0
  ```

- **CA-02** — El brainstorm va antes de redactar: en el archivo, la primera
  mención de "brainstorm" aparece antes de "Escribí el contenido acordado".
  ```yaml
  check:
    cmd: |
      f=.claude/commands/rmaestro.md
      b=$(grep -ni 'brainstorm' "$f" | head -1 | cut -d: -f1); e=$(grep -n 'Escribí el contenido acordado' "$f" | head -1 | cut -d: -f1)
      [ -n "$b" ] && [ -n "$e" ] && [ "$b" -lt "$e" ]
    expect_exit: 0
  ```

- **CA-03** — `docs/orca.md` lo menciona.
  ```yaml
  check:
    cmd: "grep -qi 'brainstorm' docs/orca.md"
    expect_exit: 0
  ```

- **CA-04** — Compatibilidad: 0039 CA-11 y 0023 CA-08 dan lo mismo que
  antes, y `spec lint 0055` y `doctor` en verde.
  ```yaml
  check:
    cmd: "scripts/verify 0039 --ca CA-11 >/dev/null && scripts/spec lint 0055 && scripts/doctor"
    expect_exit: 0
  ```

---

## 7. Dependencias y bloqueos

**D1 — Por qué en el comando y no en los scripts.** `orca-spec` y
`tmux-spec` ya abren con `/rmaestro new`; poner el paso ahí lo cubre todo
sin tocar dos scripts ni sus CA de `--dry-run`.

**D2 — Alternativas consideradas.** Un `templates/BRAINSTORM.md` aparte se
descartó porque suma un archivo que el agente tiene que acordarse de leer.
Un flag `--brainstorm` en `orca-spec` se descartó porque el operador quiere
el brainstorm siempre, no a pedido.

**D3 — 0023 CA-08** ya fallaba antes de esta spec (foto); se compara antes y
después, no se exige verde.

---

## 8. Datos e integridad

**8.1** Sólo texto de instrucciones; no toca scripts ni datos.

---

## §Historial

- 2026-10-27 — v1 — "foto pública: el historial interno no se publica" — operator

## §Traza

*(vacío — se completa con `scripts/spec trace <id>` una vez que exista)*
