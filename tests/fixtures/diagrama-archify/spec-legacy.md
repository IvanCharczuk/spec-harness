# Fixture — spec con el formato de 0025 (congelado por 0051)

Sólo trae un fence `diagrama` en YAML: `scripts/diagrama` no lo renderiza y
no toca este archivo.

### 5.3 Secuencia

```diagrama
participantes:
  - { id: OP, nombre: Operador, hace: "pide el diagrama", vive_en: ["chat"] }
  - { id: SC, nombre: Script, hace: "responde", vive_en: ["scripts/"] }
secuencia:
  - { de: OP, a: SC, msg: "pedido", tipo: peticion }
  - { de: SC, a: OP, msg: "respuesta", tipo: respuesta }
```
