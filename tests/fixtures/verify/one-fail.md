# SPEC — Fixture: una CA falla, no hay fail-fast (tests/fixtures/verify)

Fixture sintética para CA-02 de `spec 0005 (not in this snapshot)`. No representa una spec real.

```yaml
id: "9102"
title: "Fixture one-fail"
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

Fixture de prueba: la primera CA falla, la segunda pasa — prueba que
`scripts/verify` evalúa todas sin cortar en la primera (RF-02).

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

- **CA-01** — falla a propósito (exit real 1, esperado 0).
  ```yaml
  check:
    cmd: "false"
    expect_exit: 0
  ```
- **CA-02** — pasa.
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
