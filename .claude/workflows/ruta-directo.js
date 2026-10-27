export const meta = {
  name: 'ruta-directo',
  description: 'Ruta agentica del modo directo: implementador -> verificador, con una segunda vuelta si algun CA falla (RF-02 de 0021)',
  whenToUse: 'Cuando scripts/rmaestro imprimio MODO=directo. args: { spec: "<id>" }',
  phases: [
    { title: 'Implementar', detail: 'un implementador sobre toda la spec' },
    { title: 'Verificar', detail: 'desglose por CA; segunda vuelta si hay FAIL' },
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
// Ruta `directo` (RF-02 de specs/0021). Maximo 4 agentes. El control de
// flujo es codigo, no un agente (RNF-02): el script decide si hay segunda
// vuelta mirando `pasa`, nunca preguntandole a un modelo.

const spec = args && args.spec
if (!spec) throw new Error('ruta-directo: falta args.spec (id de la spec)')

const VERIFICACION = {
  type: 'object',
  properties: {
    ca: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          id: { type: 'string' },
          estado: { type: 'string', enum: ['PASS', 'FAIL', 'MANUAL'] },
          detalle: { type: 'string' },
        },
        required: ['id', 'estado'],
      },
    },
    lint_ok: { type: 'boolean' },
    doctor_ok: { type: 'boolean' },
    pasa: { type: 'boolean' },
  },
  required: ['ca', 'lint_ok', 'doctor_ok', 'pasa'],
}

const contexto = [
  `Spec activa: ${spec} (specs/${spec}-*.md). Lee AGENTS.md y lo que tu contrato de agente indica de la spec antes de actuar.`,
  'Modo de trabajo: directo (templates/MODE.md.directo).',
].join('\n')

phase('Implementar')
const impl1 = await agent(
  `${contexto}\nImplementa la spec completa dentro de su §Alcance y §5.1. No commitees.`,
  { label: 'implementador:1', phase: 'Implementar', agentType: 'implementador', ...perfil('implementador') },
)

phase('Verificar')
const promptVerificar = `${contexto}\nCorre scripts/spec lint ${spec}, scripts/verify ${spec} y bash scripts/doctor. Devolve el desglose por CA. \`pasa\` es true solo si ningun CA ejecutable esta en FAIL y lint y doctor estan en verde.`
let ver = await agent(promptVerificar, {
  label: 'verificador:1', phase: 'Verificar', agentType: 'verificador', ...perfil('verificador'), schema: VERIFICACION,
})

// RF-02: la segunda vuelta la dispara un CA en FAIL, no lint/doctor (un
// doctor en rojo por causas ajenas a la spec no justifica reimplementar).
const fallidos = ver ? ver.ca.filter(c => c.estado === 'FAIL') : []
if (fallidos.length) {
  log(`ruta-directo: ${fallidos.length} CA en FAIL, segunda vuelta del implementador`)
  await agent(
    `${contexto}\nSegunda vuelta. Estos CA estan en FAIL, con su detalle:\n${JSON.stringify(fallidos, null, 2)}\nlint_ok=${ver.lint_ok} doctor_ok=${ver.doctor_ok}\nCorregi solo lo necesario para que pasen, dentro del §Alcance. No commitees.`,
    { label: 'implementador:2', phase: 'Implementar', agentType: 'implementador', ...perfil('implementador') },
  )
  ver = await agent(promptVerificar, {
    label: 'verificador:2', phase: 'Verificar', agentType: 'verificador', ...perfil('verificador'), schema: VERIFICACION,
  })
}

if (!ver) {
  log('ruta-directo: el verificador no devolvio resultado (agente saltado o caido)')
  return { spec, ca: [], pasa: false, implementacion: impl1, ca_total: null, ca_pass: null, segunda_vuelta: fallidos.length > 0 }
}

return {
  spec, ca: ver.ca, lint_ok: ver.lint_ok, doctor_ok: ver.doctor_ok, pasa: ver.pasa, implementacion: impl1,
  ca_total: ver.ca.length,
  ca_pass: ver.ca.filter(c => c.estado === 'PASS').length,
  segunda_vuelta: fallidos.length > 0,
}
