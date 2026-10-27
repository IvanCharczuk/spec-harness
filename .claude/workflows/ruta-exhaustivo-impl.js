export const meta = {
  name: 'ruta-exhaustivo-impl',
  description: 'Ruta agentica del modo exhaustivo, segunda mitad: implementa el plan aprobado por grupos, verifica CA por CA en paralelo y refuta cada PASS (RF-03 de 0021)',
  whenToUse: 'Despues de que el operador aprobo el plan de ruta-exhaustivo-plan. args: { spec: "<id>", plan: <plan aprobado> }',
  phases: [
    { title: 'Implementar', detail: 'un implementador por grupo del plan' },
    { title: 'Verificar', detail: 'un verificador por CA, en paralelo' },
    { title: 'Refutar', detail: 'un refutador por CA que paso' },
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
// Segunda mitad de la ruta `exhaustivo` (RF-03 de specs/0021). Recibe el plan
// YA APROBADO por el operador (D2). `isolation: 'worktree'` solo para grupos
// que declaran compartir archivos con otro: es caro y el harness lo limpia
// si no hubo cambios.

const spec = args && args.spec
const plan = args && args.plan
if (!spec) throw new Error('ruta-exhaustivo-impl: falta args.spec')
if (!plan || !Array.isArray(plan.grupos) || !plan.grupos.length) throw new Error('ruta-exhaustivo-impl: falta args.plan.grupos (plan aprobado)')

const contexto = `Spec activa: ${spec} (specs/${spec}-*.md). Lee AGENTS.md y lo que tu contrato de agente indica de la spec antes de actuar. Modo de trabajo: exhaustivo (templates/MODE.md.exhaustivo).`

const REPORTE = {
  type: 'object',
  properties: {
    archivos_tocados: { type: 'array', items: { type: 'string' } },
    verificado: { type: 'string' },
    bloqueos: { type: 'array', items: { type: 'string' } },
  },
  required: ['archivos_tocados', 'verificado'],
}

const CA_RESULTADO = {
  type: 'object',
  properties: {
    id: { type: 'string' },
    estado: { type: 'string', enum: ['PASS', 'FAIL', 'MANUAL'] },
    detalle: { type: 'string' },
  },
  required: ['id', 'estado'],
}

const VEREDICTO = {
  type: 'object',
  properties: {
    clase: { type: 'string', enum: ['bug', 'diseno_ca', 'sin_evidencia'] },
    evidencia: { type: 'string' },
    comando: { type: 'string' },
    salida: { type: 'string' },
  },
  required: ['clase', 'evidencia'],
}

// derivar:inicio
// RF-02 de spec 0033 (not in this snapshot):
// `refutado` no lo decide el refutador, lo deriva el workflow. Funcion pura
// (sin agent/log/etc del harness) para que el CA-02 la pruebe extrayendola
// del archivo, sin correr agentes.
function derivarVeredicto(ca, v) {
  const evidencia = (v && v.evidencia) || ''
  const comando = (v && v.comando) || ''
  const salida = (v && v.salida) || ''
  let clase = (v && v.clase) || 'sin_evidencia'
  // 'bug' sin comando y salida propios se degrada a 'sin_evidencia': no hay
  // evidencia reproducible de que el check: falle.
  if (clase === 'bug' && !(comando && salida)) clase = 'sin_evidencia'
  const refutado = clase === 'bug' && Boolean(comando) && Boolean(salida)
  return { ca, refutado, clase_refutador: clase, evidencia_refutador: evidencia || 'refutador sin resultado' }
}
// derivar:fin

phase('Implementar')
// Barrera justificada: la verificacion por CA necesita TODOS los grupos
// implementados, porque un CA puede depender de archivos de varios grupos.
const reportes = await parallel(plan.grupos.map((g, i) => () => agent(
  `${contexto}\nImplementa SOLO este grupo del plan aprobado:\n${JSON.stringify(g, null, 2)}\nCasos borde del plan: ${JSON.stringify(plan.casos_borde || [])}\nSupuestos aprobados: ${JSON.stringify(plan.supuestos || [])}\nNo toques archivos de otros grupos. No commitees.`,
  {
    label: `implementador:${g.nombre || i + 1}`,
    phase: 'Implementar',
    agentType: 'implementador', ...perfil('implementador'),
    schema: REPORTE,
    ...(g.comparte_archivos ? { isolation: 'worktree' } : {}),
  },
)))

// Lista de CA: union de las que el plan declara cubrir, en orden estable.
const cas = Array.from(new Set(plan.grupos.flatMap(g => g.ca_cubiertas || []))).sort()
if (!cas.length) log('ruta-exhaustivo-impl: el plan no declara CA cubiertas; se verifica la spec completa')

phase('Verificar')
// pipeline: cada CA que pasa va al refutador apenas termina, sin esperar a las otras.
const resultados = await pipeline(
  cas.length ? cas : ['TODAS'],
  ca => agent(
    ca === 'TODAS'
      ? `${contexto}\nCorre scripts/verify ${spec} completo y devolve el peor estado global como un solo resultado con id "TODAS".`
      : `${contexto}\nVerifica solo ${ca}: corre scripts/verify ${spec} --ca ${ca} y devolve esa linea (nunca copies el check: a mano; RF-04 de 0036).`,
    { label: `verificador:${ca}`, phase: 'Verificar', agentType: 'verificador', ...perfil('verificador'), schema: CA_RESULTADO },
  ),
  async (r, ca) => {
    if (!r) return { id: ca, estado: 'FAIL', detalle: 'verificador sin resultado' }
    if (r.estado !== 'PASS') return { ...r, refutado: null, clase_refutador: null }
    const v = await agent(
      `${contexto}\nAfirmacion a refutar: "${ca} pasa de verdad, no por casualidad estructural". Evidencia del verificador: ${r.detalle || '(sin detalle)'}. Volve a correr scripts/verify ${spec} --ca ${ca} y clasifica tu hallazgo (bug, diseno_ca o sin_evidencia); si es bug, incluyendo el comando que corriste y su salida.`,
      { label: `refutador:${ca}`, phase: 'Refutar', agentType: 'refutador', ...perfil('refutador'), schema: VEREDICTO },
    )
    // Sin veredicto (agente caido) no es "no refutado": queda null, como
    // antes de 0033, y `pasa` da false.
    if (!v) return { ...r, refutado: null, clase_refutador: null, evidencia_refutador: 'refutador sin resultado' }
    const derivado = derivarVeredicto(ca, v)
    return { ...r, refutado: derivado.refutado, clase_refutador: derivado.clase_refutador, evidencia_refutador: derivado.evidencia_refutador }
  },
)

const ca = resultados.filter(Boolean)
// RF-03: notas de diseno, una por cada refutacion de clase diseno_ca, en
// orden de CA (mismo orden que `ca`).
const notas_diseno = ca
  .filter(c => c.clase_refutador === 'diseno_ca')
  .map(c => ({ ca: c.id, evidencia: c.evidencia_refutador }))
const pasa = ca.length > 0 && ca.every(c => c.estado === 'MANUAL' || (c.estado === 'PASS' && c.refutado === false))
log(`ruta-exhaustivo-impl: ${ca.filter(c => c.estado === 'PASS' && c.refutado === false).length}/${ca.length} CA pasan y sobreviven refutacion`)

return {
  spec, grupos: reportes.filter(Boolean), ca, pasa,
  ca_total: ca.length,
  ca_pass: ca.filter(c => c.estado === 'PASS' && c.refutado === false).length,
  notas_diseno,
  segunda_vuelta: null,
}
