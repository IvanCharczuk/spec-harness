# SPEC — Fixture de prueba (escalate) — bumpeada, score sigue TIER_A

**Spec madre:** `specs/0001-repo-maestro.md`. Fixture de test para
spec 0008 (not in this snapshot), no es una spec real. Simula el caso en que las
precondiciones de RF-02/RF-03 se cumplen (version bumpeada, entrada de
Historial), pero el score tras el bump sigue dando `TIER_A` (RF-05,
CA-05) — `schema_change: false` y sin señales que empujen el score
sobre `threshold_simple`.

**Destinatario:** ninguno — fixture de test.

**Idioma:** español rioplatense.

---

```yaml
id: "9203"
title: "Fixture de prueba (escalate) — bumpeada, sigue TIER_A"
version: 2
status: approved
created_at: 2026-08-26
updated_at: 2026-08-26
schema_change: false
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
- 2026-08-26 — v2 — "bump de prueba, sin cambiar señales de score" — Ivan Charczuk

## §Traza

*(vacío)*
