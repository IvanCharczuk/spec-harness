# SPEC — Fixture de prueba (repo de juguete de 0086)

**Spec madre:** `specs/0001-repo-maestro.md`. Fixture de test para
spec 0086 (not in this snapshot),
no es una spec real.

**Destinatario:** ninguno — fixture de test.

**Idioma:** español rioplatense.

---

```yaml
id: "9086"
title: "Fixture de prueba (repo de juguete de 0086) — implementing"
version: 1
status: implementing
created_at: 2026-10-27
updated_at: 2026-10-27
schema_change: false
arch_decision: false
target_branch: "sandbox/fixture"
loc_estimate: 10
tier_locked: null
supersedes: null
```

---

## 1. Objetivo

Fixture de test: el agente escribe `hola` en `salida.txt`.

---

## 2. Alcance

### 2.1 Dentro de alcance (IN)

- `salida.txt` con una sola línea: `hola`.

### 2.2 Fuera de alcance (OUT)

- Todo lo demás.

---

## 3. Requerimientos funcionales

**RF-01 — Saludo.** `salida.txt` tiene exactamente una línea, `hola`.

---

## 4. Requerimientos no funcionales

**RNF-01 — Requerimiento no funcional de prueba.** Texto de prueba.

---

## 5. Estructura del entregable

### 5.1 Archivos nuevos o reemplazados

```
salida.txt
```

---

## 6. Criterios de aceptación

- **CA-01** — `salida.txt` tiene la línea `hola`.
  ```yaml
  check:
    cmd: "grep -qx hola salida.txt"
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

- 2026-10-27 — v1 — "fixture de test" — Ivan Charczuk

## §Traza

*(vacío)*
