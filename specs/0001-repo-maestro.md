# SPEC — Repo maestro spec-driven (resumen público de la spec madre)

**Nota de esta foto pública.** La spec madre original es un documento largo
atado a un entorno privado (dos cuentas, un binario de agente que no se
publica, carpetas de proyectos externos). Esta versión conserva lo que las
specs incluidas en la copia necesitan: el ciclo spec → lint → route → modo →
ruta → verify, los números de RF/RNF que ellas citan y un puñado de criterios
que sí corren acá. Ante conflicto con una spec hija, sigue ganando la madre.

**Idioma:** documentación y comentarios en español rioplatense;
identificadores, paths y claves de config en inglés.

---

```yaml
id: "0001"
title: "Repo maestro spec-driven (resumen público de la spec madre)"
version: 1
status: verified
created_at: 2026-08-21
updated_at: 2026-10-27
schema_change: false
arch_decision: false
target_branch: "main"
loc_estimate: 0
tier_locked: null
supersedes: null
```

---

## 1. Objetivo

Un repositorio local **spec-driven**: la unidad de trabajo es una **spec
versionada en git**, no un prompt suelto. Nada se ejecuta sin spec, nada se
rutea sin leer la spec, nada se da por terminado sin correr sus criterios de
aceptación.

Problemas que resuelve: la elección del esfuerzo por tarea es ad hoc y no
queda registrada; la complejidad se estima a ojo cuando ya es tarde; el
trabajo no tiene una definición de terminado verificable ("está listo" es una
opinión); no hay traza entre lo que se pidió, dónde se ejecutó y qué se
commiteó.

**Usuario único:** operador individual, entorno local.

---

## 2. Alcance

### 2.1 Dentro de alcance (IN)

- `specs/` como unidad de trabajo, con plantilla canónica de 8 secciones y
  front-matter estructurado.
- Gate de arranque: no hay sesión sin spec aprobada.
- Scorer determinístico de complejidad que decide el modo, sin estimación
  manual.
- Runner de criterios de aceptación: cada CA declara comando y exit esperado.
- Ciclo de vida (`draft → approved → implementing → verified → archived`) con
  transiciones como commit.
- Trazabilidad spec ↔ sesión ↔ commit, verificada por hook y por `doctor`.
- Hooks `pre-commit` y `commit-msg`, y política de secretos.

### 2.2 Fuera de alcance (OUT)

- No aloja código de aplicaciones productivas: es capa de orquestación.
- No genera specs sin revisión humana: una spec pasa a `approved` sólo por
  acción explícita del operador.
- No usa un LLM en el camino del scorer: el ruteo es determinístico (RNF-07).
- No implementa CI/CD ni ejecución remota desatendida.

---

## 3. Requerimientos funcionales

Numeración de la madre completa; acá, una línea por RF.

**RF-01 — Estructura.** El árbol del repo (scripts, config, templates, specs, sessions, tests).

**RF-02 — Plantilla canónica de spec.** `templates/spec.md` con front-matter YAML y las 8 secciones obligatorias.

**RF-03 — Validador de spec.** `scripts/spec lint <id>` falla con exit distinto de 0 si falta una sección, un campo del front-matter, un requerimiento sin numerar o un CA sin `check:` ni `manual: true`.

**RF-04 — Gate de arranque.** No se abre sesión sin una spec que exista, pase el lint y esté `approved` o `implementing`.

**RF-05 — Scorer determinístico de complejidad.** `scripts/route --spec <id>` calcula la complejidad leyendo la spec, sin LLM ni red.

**RF-06 — Determinismo verificable.** Dos corridas sobre el mismo contenido dan salida byte-idéntica.

**RF-07 — Anulación manual explícita.** `--force` exige `--reason` no vacío y queda registrada.

**RF-08 — Ciclo de vida de spec.** Transiciones únicas permitidas, cada una como commit.

**RF-09 — Criterios de aceptación ejecutables.** Cada CA lleva un bloque `check:` (`cmd`, `expect_exit`) o `manual: true`.

**RF-10 — Trazabilidad bidireccional.** Spec, sesión y commit se enlazan con el trailer `Spec-Id:`.

**RF-11 — Escalado como delta de spec.** Superar un disparador duro o el umbral en pleno trabajo se resuelve con un bump de versión y changelog, no con un brief paralelo.

**RF-12 — Sin degradación en caliente.** Una tarea que arrancó en el modo de más esfuerzo no baja de modo dentro de la misma sesión.

**RF-13 — Perfiles.** `config/profiles/*.yaml` declara los campos del perfil de cada backend.

**RF-14 — Aislamiento de credenciales.** Variables por perfil, nunca compartidas en la misma shell.

**RF-15 — Delegación al binario del agente.** Cada perfil delega al wrapper de su tier.

**RF-16 — Contexto de agente.** `AGENTS.md` común y un contrato por modo.

**RF-17 — Bootstrap idempotente.** `scripts/bootstrap` valida el runtime, crea `.state/`, materializa perfiles e instala hooks.

**RF-18 — Doctor.** `scripts/doctor` corre checks individuales con exit 0 o 1.

