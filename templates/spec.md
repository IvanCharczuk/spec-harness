# SPEC — <título>

**Spec madre:** `specs/0001-repo-maestro.md`. Esta spec implementa exclusivamente
<RF-NN, RF-NN... de la madre> (<resumen de una línea>). No reabre ni reinterpreta
el resto de la madre; ante conflicto, gana la madre.

**Destinatario:** agente de implementación con acceso a shell, filesystem local
<y qué más: git, red, credenciales>.

**Idioma:** documentación y comentarios en español rioplatense; identificadores,
paths y claves de config en inglés.

---

```yaml
id: "0000"
title: "<título>"
version: 1
status: draft
created_at: 0000-00-00
updated_at: 0000-00-00
schema_change: false
arch_decision: false
target_branch: "spec/0000-slug"
loc_estimate: 0
supersedes: null
```

---

## 1. Objetivo

<Qué RF de la madre implementa esta spec y qué problema concreto resuelve.>

---

## 2. Alcance

### 2.1 Dentro de alcance (IN)

- <ítem>

### 2.2 Fuera de alcance (OUT)

- <ítem, con nota de a qué spec pertenece si no es de nadie todavía>

---

## 3. Requerimientos funcionales

**RF-01 — <título> (implementa RF-NN madre).** <texto>

---

## 4. Requerimientos no funcionales

**RNF-01 — <título> (hereda RNF-NN madre).** <texto>

---

## 5. Estructura del entregable

### 5.1 Archivos nuevos o reemplazados

```
<árbol>
```

### 5.3 Secuencia *(opcional)*

```archify
{
  "diagram_type": "sequence",
  "meta": { "title": "<título del flujo>" },
  "participants": [
    { "id": "a", "type": "frontend", "label": "<quién>", "sublabel": "<qué hace, dónde vive>" },
    { "id": "b", "type": "backend", "label": "<quién>", "sublabel": "<qué hace, dónde vive>" }
  ],
  "messages": [
    { "id": "pedido", "from": "a", "to": "b", "label": "<mensaje>", "variant": "emphasis" },
    { "id": "respuesta", "from": "b", "to": "a", "label": "<respuesta>", "variant": "return" }
  ]
}
```

Renderizar con `scripts/diagrama <id>`: escribe `.state/diagramas/<id>.html`, fuera de git.

Convenciones de flechas (`variant`):

| `variant` | Uso |
|---|---|
| `default` | petición común |
| `emphasis` | camino principal |
| `return` | respuesta |
| `dashed` | asíncrono o efecto lateral |
| `security` | auth o política |

Reglas:

- No hay flechas a sí mismo (archify las rechaza): se escribe una nota o se
  pasa por otro participante.
- `alt`/`else`/`loop` se expresan como `segments` anclados por
  `from_msg`/`to_msg` (ids de mensajes; `scripts/diagrama` los traduce a `y`).
- Una flecha se edita en la IR y se vuelve a renderizar: el visor no edita.

---

## 6. Criterios de aceptación

Binarios. La spec está cumplida si y sólo si los N pasan.

- **CA-01** — <descripción>.
  ```yaml
  check:
    cmd: "<comando>"
    expect_exit: 0
  ```

Nota: en un `cmd:` de varias líneas, una negación que no es la última lleva
`|| exit 1` (`! grep -q X f || exit 1`), porque bajo `set -e` un `! cmd` no
corta. `scripts/spec lint` falla en draft/approved si falta.

---

## 7. Dependencias y bloqueos

**D1 — <título>. `[TAG]`** <texto>

---

## 8. Datos e integridad

**8.1** <texto>

---

## §Historial

- 0000-00-00 — v1 — "borrador inicial" — <autor>

## §Traza

*(vacío — se completa con `scripts/spec trace <id>` una vez que exista)*
