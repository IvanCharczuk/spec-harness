# AGENTS.md

Contrato común para cualquier agente (dsh o Claude Code) que opere en este
repo, sin importar el tier (RF-16):

1. Leer la spec activa (`specs/<id>-*.md`) antes de tocar nada.
2. No exceder el §Alcance de esa spec.
3. Declarar escalado apenas se cruce un disparador duro o el umbral de
   complejidad — no seguir de largo con más alcance del que la spec cubre.
4. En un worktree del IDE de worktrees o de `scripts/tmux-spec`, el agente trabaja sólo
   en su worktree y su rama: `spec/<id>-…` si la creó `scripts/tmux-spec`,
   o la que derivó el IDE de worktrees (`<prefijo>/spec-<id>-…`); en los dos casos es el
   `target_branch` de la spec. Nunca hace `git checkout` a otra rama, nunca
   toca `main` ni otro worktree, nunca comparte `.state/locks` ni
   `.state/claude`. Registra sus corridas en `sessions/rutas.jsonl` de su
   rama; la fusión a `main` es del operador (RF-07 de
   `spec 0026 (not in this snapshot)`).
5. Reglas de disciplina de *The Clean Coder* (Robert C. Martin), RF-07 de
   `specs/0070-tdd-rojo-antes-de-verde-y-reglas-de-the-clean-coder.md`:
   - **Listo es con test.** No se declara "listo" sin un check que lo pruebe
     y que se haya visto en verde.
   - **Decir que no.** Ante un pedido que excede la spec, se escala o se dice
     que no; no se fuerza alcance para cumplir.
   - **Estimar en rango.** Toda estimación (tiempo, LOC, tokens) va como
     rango con lo que la hace variar, nunca un número único como promesa.
   - **Disciplina bajo presión.** El apuro no habilita atajos: ni saltear el
     rojo, ni `--force`, ni bajar un check para que pase.

La profundidad de planificación exigida, la política de aprobación de
comandos destructivos y la verbosidad del log difieren por **modo de
trabajo**; ver `templates/MODE.md.directo` y `templates/MODE.md.exhaustivo`
(RF-04 de `spec 0014 (not in this snapshot)`). El modo lo imprime
`scripts/rmaestro` en su última línea, `MODO=...`;
`templates/CLAUDE.md.personal` / `.work` son el camino legado por tier.
