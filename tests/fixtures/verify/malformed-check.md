# SPEC — Fixture: check: malformado (tests/fixtures/verify)

Fixture sintética para CA-11 de `spec 0005 (not in this snapshot)`. No representa una spec real.

```yaml
id: "9110"
title: "Fixture malformed-check"
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

Fixture de prueba: CA-01 tiene `check:` con `cmd:` pero sin
`expect_exit:` (malformada); CA-02 es una `check:` válida que pasa.
Prueba que una CA malformada cuenta en `CA_TOTAL` pero no infla
`MANUAL_RATIO` (RF-04).

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

- **CA-01** — malformada a propósito: falta expect_exit:.
  ```yaml
  check:
    cmd: "true"
  ```
- **CA-02** — válida, pasa.
  ```yaml
  check:
    cmd: "true"
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
