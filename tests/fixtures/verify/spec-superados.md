# SPEC — Fixture: CA que pasa, CA que falla y CA con exit 127 (tests/fixtures/verify)

Fixture sintética para CA-01/CA-02 de
`spec 0046 (not in this snapshot)`.
No representa una spec real.

```yaml
id: "9104"
title: "Fixture spec-superados"
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

Fixture de prueba: CA-01 pasa, CA-02 falla (a propósito, para que el
registro de `ca-superados.yaml` lo supere en la prueba) y CA-03 da exit
127 (para probar la pista de RF-03 de 0046).

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
- **CA-02** — falla a propósito (exit real 1, esperado 0); en
  `superados-ok.yaml` está superado por 0033.
  ```yaml
  check:
    cmd: "false"
    expect_exit: 0
  ```
- **CA-03** — comando inexistente, exit real 127.
  ```yaml
  check:
    cmd: "comando-inexistente-fixture-0046"
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
