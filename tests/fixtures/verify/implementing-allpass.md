# SPEC — Fixture: implementing con todas las CA en verde (tests/fixtures/verify)

**Spec madre:** ninguna — fixture sintética de `spec 0005 (not in this snapshot)` (CA-14).

**Destinatario:** `scripts/spec verify`, en tests, sobre un clon git descartable.

**Idioma:** español rioplatense.

---

```yaml
id: "9112"
title: "Fixture implementing-allpass"
version: 1
status: implementing
created_at: 2026-08-24
updated_at: 2026-08-24
schema_change: false
arch_decision: false
target_branch: "sandbox/fixture"
loc_estimate: 10
tier_locked: null
supersedes: null
```

---

## 1. Objetivo

Fixture de prueba: con `scripts/verify` real, `scripts/spec verify <id>`
debe completar `implementing → verified` porque las dos CA de §6 pasan.

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
- **CA-02** — pasa.
  ```yaml
  check:
    cmd: "test 1 -eq 1"
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
