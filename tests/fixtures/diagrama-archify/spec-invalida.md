# Fixture — spec con IR que archify rechaza (0051)

JSON válido, pero `schema_version` no es 1: archify da su diagnóstico.

### 5.3 Secuencia

```archify
{
  "schema_version": 99,
  "diagram_type": "sequence",
  "meta": { "title": "Fixture inválida" },
  "participants": [
    { "id": "ag", "type": "frontend", "label": "Agente" },
    { "id": "dg", "type": "backend", "label": "diagrama" }
  ],
  "messages": [
    { "from": "ag", "to": "dg", "label": "pedido" },
    { "from": "dg", "to": "ag", "label": "respuesta", "variant": "return" }
  ]
}
```
