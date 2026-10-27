# SPEC — Fixture de prueba (session logging) — verify all-pass

**Spec madre:** `specs/0001-repo-maestro.md`. Fixture de test para
spec 0006 (not in this snapshot), no es una spec real.

**Destinatario:** ninguno — fixture de test.

**Idioma:** español rioplatense.

---

```yaml
id: "9202"
title: "Fixture de prueba (session logging) — verify all-pass"
version: 1
status: approved
created_at: 2026-08-25
updated_at: 2026-08-25
schema_change: false
arch_decision: false
target_branch: "sandbox/fixture"
loc_estimate: 10
tier_locked: null
supersedes: null
```

---

## 1. Objetivo

Fixture de test: todas las CA de §6 pasan, para probar
`verify_result=pass` (CA-11 de 0006).

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

- **CA-01** — Pasa.
  ```yaml
  check:
    cmd: "true"
    expect_exit: 0
  ```
- **CA-02** — Pasa.
  ```yaml
  check:
    cmd: "test 1 -eq 1"
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

- 2026-08-25 — v1 — "fixture de test" — Ivan Charczuk

## §Traza

*(vacío)*
