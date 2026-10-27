export const meta = {
  name: 'ruta-exhaustivo-plan',
  description: 'Ruta agentica del modo exhaustivo, primera mitad: panel de planificadores y refutadores por plan (3 y 3 por defecto, dimensionable por args.perfiles.panel), sintesis. No edita nada (RF-03 de 0021, RF-04 de 0023)',
  whenToUse: 'Cuando scripts/rmaestro imprimio MODO=exhaustivo. El plan que devuelve lo aprueba el operador antes de correr ruta-exhaustivo-impl. args: { spec: "<id>", perfiles: { panel: {...} } }',
  phases: [
    { title: 'Planificar', detail: 'enfoques independientes segun panel.planificadores' },
    { title: 'Refutar', detail: 'refutadores por plan segun panel.refutadores_por_plan, en paralelo' },
    { title: 'Sintetizar', detail: 'un plan ganador con los reparos sobrevivientes' },
  ],
}

// Perfiles por agente (modelo + esfuerzo): llegan por args.perfiles, que el
// agente de la sesion resuelve con `scripts/rutas perfiles --spec <id>`
// desde config/rutas.yaml (RF-04 de 0023). El PERFILES de aca abajo es el
// fallback documentado para cuando args.perfiles no viene (los scripts de
// Workflow no leen filesystem): coincide con la banda `directo` de
// config/rutas.yaml (D3 de 0023).
const PERFILES = Object.assign({
  planificador: { model: 'sonnet', effort: 'medium' },
  implementador: { model: 'sonnet', effort: 'medium' },
  verificador: { model: 'haiku', effort: 'low' },
  refutador: { model: 'haiku', effort: 'low' },
  sintesis: { model: 'opus', effort: 'medium' },
}, (args && args.perfiles) || {})
const perfil = t => {
  const p = Object.assign({}, PERFILES[t] || {})
  // RNF-06 de 0023: ningun subagente hereda el modelo de la sesion (fable, cuota aparte)
  if (!p.model || p.model === 'inherit' || p.model === 'fable') p.model = t === 'sintesis' ? 'opus' : (t === 'verificador' || t === 'refutador') ? 'haiku' : 'sonnet'
  return p
}
// Primera mitad de la ruta `exhaustivo` (RF-03 de specs/0021). Un workflow no
// puede pausar a esperar la aprobacion del operador (D2), por eso termina
// aca: el agente de la sesion muestra el plan, el operador aprueba, y recien
// entonces se corre ruta-exhaustivo-impl con ese plan en args.

const spec = args && args.spec
if (!spec) throw new Error('ruta-exhaustivo-plan: falta args.spec (id de la spec)')

// Tamano del panel (RF-04 de 0023): args.perfiles.panel lo trae
// `scripts/rutas perfiles --spec <id>` segun la banda; sin panel, se
// comporta como hoy (3 planificadores, 3 refutadores por plan).
const panel = (args && args.perfiles && args.perfiles.panel) || { planificadores: 3, refutadores_por_plan: 3 }

const ENFOQUES = [
  { key: 'mvp', texto: 'Minimo viable primero: el camino mas corto a que todos los CA pasen, sin nada que la spec no exija.' },
  { key: 'riesgo', texto: 'Riesgo primero: identifica lo que mas probablemente falle o pise otra cosa del repo, y ordena el plan para atacarlo antes.' },
  { key: 'ca', texto: 'CA primero: parti de cada CA de §6 y derivá los archivos desde ahi; nada que no sirva a un CA entra.' },
].slice(0, panel.planificadores)

// Lentes de refutacion, una lista fija; por plan se usan las primeras
// `refutadores_por_plan` (con 1 refutador la sintesis no promedia votos: el
// veredicto es ese, sin logica de desempate).
const LENTES = [
  'cobertura: ¿hay algun RF o CA de la spec que ningun grupo cubre?',
  'alcance: ¿algun grupo toca algo fuera de §5.1 o del §Alcance?',
  'paralelismo: ¿dos grupos marcados como independientes comparten un archivo?',
]

const PLAN = {
  type: 'object',
  properties: {
    enfoque: { type: 'string' },
    grupos: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          nombre: { type: 'string' },
          archivos: { type: 'array', items: { type: 'string' } },
          descripcion: { type: 'string' },
          ca_cubiertas: { type: 'array', items: { type: 'string' } },
          comparte_archivos: { type: 'boolean' },
        },
        required: ['nombre', 'archivos', 'descripcion', 'ca_cubiertas', 'comparte_archivos'],
      },
    },
    casos_borde: { type: 'array', items: { type: 'string' } },
    supuestos: { type: 'array', items: { type: 'string' } },
    diagrama: { type: 'string' },
  },
  required: ['enfoque', 'grupos', 'casos_borde', 'supuestos', 'diagrama'],
}

