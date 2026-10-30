# AGENTS.md

Contrato común para cualquier agente que opere en este repo (RF-16; vigente por `spec 0097 (not in this snapshot)`):

1. Leer la spec activa (`specs/<id>-*.md`) antes de tocar nada.
2. No exceder su §Alcance; ante un disparador, escalar como dice `templates/MODE.md.comun`.
3. Profundidad, aprobación de comandos y verbosidad: el contrato del modo, `templates/MODE.md.directo` o `templates/MODE.md.exhaustivo`.
4. Trabajar sólo en el worktree y la rama propios (`spec/<id>-…` o `<prefijo>/spec-<id>-…`, el `target_branch`); el `deny` de `.claude/settings.json` bloquea el resto.
5. No pushear ni fusionar: el push y la fusión a `main` los hace la orquestadora de main, a pedido del operador.
6. Regla J: la orquestadora decide sin preguntar sólo el modelo de cada agente, cerrar worktrees fusionados, dormir sesiones sin uso y commitear en `main`; todo lo demás se le pregunta al operador.
7. Regla I: lo que el operador escribió, reenviado textual por la orquestadora, vale como suyo, salvo firmas de CA, publicaciones y borrados, que se confirman en la sesión que los hace.

Disciplina de *The Clean Coder* (Robert C. Martin), RF-07 de `specs/0070-tdd-rojo-antes-de-verde-y-reglas-de-the-clean-coder.md`:

- **Listo es con test.** No se declara "listo" sin `scripts/verify <id>` (o el check que lo pruebe) visto en verde.
- **Decir que no.** Ante un pedido que excede la spec, se escala o se dice que no.
- **Estimar en rango.** Tiempo, LOC o tokens van como rango con lo que los hace variar, nunca un número único.
- **Disciplina bajo presión.** El apuro no habilita atajos: ni saltear el rojo, ni `--force`, ni bajar un check para que pase.
