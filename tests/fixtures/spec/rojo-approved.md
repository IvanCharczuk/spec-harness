# SPEC — Fixture de prueba (lint)

**Spec madre:** `specs/0001-repo-maestro.md`. Fixture de test para
specs/0070-tdd-rojo-antes-de-verde-y-reglas-de-the-clean-coder.md, no es una spec real.

**Destinatario:** ninguno — fixture de test.

**Idioma:** español rioplatense.

---

```yaml
id: "9999"
title: "Fixture de rojo antes de verde"
version: 1
status: approved
created_at: 2026-08-21
updated_at: 2026-08-21
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

- **CA-01** — Pasa desde antes de implementar.
  ```yaml
  check:
    cmd: "true"
    expect_exit: 0
  ```

- **CA-02** — Falla hasta que se implemente.
  ```yaml
  check:
    cmd: "false"
    expect_exit: 0
  ```

- **CA-03** — Compatibilidad: pasa antes y después, es lo esperado.
  ```yaml
  compat: true
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

- 2026-08-21 — v1 — "fixture de test" — Ivan Charczuk

## §Traza

*(vacío)*
