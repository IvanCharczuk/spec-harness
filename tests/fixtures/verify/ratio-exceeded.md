# SPEC — Fixture: ratio de manuales excedido (tests/fixtures/verify)

Fixture sintética para CA-09/CA-10 de `spec 0005 (not in this snapshot)`. No representa una spec real.

```yaml
id: "9109"
title: "Fixture ratio-exceeded"
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

Fixture de prueba: 2 CA, ambas pasan individualmente, pero 1 de 2 es
manual (50%) — por encima del `max_manual_ratio` por defecto (0.3).
Prueba el gate de ratio de RF-04 aun con todas las CA individuales en
verde.

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

- **CA-01** — check, trivial, pasa.
  ```yaml
  check:
    cmd: "true"
    expect_exit: 0
  ```
- **CA-02** — manual, firmada correctamente.
  ```yaml
  manual: true
  signed_off_by: Fixture Autor
  signed_off_at: 2026-08-24
  ```

## 7. Dependencias y bloqueos

Sin bloqueos declarados.

## 8. Datos e integridad

Sin marcas pendientes.

## §Historial

*(vacío — fixture sintética)*

## §Traza

*(vacío)*
