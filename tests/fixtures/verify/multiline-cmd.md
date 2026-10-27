# SPEC — Fixture: cmd multilínea con bloque literal (tests/fixtures/verify)

Fixture sintética para CA-03 de `spec 0005 (not in this snapshot)`. No representa una spec real.

```yaml
id: "9103"
title: "Fixture multiline-cmd"
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

Fixture de prueba: 1 CA con `cmd: |` de varios pasos, para probar el
estilo 2 de RF-01 (bloque literal, dedent seguro).

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

- **CA-01** — script de varios pasos, pasa.
  ```yaml
  check:
    cmd: |
      set -e
      x=1
      y=$((x + 1))
      [ "$y" -eq 2 ]
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
