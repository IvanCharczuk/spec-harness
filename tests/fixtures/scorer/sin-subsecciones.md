# SPEC — Fixture sin subsecciones (tests/fixtures/scorer)

Fixture sintética para CA-01 de `spec 0027 (not in this snapshot)...md`.
§5 no tiene ningún `### 5.x`: un fence pelado con 2 paths y una tabla de 3
filas con paths adentro (para probar que la regla de tabla sigue actuando
dentro del fence), y después un fence ```yaml``` con paths y texto con
paths fuera de fences, ninguno de los cuales debe contarse (RF-01). No
representa una spec real (§8.4 de 0002).

```yaml
id: "9003"
title: "Fixture sin subsecciones"
version: 1
status: draft
schema_change: false
arch_decision: false
target_branch: "personal/fixture"
loc_estimate: 50
tier_locked: null
supersedes: null
```

## 1. Objetivo

Fixture de prueba, sin contenido real.

## 2. Alcance

### 2.1 Dentro de alcance (IN)

- Contenido sintético para probar el scorer.

### 2.2 Fuera de alcance (OUT)

- Cualquier uso real.

## 3. Requerimientos funcionales

**RF-01** — placeholder.
**RF-02** — placeholder.
**RF-03** — placeholder.

## 4. Requerimientos no funcionales

**RNF-01** — placeholder, no cuenta para el score.

## 5. Estructura del entregable

```
scripts/foo
docs/bar.md

| Archivo | Qué hace | Dónde vive |
|---|---|---|
| Uno | hace algo | `scripts/uno.sh` |
| Dos | hace otra cosa | `docs/dos.md` |
| Tres | hace lo tercero | `config/tres.yaml` |
```

```yaml
paths:
  - scripts/no-contar.sh
  - docs/no-contar.md
```

Ver también `scripts/tampoco-contar.sh` para más detalle, fuera de todo fence.

## 6. Criterios de aceptación

- **CA-01** — placeholder.
- **CA-02** — placeholder.
- **CA-03** — placeholder.

## 7. Dependencias y bloqueos

Sin bloqueos declarados.

## 8. Datos e integridad

Sin marcas pendientes.

## §Historial

*(vacío — versión 1, borrador inicial, sin bumps todavía)*

## §Traza

*(vacío)*