const VEREDICTO = {
  type: 'object',
  properties: {
    refutado: { type: 'boolean' },
    evidencia: { type: 'string' },
    notas: { type: 'array', items: { type: 'string' } },
  },
  required: ['refutado', 'evidencia'],
}

const contexto = `Spec activa: ${spec} (specs/${spec}-*.md). Lee AGENTS.md y lo que tu contrato de agente indica de la spec antes de actuar. Modo de trabajo: exhaustivo (templates/MODE.md.exhaustivo).`

// pipeline: cada plan pasa a refutacion apenas esta listo, sin esperar a los
// demas planificadores del panel.
const evaluados = await pipeline(
  ENFOQUES,
  e => agent(
    `${contexto}\nEnfoque obligatorio: ${e.texto}\nDevolve un plan de implementacion completo: grupos de archivos implementables en paralelo (marcando si comparten archivos entre si), que CA cubre cada grupo, casos borde y supuestos. Ademas, en la clave "diagrama" devolve un string con JSON IR sequence de archify (sin fence): participants con id, type, label y sublabel (que hace y donde vive); messages con id, from, to, label y variant (default, emphasis, return, dashed o security); alt, else y loop como segments anclados con from_msg y to_msg; sin y ni meta.output, que los completa scripts/diagrama --json, que describa el flujo de ESTE plan: que grupos tocan que archivos y en que orden se implementan y verifican.`,
    { label: `planificador:${e.key}`, phase: 'Planificar', agentType: 'planificador', ...perfil('planificador'), schema: PLAN },
  ),
  async (plan, e) => {
    if (!plan) return null
    const votos = await parallel(LENTES.slice(0, panel.refutadores_por_plan).map((lente, i) => () => agent(
      `${contexto}\nAfirmacion a refutar: "este plan cubre la spec ${spec} y es implementable en paralelo como esta".\nLente: ${lente}\nPlan:\n${JSON.stringify(plan, null, 2)}`,
      { label: `refutador:${e.key}:${i + 1}`, phase: 'Refutar', agentType: 'refutador', ...perfil('refutador'), schema: VEREDICTO },
    )))
    const v = votos.filter(Boolean)
    return { enfoque: e.key, plan, refutaciones: v.filter(x => x.refutado).length, veredictos: v }
  },
)

const validos = evaluados.filter(Boolean)
if (!validos.length) {
  log('ruta-exhaustivo-plan: ningun planificador devolvio plan')
  return { spec, pasa: false, plan: null, reparos: [], candidatos: [], ca_total: null, ca_pass: null, segunda_vuelta: null }
}
// Ranking en codigo (RNF-02): menos refutaciones gana; empate -> orden de ENFOQUES.
validos.sort((a, b) => a.refutaciones - b.refutaciones)
const ganador = validos[0]
log(`ruta-exhaustivo-plan: gana el enfoque '${ganador.enfoque}' con ${ganador.refutaciones} refutaciones`)

phase('Sintetizar')
const sintesis = await agent(
  `${contexto}\nSintetiza UN plan final a partir del ganador, incorporando lo mejor de los otros y resolviendo cada reparo que sobrevivio. No edites nada. Incluí la clave "diagrama" (un string con JSON IR sequence de archify (sin fence): participants con id, type, label y sublabel (que hace y donde vive); messages con id, from, to, label y variant (default, emphasis, return, dashed o security); alt, else y loop como segments anclados con from_msg y to_msg; sin y ni meta.output, que los completa scripts/diagrama --json) que describa el flujo del plan final: que grupos tocan que archivos y en que orden se implementan y verifican.\nGanador (${ganador.enfoque}):\n${JSON.stringify(ganador.plan, null, 2)}\nReparos sobre el ganador:\n${JSON.stringify(ganador.veredictos, null, 2)}\nOtros candidatos:\n${JSON.stringify(validos.slice(1).map(c => ({ enfoque: c.enfoque, plan: c.plan, refutaciones: c.refutaciones })), null, 2)}`,
  { label: 'planificador:sintesis', phase: 'Sintetizar', agentType: 'planificador', ...perfil('sintesis'), schema: PLAN },
)

return {
  spec,
  pasa: true,
  plan: sintesis || ganador.plan,
  reparos: ganador.veredictos.filter(v => v.refutado).map(v => v.evidencia),
  candidatos: validos.map(c => ({ enfoque: c.enfoque, refutaciones: c.refutaciones })),
  ca_total: null,
  ca_pass: null,
  segunda_vuelta: null,
}
