# SPEC — Fixture: manual sin signed_off_by (tests/fixtures/verify)

Fixture sintética para CA-06 de `spec 0005 (not in this snapshot)`. No representa una spec real.

```yaml
id: "9106"
title: "Fixture manual-unsigned"
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

Fixture de prueba: 1 CA `manual: true` sin `signed_off_by` — debe dar
FAIL (RF-03).

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

- **CA-01** — manual, sin firmar.
  ```yaml
  manual: true
  ```

## 7. Dependencias y bloqueos

Sin bloqueos declarados.

## 8. Datos e integridad

Sin marcas pendientes.

## §Historial

*(vacío — fixture sintética)*

## §Traza

*(vacío)*
