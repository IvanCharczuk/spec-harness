# SPEC — Fixture de prueba (escalate) — bumpeada sin entrada de Historial

**Spec madre:** `specs/0001-repo-maestro.md`. Fixture de test para
spec 0008 (not in this snapshot), no es una spec real. Simula el caso en que
`version` sí se bumpeó pero §Historial no tiene la entrada
correspondiente a esa versión (RF-03, CA-02).

**Destinatario:** ninguno — fixture de test.

**Idioma:** español rioplatense.

---

```yaml
id: "9202"
title: "Fixture de prueba (escalate) — bumpeada sin Historial"
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

## §Traza

*(vacío)*
