# Fixture — anclas por id de mensaje (0051, RF-03)

Un segment y una activación anclados con `from_msg`/`to_msg`, sin
coordenadas escritas.

### 5.3 Secuencia

```archify
{
  "diagram_type": "sequence",
  "meta": { "title": "Fixture anclas" },
  "participants": [
    { "id": "ag", "type": "frontend", "label": "Agente" },
    { "id": "dg", "type": "backend", "label": "diagrama" },
    { "id": "ar", "type": "external", "label": "archify" }
  ],
  "messages": [
    { "id": "pide", "from": "ag", "to": "dg", "label": "pide" },
    { "id": "valida", "from": "dg", "to": "ar", "label": "valida" },
    { "id": "ok", "from": "ar", "to": "dg", "label": "ok", "variant": "return" },
    { "id": "ruta", "from": "dg", "to": "ag", "label": "ruta", "variant": "return" }
  ],
  "segments": [
    { "from_msg": "valida", "to_msg": "ok", "label": "IR buena" }
  ],
  "activations": [
    { "participant": "dg", "from_msg": "pide", "to_msg": "ruta", "type": "backend" }
  ]
}
```
