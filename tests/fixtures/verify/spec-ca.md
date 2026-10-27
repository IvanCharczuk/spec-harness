# SPEC — Fixture: tres CA (PASS, FAIL, MANUAL) para `--ca` (tests/fixtures/verify)

Fixture sintética para CA-01/CA-02 de `specs/0036-verify-ca-un-ca-por-scripts-verify-nunca-el-check-copiado-a-mano.md`. No representa una spec real.

```yaml
id: "9103"
title: "Fixture spec-ca"
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

Fixture de prueba: CA-01 pasa, CA-02 falla, CA-03 es manual y está
firmada (pasa) — prueba `scripts/verify --ca` (RF-01 de 0036).

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

- **CA-01** — pasa.
  ```yaml
  check:
    cmd: "true"
    expect_exit: 0
  ```
- **CA-02** — falla a propósito (exit real 1, esperado 0).
  ```yaml
  check:
    cmd: "false"
    expect_exit: 0
  ```
- **CA-03** — manual, firmada.
  ```yaml
  manual: true
  signed_off_by: "fixture"
  signed_off_at: "2026-09-28"
  ```

## 7. Dependencias y bloqueos

Sin bloqueos declarados.

## 8. Datos e integridad

Sin marcas pendientes.

## §Historial

*(vacío — fixture sintética)*

## §Traza

*(vacío)*
