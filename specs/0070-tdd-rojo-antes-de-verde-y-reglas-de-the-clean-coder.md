# SPEC — TDD rojo antes de verde y reglas de The Clean Coder

**Spec madre:** `specs/0001-repo-maestro.md`. Extiende el ciclo de vida de
`spec 0003 (not in this snapshot)` (`start`) y `scripts/verify` de
`spec 0005 (not in this snapshot)` sin reabrirlos: `start` además guarda una corrida en
rojo de los CA, y `verify` marca los CA que ya pasaban antes de implementar.
Suma reglas de disciplina a `AGENTS.md` y al agente `implementador`. Ante
conflicto, gana la madre.

**Destinatario:** la sesión del worktree de 0070, con shell, git y
filesystem local.

**Idioma:** documentación y comentarios en español rioplatense;
identificadores, paths y claves de config en inglés.

---

```yaml
id: "0070"
title: "TDD rojo antes de verde y reglas de The Clean Coder"
version: 1
status: verified
created_at: 2026-10-20
updated_at: 2026-10-20
schema_change: false
arch_decision: false
target_branch: "operator/spec-0070-tdd-rojo-antes-de-verde-y-reglas-de-the"
loc_estimate: 140
tier_locked: null
supersedes: null
```

---

## 1. Objetivo

Hoy un CA puede pasar desde antes de escribir una línea de código, y nadie
se entera: el `verify` final da verde igual, aunque el check no pruebe nada
de lo implementado. Esta spec hace tres cosas:

1. El `implementador` trabaja rojo antes de verde: por cada CA escribe o
   corre primero su check, lo ve fallar, implementa lo mínimo para que pase
   y recién después refactoriza.
2. `scripts/spec start` guarda, en el mismo commit de `approved →
   implementing`, la corrida de los CA en ese momento
   (`sessions/rojo/<id>.txt`). `scripts/verify` la contrasta con la corrida
   final: un CA que ya pasaba en rojo sale marcado `[YA-VERDE]`, sin fallar,
   salvo que el CA se declare de compatibilidad (`compat: true`), en cuyo
   caso que ya pase es lo esperado y no se marca.
3. `AGENTS.md` suma cuatro reglas de *The Clean Coder* (Robert C. Martin; no
   *Clean Code*) para cualquier agente del repo.

---

## 2. Alcance

### 2.1 Dentro de alcance (IN)

- `scripts/spec`: `start` corre `scripts/verify <id>` antes de cambiar el
  status, guarda `sessions/rojo/<id>.txt` y lo agrega al mismo commit.
- `scripts/verify` y `scripts/lib/verify.sh`: lectura de
  `sessions/rojo/<id>.txt`, detección de `compat: true` en el bloque YAML
  del CA, línea `[YA-VERDE]` y campo `CA_YA_VERDES=` en la línea `VERIFY=`.
- `tests/fixtures/spec/rojo-approved.md` (nuevo): fixture `approved` con un
  CA que pasa, uno que falla y uno `compat: true` que pasa.
- `.claude/agents/implementador.md`: sección "Rojo antes de verde".
- `AGENTS.md`: punto 5 con las cuatro reglas de *The Clean Coder*.
- `sessions/rojo/0070.txt` (nuevo): corrida en rojo de esta misma spec,
  capturada a mano (D2).

### 2.2 Fuera de alcance (OUT)

- Microservicios: repo-maestro son scripts Bash; no aplica. Si un proyecto
  futuro los necesita, va en su propia spec.
- Corridas en rojo retroactivas para specs `verified` o `implementing`: sin
  `sessions/rojo/<id>.txt`, `verify` se comporta exactamente como hoy.
- Que `[YA-VERDE]` haga fallar `verify` o cambie su exit code.
- Cambios a los workflows de rutas (`ruta-directo`, `ruta-exhaustivo-*`) o
  a `scripts/rutas log` para contar `[YA-VERDE]`.
