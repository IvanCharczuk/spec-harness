# SPEC — Fixture: todas las CA pasan (tests/fixtures/verify)

Fixture sintética para CA-01 de `spec 0005 (not in this snapshot)`. No representa una spec real.

```yaml
id: "9101"
title: "Fixture all-pass"
version: 1
status: draft
schema_change: false
arch_decision: false
target_branch: "sandbox/fixture"
loc_estimate: 10
tier_locked: null
supersedes: null
```

## 1. Objetivo

Fixture de prueba, sin contenido real.

## 2. Alcance

Sólo para tests/fixtures/verify.

## 3. Requerimientos funcionales

**RF-01** — placeholder.

## 4. Requerimientos no funcionales

**RNF-01** — placeholder.

## 5. Estructura del entregable

```
scripts/foo
```

## 6. Criterios de aceptación

- **CA-01** — trivial, pasa.
  ```yaml
  check:
    cmd: "true"
    expect_exit: 0
  ```
- **CA-02** — trivial, pasa.
  ```yaml
  check:
    cmd: "test 1 -eq 1"
    expect_exit: 0
  ```
- **CA-03** — trivial, pasa.
  ```yaml
  check:
    cmd: "[ -d . ]"
    expect_exit: 0
  ```

## 7. Dependencias y bloqueos

Sin bloqueos declarados.

## 8. Datos e integridad

Sin marcas pendientes.

## §Historial

*(vacío — fixture sintética)*

## §Traza

*(vacío)*
