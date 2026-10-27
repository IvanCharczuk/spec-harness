# Fixture — spec mínima con fence archify (0051)

IR `sequence` sin `y` ni `meta.output`: los completa `scripts/diagrama`.

### 5.3 Secuencia

```archify
{
  "diagram_type": "sequence",
  "meta": { "title": "Fixture mínima" },
  "participants": [
    { "id": "ag", "type": "frontend", "label": "Agente", "sublabel": "redacta la IR" },
    { "id": "dg", "type": "backend", "label": "diagrama", "sublabel": "valida y renderiza" },
    { "id": "ar", "type": "external", "label": "archify", "sublabel": "vendor" }
  ],
  "messages": [
    { "from": "ag", "to": "dg", "label": "diagrama <id>", "variant": "emphasis" },
    { "from": "dg", "to": "ar", "label": "validate + render" },
    { "from": "ar", "to": "dg", "label": "HTML", "variant": "return" },
    { "from": "dg", "to": "ag", "label": "ruta del HTML", "variant": "return" }
  ]
}
```