- `loc_estimate` como rango: la regla de estimar en rango es de conducta del
  agente, no un cambio al front-matter (lint exige los 12 campos actuales).

---

## 3. Requerimientos funcionales

**RF-01 — Corrida en rojo en `start` (extiende `start` de 0003).** Antes de
cambiar el status, `scripts/spec start <id>` corre `scripts/verify <ruta>`,
se queda con las líneas `[PASS] CA-NN` y `[FAIL] CA-NN` (sólo esas dos
palabras, sin el detalle) y las escribe en `sessions/rojo/<id>.txt`, con
`<id>` el del front-matter. Los CA `[SUPERADO]` no se registran. Un exit
distinto de 0 de `verify` es lo esperado y nunca hace fallar `start`.

**RF-02 — Mismo commit.** `start` agrega `sessions/rojo/<id>.txt` al commit
`spec(<id>): approved → implementing`: sigue siendo exactamente un commit,
con el mismo mensaje.

**RF-03 — `[YA-VERDE]` en `verify`.** Si existe `sessions/rojo/<id>.txt`,
para cada CA que da `[PASS]` ahora y figura `[PASS]` en el registro,
`verify` imprime, justo después de su `[PASS]`, la línea
`[YA-VERDE] CA-NN pasaba antes de implementar (sessions/rojo/<id>.txt)`. El
CA sigue contando como PASS; el exit code no cambia. Vale igual con
`--ca`.

**RF-04 — Compatibilidad declarada.** Un CA cuyo bloque YAML tiene
`compat: true` como clave de primer nivel (hermana de `check:`) no se marca
`[YA-VERDE]` aunque pasara en rojo. `compat:` no altera la categorización
`check`/`manual`/`malformed` ni la extracción del comando.

**RF-05 — Campo en la línea final.** Si hubo al menos un `[YA-VERDE]`, la
línea `VERIFY=` termina con ` CA_YA_VERDES=<n>` (después de
`CA_SUPERADOS=` si está). Sin registro o sin marcas, la salida de `verify`
queda byte a byte igual a la de hoy.

**RF-06 — Rojo antes de verde en el `implementador`.**
`.claude/agents/implementador.md` suma la sección "Rojo antes de verde": por
cada CA asignado (1) escribir o completar su `check:` si falta, (2)
correrlo con `scripts/verify <id> --ca CA-NN` y verlo fallar, (3)
implementar lo mínimo para que pase, (4) refactorizar con el CA en verde.
Si el CA ya pasa antes de tocar nada y no es `compat: true`, lo reporta en
vez de seguir como si nada. Se mantiene "Leé `AGENTS.md` completo".

**RF-07 — Reglas de The Clean Coder en `AGENTS.md`.** Punto 5 nuevo, con
estos cuatro títulos literales:
- **Listo es con test.** No se declara "listo" sin un check que lo pruebe y
  que se haya visto en verde.
- **Decir que no.** Ante un pedido que excede la spec, se escala o se dice
  que no; no se fuerza alcance para cumplir.
- **Estimar en rango.** Toda estimación (tiempo, LOC, tokens) va como rango
  con lo que la hace variar, nunca un número único como promesa.
- **Disciplina bajo presión.** El apuro no habilita atajos: ni saltear el
  rojo, ni `--force`, ni bajar un check para que pase.
Los puntos 1–4 actuales no cambian.

---

## 4. Requerimientos no funcionales

**RNF-01 — Sin regresión en specs viejas (hereda RNF-01 de 0046).** La
compatibilidad se prueba con CA filtrados (`scripts/verify <id> --ca
CA-NN`), nunca con un `verify` entero de una spec anterior.

**RNF-02 — Sin reloj de pared.** `sessions/rojo/<id>.txt` sólo tiene el
estado por CA, sin fechas ni duraciones: es determinista y fusionable (un
archivo por spec, no hay conflictos entre worktrees).

**RNF-03 — Bash como el resto (hereda RNF-06 madre).** `set -euo pipefail`;
el exit 1 de `verify` en rojo se captura explícitamente. Sin dependencias
nuevas.