**RF-19 — Allowlist de plugins.** `config/plugins.lock.yaml` con versión exacta.

**RF-20 — Secretos.** `.gitignore` excluye estado y credenciales; `pre-commit` escanea y aborta ante hallazgo.

**RF-21 — Paralelismo.** Locks y puertos distintos por sesión.

**RF-22 — Kill switch.** `scripts/kill` termina las sesiones de un perfil y libera sus locks.

**RF-23 — Registro de sesión.** Una línea por sesión en `sessions/index.jsonl`.

**RF-24 — Calibración.** `scripts/route --stats` reporta la distribución de ruteo a partir del registro.

**RF-25 — Carpeta de entornos.** No forma parte de esta foto pública.

**RF-26 — Modo de trabajo por complejidad.** `scripts/rmaestro` imprime `MODO=<directo|exhaustivo>`; cada modo tiene su contrato en `templates/MODE.md.*`.

**RF-27 — Aislamiento por worktree.** Una spec por worktree y por rama; el agente no cambia de rama ni toca `main`.

---

## 4. Requerimientos no funcionales

**RNF-01 — Runtime.** Node.js `^22.19.0 || >=24.0.0`.

**RNF-02 — Superficie de red.** Toda UI local bindea sólo a `127.0.0.1`.

**RNF-03 — Sandbox.** Backend declarado por perfil, con el mecanismo nativo del SO.

**RNF-04 — Versión pineada.** Pin exacto de lo que se instala, en `config/versions.yaml`.

**RNF-05 — Reproducibilidad.** Clonar y correr `bootstrap` deja el entorno operativo sin pasos no documentados.

**RNF-06 — Formato.** Specs y docs en Markdown con front-matter YAML; config en YAML; scripts en Bash con `set -euo pipefail`; sin dependencias de runtime nuevas.

**RNF-07 — Auditabilidad del ruteo.** El scorer es determinístico, offline y legible: cualquiera reproduce la decisión a mano.

**RNF-08 — La spec es la fuente de verdad.** Ante divergencia entre spec y código, gana la spec: se corrige el código o se bumpea la spec.

**RNF-09 — Costo del proceso.** Escribir la spec no puede costar más que la tarea.

**RNF-10 — Publicación.** El repo de trabajo es privado. Esta copia es una foto única, curada y sin historial, que el operador decidió publicar; no se sincroniza.

**RNF-11 — Cuota.** El harness es gratuito; el costo lo determina el backend.

---

## 5. Estructura del entregable

### 5.1 Árbol de directorios

`scripts/` (los ejecutables y `scripts/lib/`), `config/`, `templates/`,
`specs/`, `sessions/`, `tests/`, `.githooks/`, `.claude/` (agentes,
workflows y comandos) y `AGENTS.md`.

### 5.3 Front-matter de spec

Los 12 campos que valida `spec lint`: `id`, `title`, `version`, `status`,
`created_at`, `updated_at`, `schema_change`, `arch_decision`,
`target_branch`, `loc_estimate`, `tier_locked`, `supersedes`.

---

## 6. Criterios de aceptación

Binarios. De los 18 de la madre completa, esta foto conserva los que corren
sin el entorno privado.

- **CA-01** — `spec lint` falla con exit distinto de 0 sobre una spec a la que se le borró una sección.
  ```yaml
  check:
    cmd: "scripts/spec lint tests/fixtures/spec/missing-section.md"
    expect_exit: 1
  ```

- **CA-02** — `spec lint` falla sobre una spec con un CA sin `check:` ni `manual: true`.
  ```yaml
  check:
    cmd: "scripts/spec lint tests/fixtures/spec/ca-without-check.md"
    expect_exit: 1
  ```

- **CA-03** — `spec lint` pasa sobre una spec válida.
  ```yaml
  check:
    cmd: "scripts/spec lint tests/fixtures/spec/valid-draft.md"
    expect_exit: 0
  ```

- **CA-04** — `scripts/route --spec <id>` corrido dos veces sobre contenido idéntico produce stdout byte-idéntico.
  ```yaml
  check:
    cmd: "diff <(scripts/route --spec 0012) <(scripts/route --spec 0012)"
    expect_exit: 0
  ```

- **CA-05** — Sesión con el entorno de dos cuentas, paralelismo real y calibración sobre registros: no se reproduce en esta foto.
  ```yaml
  manual: true
  ```

---

## 7. Dependencias y bloqueos

Los bloqueos de la madre completa dependen de cuentas y de un binario que no
forman parte de esta foto. Los riesgos que sí aplican: la cuota del backend
(RNF-11) y que los contratos del agente cambian entre versiones (RNF-04).

---

## 8. Datos e integridad

Los registros (`sessions/index.jsonl`, `sessions/rutas.jsonl`) son locales,
una línea JSON por evento; nunca llevan credenciales ni transcripts crudos
(`sessions/raw/` está fuera de git). En esta foto, `sessions/rutas.jsonl` es
sólo un ejemplo.

---

## §Historial

- 2026-10-27 — v1 — "foto pública: el historial interno no se publica" — operator

## §Traza

*(vacío — se completa con `scripts/spec trace <id>` una vez que exista)*
