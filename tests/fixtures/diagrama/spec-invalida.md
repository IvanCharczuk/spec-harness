# SPEC — Fixture de prueba (diagrama inválida)

**Spec madre:** `specs/0001-repo-maestro.md`. Fixture de test para
spec 0025 (not in this snapshot),
no es una spec real.

**Destinatario:** ninguno — fixture de test.

**Idioma:** español rioplatense.

---

```yaml
id: "9003"
title: "Fixture de prueba (diagrama) — inválida"
version: 1
status: draft
created_at: 2026-09-16
updated_at: 2026-09-16
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

### 5.3 Secuencia

```diagrama
capas:
  - { id: origen, nombre: Origen }
  - { id: destino, nombre: Destino }
participantes:
  - { id: O, nombre: "origen-svc", capa: origen, hace: "Dispara el pedido", vive_en: ["ejemplo/origen.sh"] }
  - { id: D, nombre: "destino-svc", capa: inexistente, hace: "Procesa el pedido", vive_en: ["ejemplo/destino.sh"] }
secuencia:
  - { de: O, a: D, msg: "pedido", tipo: raro }
  - alt: "hay dato"
    pasos: []
```
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

- 2026-09-16 — v1 — "fixture de test" — Ivan Charczuk

## §Traza

*(vacío)*