---

## 5. Estructura del entregable

### 5.1 Archivos nuevos o reemplazados

```
scripts/spec                              # RF-01, RF-02
scripts/verify                            # RF-03, RF-05
scripts/lib/verify.sh                     # RF-04 (ca_compat)
tests/fixtures/spec/rojo-approved.md      # nuevo, CA-01..03
.claude/agents/implementador.md           # RF-06
AGENTS.md                                 # RF-07
sessions/rojo/0070.txt                    # nuevo, D2
```

### 5.3 Secuencia

```archify
{
  "diagram_type": "sequence",
  "meta": { "title": "Rojo en start, contraste en verify" },
  "participants": [
    { "id": "op", "type": "frontend", "label": "Sesión", "sublabel": "operador o agente del worktree" },
    { "id": "spec", "type": "backend", "label": "scripts/spec start", "sublabel": "transición approved → implementing" },
    { "id": "verify", "type": "backend", "label": "scripts/verify", "sublabel": "scripts/verify + lib/verify.sh" },
    { "id": "rojo", "type": "database", "label": "Registro rojo", "sublabel": "sessions/rojo/<id>.txt" },
    { "id": "impl", "type": "backend", "label": "implementador", "sublabel": ".claude/agents/implementador.md" }
  ],
  "messages": [
    { "id": "start", "from": "op", "to": "spec", "label": "start <id>", "variant": "emphasis" },
    { "id": "corre", "from": "spec", "to": "verify", "label": "verify <ruta> (exit 1 esperado)", "variant": "default" },
    { "id": "lineas", "from": "verify", "to": "spec", "label": "[PASS]/[FAIL] CA-NN", "variant": "return" },
    { "id": "guarda", "from": "spec", "to": "rojo", "label": "escribe y git add, mismo commit", "variant": "default" },
    { "id": "ok", "from": "spec", "to": "op", "label": "1 commit approved → implementing", "variant": "return" },
    { "id": "encarga", "from": "op", "to": "impl", "label": "CA asignados", "variant": "emphasis" },
    { "id": "rojoca", "from": "impl", "to": "verify", "label": "verify --ca CA-NN: ve fallar", "variant": "default" },
    { "id": "verdeca", "from": "impl", "to": "verify", "label": "implementa mínimo, verify --ca: verde", "variant": "default" },
    { "id": "final", "from": "op", "to": "verify", "label": "verify <id>", "variant": "emphasis" },
    { "id": "lee", "from": "verify", "to": "rojo", "label": "lee el registro", "variant": "dashed" },
    { "id": "marca", "from": "verify", "to": "op", "label": "[YA-VERDE] CA-NN, CA_YA_VERDES=n, exit sin cambio", "variant": "return" },
    { "id": "igual", "from": "verify", "to": "op", "label": "salida idéntica a hoy", "variant": "return" }
  ],
  "segments": [
    { "label": "loop: por cada CA", "from_msg": "rojoca", "to_msg": "verdeca" },
    { "label": "alt: hay registro", "from_msg": "lee", "to_msg": "marca" },
    { "label": "else: spec vieja sin registro", "from_msg": "igual", "to_msg": "igual" }
  ]
}
```

---

## 6. Criterios de aceptación

Binarios. La spec está cumplida si y sólo si los 10 pasan.

- **CA-01** — `start` sobre el fixture guarda la corrida en rojo en el
  mismo commit, con un CA en FAIL, y no falla.
  ```yaml
  check:
    cmd: |
      tmp=$(mktemp -d); git clone -q . "$tmp"
      cp tests/fixtures/spec/rojo-approved.md "$tmp/specs/9999-rojo.md"
      git -C "$tmp" add specs/9999-rojo.md; git -C "$tmp" commit -qm fixture
      "$tmp/scripts/spec" start "$tmp/specs/9999-rojo.md" || { rm -rf "$tmp"; exit 1; }
      ok=1
      [ "$(git -C "$tmp" log -1 --format=%s)" = "spec(9999): approved → implementing" ] || ok=0
      git -C "$tmp" show --name-only --format= HEAD | grep -qx 'sessions/rojo/9999.txt' || ok=0
      [ "$(cat "$tmp/sessions/rojo/9999.txt")" = "$(printf '[PASS] CA-01\n[FAIL] CA-02\n[PASS] CA-03')" ] || ok=0
      rm -rf "$tmp"; [ "$ok" -eq 1 ]
    expect_exit: 0
  ```

