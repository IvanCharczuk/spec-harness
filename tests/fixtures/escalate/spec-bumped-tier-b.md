# SPEC — Fixture de prueba (escalate) — bumpeada, score da TIER_B

**Spec madre:** `specs/0001-repo-maestro.md`. Fixture de test para
spec 0008 (not in this snapshot), no es una spec real. Simula el caso feliz:
`version` bumpeada, entrada de §Historial presente, y `schema_change:
true` (disparador duro de `spec 0002 (not in this snapshot)`) para que `route` dé
`TIER_B` de forma determinística, sin depender del cálculo de score.

**Destinatario:** ninguno — fixture de test.

**Idioma:** español rioplatense.

---

```yaml
id: "9204"
title: "Fixture de prueba (escalate) — bumpeada, da TIER_B"
version: 2
status: approved
created_at: 2026-08-26
updated_at: 2026-08-26
schema_change: true
arch_decision: false
target_branch: "sandbox/fixture"
loc_estimate: 10
tier_locked: null
supersedes: null
```

---

## 1. Objetivo

Fixture de test, sin contenido real.

---

## 2. Alcance

### 2.1 Dentro de alcance (IN)

- Nada real, es un fixture.

### 2.2 Fuera de alcance (OUT)

- Todo lo demás.

---

## 3. Requerimientos funcionales

**RF-01 — Requerimiento de prueba.** Texto de prueba.

---

## 4. Requerimientos no funcionales

**RNF-01 — Requerimiento no funcional de prueba.** Texto de prueba.

---

## 5. Estructura del entregable

Sin archivos reales.

---

## 6. Criterios de aceptación

- **CA-01** — Criterio de prueba.
  ```yaml
  check:
    cmd: "true"
    expect_exit: 0
  ```

---

## 7. Dependencias y bloqueos

Ninguna.

---

## 8. Datos e integridad

Ninguna.

---

## §Historial

- 2026-08-26 — v1 — "fixture de test" — Ivan Charczuk
- 2026-08-26 — v2 — "bump de prueba, schema_change:true para TIER_B determinístico" — Ivan Charczuk

## §Traza

*(vacío)*
