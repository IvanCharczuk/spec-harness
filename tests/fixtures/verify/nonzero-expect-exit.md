# SPEC — Fixture: expect_exit distinto de 0 (tests/fixtures/verify)

Fixture sintética para CA-04 de `spec 0005 (not in this snapshot)`. No representa una spec real.

```yaml
id: "9104"
title: "Fixture nonzero-expect-exit"
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

Fixture de prueba: cmd sale con exit 3, expect_exit: 3 — prueba que
`expect_exit` no está hardcodeado a 0.

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

- **CA-01** — sale 3, se espera 3.
  ```yaml
  check:
    cmd: "exit 3"
    expect_exit: 3
  ```

## 7. Dependencias y bloqueos

Sin bloqueos declarados.

## 8. Datos e integridad

Sin marcas pendientes.

## §Historial

*(vacío — fixture sintética)*

## §Traza

*(vacío)*