- **CA-02** — `verify` marca `[YA-VERDE]` el CA que ya pasaba, no el
  `compat: true`, y no cambia el exit.
  ```yaml
  check:
    cmd: |
      tmp=$(mktemp -d); git clone -q . "$tmp"
      cp tests/fixtures/spec/rojo-approved.md "$tmp/specs/9999-rojo.md"
      git -C "$tmp" add specs/9999-rojo.md; git -C "$tmp" commit -qm fixture
      "$tmp/scripts/spec" start "$tmp/specs/9999-rojo.md" >/dev/null 2>&1 || { rm -rf "$tmp"; exit 1; }
      sed -i.bak 's/cmd: "false"/cmd: "true"/' "$tmp/specs/9999-rojo.md"
      out=$("$tmp/scripts/verify" "$tmp/specs/9999-rojo.md"); rc=$?
      rm -rf "$tmp"
      [ "$rc" -eq 0 ] || exit 1
      [ "$(printf '%s\n' "$out" | grep -c '^\[YA-VERDE\]')" -eq 1 ] || exit 1
      printf '%s\n' "$out" | grep -qx '\[YA-VERDE\] CA-01 pasaba antes de implementar (sessions/rojo/9999.txt)' || exit 1
      printf '%s\n' "$out" | tail -1 | grep -qE ' CA_YA_VERDES=1$'
    expect_exit: 0
  ```

- **CA-03** — `compat: true` no cambia la categorización: el fixture sigue
  dando 3 CA evaluados y `lint` en verde.
  ```yaml
  check:
    cmd: |
      out=$(scripts/verify tests/fixtures/spec/rojo-approved.md 2>&1)
      printf '%s\n' "$out" | tail -1 | grep -q 'CA_TOTAL=3 CA_PASS=2 CA_FAIL=1' || exit 1
      ! printf '%s\n' "$out" | grep -q 'malformed' || exit 1
      scripts/spec lint tests/fixtures/spec/rojo-approved.md >/dev/null
    expect_exit: 0
  ```

- **CA-04** — Compatibilidad 0046 CA-03: sin registro, `verify 0033` sigue
  byte a byte igual al fixture de 0036.
  ```yaml
  compat: true
  check:
    cmd: "scripts/verify 0046 --ca CA-03"
    expect_exit: 0
  ```

- **CA-05** — Compatibilidad 0003 CA-12: `start` sigue siendo un commit con
  el mismo mensaje.
  ```yaml
  compat: true
  check:
    cmd: "scripts/verify 0003 --ca CA-12"
    expect_exit: 0
  ```

- **CA-06** — Compatibilidad 0021 CA-01: los cuatro agentes siguen con su
  front-matter, la referencia a `AGENTS.md` y el límite de irreversibles.
  ```yaml
  compat: true
  check:
    cmd: "scripts/verify 0021 --ca CA-01"
    expect_exit: 0
  ```

- **CA-07** — `AGENTS.md` tiene las cuatro reglas y conserva la de
  worktrees (lo que greppea 0026 CA-08, hoy superado por otra parte de su
  check).
  ```yaml
  check:
    cmd: |
      ok=1
      for r in 'Listo es con test.' 'Decir que no.' 'Estimar en rango.' 'Disciplina bajo presión.'; do
        grep -qF "**$r**" AGENTS.md || ok=0
      done
      grep -q 'The Clean Coder' AGENTS.md || ok=0
      grep -qi 'worktree' AGENTS.md && grep -q 'spec/<id>' AGENTS.md || ok=0
      [ "$ok" -eq 1 ]
    expect_exit: 0
  ```

- **CA-08** — El `implementador` tiene "Rojo antes de verde" con los cuatro
  pasos y el reporte de un CA que ya pasaba.
  ```yaml
  check:
    cmd: |
      f=.claude/agents/implementador.md
      grep -q '^## Rojo antes de verde' "$f" &&
      grep -q 'verlo fallar' "$f" &&
      grep -q 'lo mínimo' "$f" &&
      grep -qi 'refactoriz' "$f" &&
      grep -q 'compat: true' "$f" &&
      grep -q 'scripts/verify <id> --ca' "$f"
    expect_exit: 0
  ```

- **CA-09** — Esta spec se capturó en rojo antes de implementar (D2): el
  registro existe y los CA de comportamiento nuevo figuran en FAIL.
  ```yaml
  check:
    cmd: |
      f=sessions/rojo/0070.txt
      [ -f "$f" ] || exit 1
      for c in CA-01 CA-02 CA-03 CA-07 CA-08; do grep -qx "\[FAIL\] $c" "$f" || exit 1; done
    expect_exit: 0
  ```

- **CA-10** — `scripts/spec lint 0070` y `scripts/doctor` en verde.
  ```yaml
  check:
    cmd: "scripts/spec lint 0070 >/dev/null && bash scripts/doctor >/dev/null"
    expect_exit: 0
  ```

---

## 7. Dependencias y bloqueos

**D1 — `.claude/` no se edita headless. `[RESTRICCIÓN]`** Medido en 0034:
una corrida headless no puede escribir en `.claude/`. El cambio a
`.claude/agents/implementador.md` (RF-06) lo hace la sesión del worktree o
`scripts/ruta`, no un subagente de `ruta-directo`.

**D2 — 0070 no puede usar su propio mecanismo. `[ORDEN]`** Esta spec pasa a
`implementing` con el `start` actual, que no guarda rojo. Para cumplir su
propia regla, antes de escribir código la sesión corre
`scripts/verify 0070 | grep -oE '^\[(PASS|FAIL)\] CA-[0-9]+' >
sessions/rojo/0070.txt` y lo commitea. Ahí todos los CA salvo los `compat:
true` (CA-04..06) y, quizás, CA-10 tienen que estar en FAIL.

**D3 — Alternativas consideradas.** El operador eligió evidencia en
`start` + contraste en `verify` (más el texto en `implementador.md` y
`AGENTS.md`). Descartadas:
- Sólo texto en `implementador.md` y `AGENTS.md`: no deja evidencia; un CA
  que ya pasaba sigue sin verse.
- Rojo registrado por la ruta agéntica en `sessions/rutas.jsonl`: deja
  afuera lo implementado a mano en sesión y toca workflows y el schema de
  `rutas log` (0022/0023).
- Gate duro (`verify` falla si un CA ya pasaba): bloquea CA legítimos como
  lint/doctor y contradice "se marca, no falla".

**D4 — Cuesta tiempo en `start`. `[RIESGO]`** `start` ahora corre todos los
CA de la spec; en specs con clones temporales tarda lo que tarde un
`verify`. Se acepta: pasa una vez por spec.

---

## 8. Datos e integridad

**8.1** `sessions/rojo/<id>.txt` es versionado, un archivo por spec, una
línea `[PASS] CA-NN` o `[FAIL] CA-NN` por CA, sin fechas (RNF-02). Lo
escribe sólo `start` (o la captura a mano de D2); `verify` sólo lo lee.

**8.2** Specs sin registro (todas las anteriores a 0070): `verify` no
cambia ni un byte (RF-05). Un `reopen` + `start` posterior reescribe el
registro con la corrida de ese momento.

---

## §Historial

- 2026-10-27 — v1 — "foto pública: el historial interno no se publica" — operator

## §Traza

*(vacío — se completa con `scripts/spec trace <id>` una vez que exista)*
