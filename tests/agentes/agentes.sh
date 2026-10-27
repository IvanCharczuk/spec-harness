#!/usr/bin/env bash
# CA-01, CA-03 a CA-08, CA-11 y CA-12 de
# spec 0086 (not in this snapshot)
#   bash tests/agentes/agentes.sh {generar|dry-run|cli|segunda-vuelta|ollama|guardas|lint|registro|prompt-sin-herramientas}
#   bash tests/agentes/agentes.sh preparar-juguete   (para CA-10: imprime la copia y no la borra)
#
# Cada subcomando imprime `[ok]` o `[x] <qué falló>` por aserción y sale con
# 0 o 1. Reentrante: verificadores y refutadores lo corren en paralelo, así
# que todo estado (copias, contadores del fake, registros, port file) vive
# bajo un `mktemp -d` propio que el trap borra; sobre el repo real sólo se
# lee (dry-run, generar --check, lint).
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FIX="$SRC/tests/fixtures/agentes"
SUB="${1:-}"
case "$SUB" in
  generar|dry-run|cli|segunda-vuelta|ollama|guardas|lint|registro|prompt-sin-herramientas|preparar-juguete) ;;
  *) echo "uso: tests/agentes/agentes.sh {generar|dry-run|cli|segunda-vuelta|ollama|guardas|lint|registro|prompt-sin-herramientas|preparar-juguete}" >&2; exit 2 ;;
esac

# Nada heredado puede apuntar a otra config ni a otro repo.
unset AGENTES_CONFIG FAKE_CODEX_MODO FAKE_CODEX_DIR FAKE_CODEX_ROOT GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE

FAKE_PID=""
if [ "$SUB" = "preparar-juguete" ]; then
  base="$(mktemp -d)" || exit 1
else
  base="$(mktemp -d)" || exit 1
  trap 'if [ -n "$FAKE_PID" ]; then kill "$FAKE_PID" 2>/dev/null || true; fi; rm -rf "$base"' EXIT
fi
base="$(cd "$base" && pwd -P)"

FALLAS=0
ok()  { printf '[ok] %s\n' "$1"; }
mal() { printf '[x] %s\n' "$1"; FALLAS=$((FALLAS + 1)); }
afirma() { # afirma <descripción> <comando...>
  local d="$1"; shift
  if "$@"; then ok "$d"; else mal "$d"; fi
}
fin() { [ "$FALLAS" -eq 0 ] || { echo "$FALLAS fallas" >&2; exit 1; }; exit 0; }

# correr <nombre> <comando...>: stdout y stderr a $base/<nombre>.{out,err},
# exit en $RC. Nunca por pipe ni por $(): un `| grep -q` con pipefail da
# falsos negativos y $() come los \n finales.
RC=0
correr() { local n="$1"; shift; RC=0; "$@" >"$base/$n.out" 2>"$base/$n.err" || RC=$?; }
en() { local d="$1"; shift; ( cd "$d" && "$@" ); }
rc_es() { [ "$RC" -eq "$1" ]; }
tiene() { grep -qF -- "$2" "$base/$1"; }       # tiene <archivo bajo $base> <texto>
no_tiene() { ! grep -qF -- "$2" "$base/$1"; }
vacio() { [ ! -s "$1" ]; }
cmd_trae() { [ -n "$2" ] && tiene "$1" "$2"; }   # cmd_trae <archivo bajo $base> <modelo>
pasa_es() { grep -qE "^RUTA=.* PASA=$2( |\$)" "$base/$1.out"; }

GITC=(-c user.name=Tester -c user.email=tester@localhost -c core.hooksPath=/dev/null -c commit.gpgsign=false)

# jsonl_es <archivo> <n_lineas> <expresión JS sobre r (la última línea)>
jsonl_es() {
  node -e '
    const fs = require("fs");
    const [f, n, expr] = process.argv.slice(1);
    let t = "";
    try { t = fs.readFileSync(f, "utf8"); } catch (e) { process.exit(1); }
    const ls = t.split("\n").filter((l) => l.trim() !== "");
    if (ls.length !== Number(n)) process.exit(1);
    const r = JSON.parse(ls[ls.length - 1]);
    process.exit(Function("r", "return (" + expr + ");")(r) ? 0 : 1);
  ' "$1" "$2" "$3"
}

sha_de() { node -e 'process.stdout.write(require("crypto").createHash("sha256").update(require("fs").readFileSync(process.argv[1])).digest("hex"))' "$1"; }

# armar_juguete <dir>: <dir>/repo es una copia del working tree (scripts,
# config, agentes, AGENTS.md y los workflows) más la spec 9086, con un
# commit propio; <dir>/bin/codex envuelve a fake-codex; <dir>/fake guarda
# lo que el fake grabe. El `../x` del caso traversal cae en <dir>/x.
armar_juguete() {
  local d="$1"
  mkdir -p "$d/repo/.claude" "$d/bin" "$d/fake"
  cp -Rp "$SRC/scripts" "$SRC/config" "$SRC/agentes" "$SRC/AGENTS.md" "$d/repo/"
  cp -Rp "$SRC/.claude/workflows" "$d/repo/.claude/"
  cp -Rp "$FIX/repo-juguete/." "$d/repo/"
  git -c init.defaultBranch=main -C "$d/repo" init -q
  git -C "$d/repo" add -A
  git -C "$d/repo" "${GITC[@]}" commit -q -m "juguete 9086"
  printf '#!/usr/bin/env bash\nexec bash "%s/fake-codex" "$@"\n' "$FIX" > "$d/bin/codex"
  chmod +x "$d/bin/codex"
}

# ruta_codex <dir> <modo> <nombre> <registro>
ruta_codex() {
  local d="$1" modo="$2" n="$3" reg="$4" root
  root="$(cd "$d/repo" && pwd -P)"
  correr "$n" env PATH="$d/bin:$PATH" FAKE_CODEX_MODO="$modo" FAKE_CODEX_DIR="$d/fake" FAKE_CODEX_ROOT="$root" \
    "$d/repo/scripts/ruta" directo 9086 --agent codex --registro "$reg"
}

# ruta_ollama <dir> <config> <nombre> <registro>
ruta_ollama() {
  local d="$1" cfg="$2" n="$3" reg="$4"
  correr "$n" env AGENTES_CONFIG="$cfg" "$d/repo/scripts/ruta" directo 9086 --agent ollama --registro "$reg"
}

ROLES="planificador implementador verificador refutador"
PROHIBIDAS="--dangerously bypass --yolo --force danger-full-access"

case "$SUB" in

# --- CA-01: roles neutros generan lo mismo ----------------------------------
generar)
  correr g1 en "$SRC" node scripts/agentes generar --check
  afirma "generar --check sale 0 en el repo real (rc=$RC)" rc_es 0
  correr g2 en "$SRC" node scripts/agentes generar --check
  afirma "segundo generar --check sale 0 (rc=$RC)" rc_es 0
  afirma "generar --check da el mismo stdout dos veces" cmp -s "$base/g1.out" "$base/g2.out"
  afirma "generar --check dice 'sin diferencias (4 roles)'" grep -qxF 'generar: sin diferencias (4 roles)' "$base/g1.out"
  afirma ".claude/agents sin cambios respecto de e242192" git -C "$SRC" diff --quiet e242192 -- .claude/agents
  for rol in $ROLES; do
    tail -n +7 "$SRC/.claude/agents/$rol.md" > "$base/cuerpo-$rol"
    afirma "agentes/roles/$rol.md es el cuerpo de .claude/agents/$rol.md" cmp -s "$base/cuerpo-$rol" "$SRC/agentes/roles/$rol.md"
  done

  c="$base/copia"
  mkdir -p "$c/scripts" "$c/config" "$c/agentes" "$c/.claude"
  cp -Rp "$SRC/scripts/agentes" "$SRC/scripts/lib" "$c/scripts/"
  cp -Rp "$SRC/config/agentes.yaml" "$c/config/"
  cp -Rp "$SRC/agentes/roles" "$c/agentes/"
  cp -Rp "$SRC/.claude/agents" "$c/.claude/"
  LINEA="línea agregada por tests/agentes/agentes.sh (0086)"
  printf '%s\n' "$LINEA" >> "$c/agentes/roles/verificador.md"

  correr c1 en "$c" node scripts/agentes generar --check
  cat "$base/c1.out" "$base/c1.err" > "$base/c1.all"
  afirma "con un cuerpo alterado, --check sale 1 (rc=$RC)" rc_es 1
  afirma "--check nombra 'generar: verificador difiere'" grep -qxF 'generar: verificador difiere' "$base/c1.all"
  n="$(grep -c 'difiere' "$base/c1.all" || true)"
  afirma "--check no nombra otro rol (líneas 'difiere': $n)" [ "$n" = "1" ]

  for rol in planificador implementador refutador; do
    chmod a-w "$c/.claude/agents/$rol.md"
    ls -i "$c/.claude/agents/$rol.md" | awk '{print $1}' > "$base/inodo-$rol"
  done
  correr c2 en "$c" node scripts/agentes generar
  cat "$base/c2.out" "$base/c2.err" > "$base/c2.all"
  afirma "generar sale 0 con los otros tres de sólo lectura (rc=$RC)" rc_es 0
  afirma "generar imprime 'generar: verificador escrito'" grep -qxF 'generar: verificador escrito' "$base/c2.all"
  n="$(grep -c 'escrito' "$base/c2.all" || true)"
  afirma "generar escribe sólo el que difiere (líneas 'escrito': $n)" [ "$n" = "1" ]
  for rol in planificador implementador refutador; do
    ls -i "$c/.claude/agents/$rol.md" | awk '{print $1}' > "$base/inodo2-$rol"
    afirma "generar no reemplazó .claude/agents/$rol.md" cmp -s "$base/inodo-$rol" "$base/inodo2-$rol"
    afirma ".claude/agents/$rol.md quedó igual" cmp -s "$c/.claude/agents/$rol.md" "$SRC/.claude/agents/$rol.md"
  done
  tail -n 1 "$c/.claude/agents/verificador.md" > "$base/ultima"
  printf '%s\n' "$LINEA" > "$base/ultima.esperada"
  afirma "el verificador generado termina con la línea agregada" cmp -s "$base/ultima" "$base/ultima.esperada"
  correr c3 en "$c" node scripts/agentes generar --check
  afirma "después de generar, --check sale 0 (rc=$RC)" rc_es 0
  correr c4 en "$c" node scripts/agentes generar
  cat "$base/c4.out" "$base/c4.err" > "$base/c4.all"
  afirma "un segundo generar sale 0 (rc=$RC)" rc_es 0
  afirma "un segundo generar no escribe nada" no_tiene c4.all 'escrito'
  fin ;;

# --- CA-03: --dry-run por agente --------------------------------------------
dry-run)
  REG="$SRC/sessions/rutas.jsonl"
  huella() { if [ -f "$1" ]; then cksum < "$1"; else echo ausente; fi; }
  h0="$(huella "$REG")"
  R="$SRC/scripts/ruta"

  correr d0 en "$SRC" "$R" directo 0028 --dry-run
  r0=$RC
  correr d1 en "$SRC" "$R" directo 0028 --agent claude --dry-run
  afirma "directo: sin --agent y con --agent claude salen 0 ($r0, $RC)" [ "$r0" -eq 0 -a "$RC" -eq 0 ]
  afirma "directo: --agent claude da el mismo stdout" cmp -s "$base/d0.out" "$base/d1.out"
  afirma "directo: --agent claude da el mismo stderr" cmp -s "$base/d0.err" "$base/d1.err"

  PLAN=tests/fixtures/ruta/ok-plan.output.json
  correr e0 en "$SRC" "$R" exhaustivo 0028 --fase impl --plan "$PLAN" --dry-run
  r0=$RC
  correr e1 en "$SRC" "$R" exhaustivo 0028 --fase impl --plan "$PLAN" --dry-run --agent claude
  afirma "exhaustivo: sin --agent y con --agent claude salen 0 ($r0, $RC)" [ "$r0" -eq 0 -a "$RC" -eq 0 ]
  afirma "exhaustivo: --agent claude da el mismo stdout" cmp -s "$base/e0.out" "$base/e1.out"
  afirma "exhaustivo: --agent claude da el mismo stderr" cmp -s "$base/e0.err" "$base/e1.err"

  correr prompt en "$SRC" node scripts/agentes prompt --rol implementador --spec 0028
  afirma "prompt --rol implementador --spec 0028 sale 0 (rc=$RC)" rc_es 0
  SHA="$(sha_de "$base/prompt.out")"
  # RF-06b (v2): ollama (tools: false) recibe el prompt con --sin-herramientas.
  correr prompt-sh en "$SRC" node scripts/agentes prompt --rol implementador --spec 0028 --sin-herramientas
  SHA_SH="$(sha_de "$base/prompt-sh.out")"

  for a in codex ollama; do
    correr "$a-1" en "$SRC" "$R" directo 0028 --agent "$a" --dry-run
    r1=$RC
    correr "$a-2" en "$SRC" "$R" directo 0028 --agent "$a" --dry-run
    afirma "$a: las dos corridas salen 0 ($r1, $RC)" [ "$r1" -eq 0 -a "$RC" -eq 0 ]
    afirma "$a: dos corridas dan stdout idéntico" cmp -s "$base/$a-1.out" "$base/$a-2.out"
    sed "s#$SRC#<REPO_ROOT>#g" "$base/$a-1.out" > "$base/$a.norm"
    afirma "$a: stdout igual a dry-run-$a.expected" cmp -s "$base/$a.norm" "$FIX/dry-run-$a.expected"
    sha_a="$SHA"; [ "$a" = ollama ] && sha_a="$SHA_SH"
    afirma "$a: PROMPT_SHA es el sha256 de scripts/agentes prompt" grep -qxF "PROMPT_SHA=$sha_a" "$base/$a-1.out"
    model="$(sed -n 's/^MODEL=//p' "$base/$a-1.out")"
    grep '^CMD=' "$base/$a-1.out" > "$base/$a.cmd" || true
    afirma "$a: CMD= trae el modelo de MODEL= ('$model')" cmd_trae "$a.cmd" "$model"
    for f in $PROHIBIDAS; do
      afirma "$a: CMD= sin $f" no_tiene "$a.cmd" "$f"
    done
  done

  h1="$(huella "$REG")"
  afirma "el registro no cambió" [ "$h0" = "$h1" ]
  fin ;;

# --- CA-04: corrida con la CLI falsa ----------------------------------------
cli)
  d="$base/c"
  armar_juguete "$d"
  ruta_codex "$d" ok r "$d/reg.jsonl"
  afirma "ruta --agent codex sale 0 (rc=$RC)" rc_es 0
  afirma "la salida dice PASA=true" pasa_es r true
  afirma "el registro tiene una línea con pasa, segunda_vuelta, agentes, tokens, workflow y notas" \
    jsonl_es "$d/reg.jsonl" 1 'r.pasa === true && r.segunda_vuelta === false && r.agentes === 1 && r.tokens === 0 && r.workflow === "ruta-directo.js" && /^agente=codex model=/.test(r.notas)'
  printf '%s\n' exec --model gpt-5-codex --sandbox workspace-write - > "$base/argv.esperado"
  afirma "argv-1 es 'exec --model gpt-5-codex --sandbox workspace-write -'" cmp -s "$base/argv.esperado" "$d/fake/argv-1"
  afirma "una sola invocación del agente" [ ! -e "$d/fake/argv-2" ]
  correr p9086 en "$d/repo" node scripts/agentes prompt --rol implementador --spec 9086
  afirma "stdin-1 es byte a byte el prompt del implementador para 9086" cmp -s "$base/p9086.out" "$d/fake/stdin-1"
  afirma "stdin-1 empieza con el cuerpo del rol implementador" \
    node -e 'const fs=require("fs");process.exit(fs.readFileSync(process.argv[1]).subarray(0,fs.statSync(process.argv[2]).size).equals(fs.readFileSync(process.argv[2]))?0:1)' "$d/fake/stdin-1" "$d/repo/agentes/roles/implementador.md"
  afirma "stdin-1 trae el bloque '## Contexto'" grep -qxF '## Contexto' "$d/fake/stdin-1"
  afirma "el fake escribió salida.txt" grep -qx hola "$d/repo/salida.txt"
  fin ;;

# --- CA-05: segunda vuelta --------------------------------------------------
segunda-vuelta)
  d="$base/una"
  armar_juguete "$d"
  ruta_codex "$d" falla-una-vez r1 "$d/reg.jsonl"
  afirma "falla-una-vez: sale 0 (rc=$RC)" rc_es 0
  afirma "falla-una-vez: PASA=true" pasa_es r1 true
  afirma "stdin-1 no trae 'Resultado de la vuelta anterior'" bash -c '! grep -qF "## Resultado de la vuelta anterior" "$1"' _ "$d/fake/stdin-1"
  afirma "stdin-2 trae '## Resultado de la vuelta anterior'" grep -qF '## Resultado de la vuelta anterior' "$d/fake/stdin-2"
  afirma "stdin-2 trae la salida de verify ('[FAIL] CA-01')" grep -qF '[FAIL] CA-01' "$d/fake/stdin-2"
  afirma "falla-una-vez: dos invocaciones, no tres" [ -e "$d/fake/argv-2" -a ! -e "$d/fake/argv-3" ]
  afirma "falla-una-vez: registro con pasa, segunda_vuelta y agentes 2" \
    jsonl_es "$d/reg.jsonl" 1 'r.pasa === true && r.segunda_vuelta === true && r.agentes === 2'

  d="$base/mal"
  armar_juguete "$d"
  ruta_codex "$d" mal r2 "$d/reg.jsonl"
  afirma "mal: sale 0 (se registró) (rc=$RC)" rc_es 0
  afirma "mal: PASA=false" pasa_es r2 false
  afirma "mal: exactamente dos invocaciones" [ -e "$d/fake/argv-2" -a ! -e "$d/fake/argv-3" ]
  afirma "mal: registro con pasa false" jsonl_es "$d/reg.jsonl" 1 'r.pasa === false && r.segunda_vuelta === true && r.agentes === 2'
  fin ;;

# --- CA-06: Ollama sin herramientas, con el fake HTTP ------------------------
ollama)
  node "$FIX/fake-ollama.js" "$base/port" "$base/requests.jsonl" "$base/modo" >/dev/null 2>"$base/fake.err" &
  FAKE_PID=$!
  for _ in $(seq 1 50); do [ -s "$base/port" ] && break; sleep 0.1; done
  if [ ! -s "$base/port" ]; then mal "fake-ollama no escribió el puerto"; fin; fi
  port="$(tr -d '\n' < "$base/port")"
  url="http://127.0.0.1:$port"
  sed "s#__PORT__#$port#" "$FIX/agentes-valida.yaml" > "$base/agentes.yaml"
  CFG="$base/agentes.yaml"
  modo() { printf '%s\n' "$1" > "$base/modo"; }
  node -e 'process.stdout.write(JSON.stringify({type:"object",required:["archivos","resumen"],properties:{archivos:{type:"array",items:{type:"object",required:["path","contenido"],properties:{path:{type:"string"},contenido:{type:"string"}}}},resumen:{type:"string"}}}))' > "$base/schema.json"

  modo ok
  d="$base/ok"; armar_juguete "$d"
  ruta_ollama "$d" "$CFG" ok "$d/reg.jsonl"
  afirma "ok: ruta --agent ollama sale 0 (rc=$RC)" rc_es 0
  afirma "ok: PASA=true" pasa_es ok true
  afirma "ok: escribió salida.txt" grep -qx hola "$d/repo/salida.txt"
  afirma "ok: registro con pasa y notas agente=ollama" jsonl_es "$d/reg.jsonl" 1 'r.pasa === true && /^agente=ollama model=/.test(r.notas)'
  correr p9086 en "$d/repo" node scripts/agentes prompt --rol implementador --spec 9086 --sin-herramientas
  afirma "el request trae format = schema, stream false, temperature 0 y el prompt de RF-06b" node -e '
    const fs = require("fs"), assert = require("assert");
    const [reqs, schema, prompt] = process.argv.slice(1);
    const l = fs.readFileSync(reqs, "utf8").split("\n").filter((x) => x.trim() !== "");
    if (l.length < 1) process.exit(1);
    const r = JSON.parse(l[0]);
    try { assert.deepStrictEqual(r.format, JSON.parse(fs.readFileSync(schema, "utf8"))); } catch (e) { process.exit(1); }
    const ok = r.stream === false && r.options && r.options.temperature === 0 && r.model === "qwen2.5-coder:7b"
      && Array.isArray(r.messages) && r.messages[0] && r.messages[0].role === "user"
      && r.messages[0].content === fs.readFileSync(prompt, "utf8");
    process.exit(ok ? 0 : 1);
  ' "$base/requests.jsonl" "$base/schema.json" "$base/p9086.out"

  for m in fuera traversal git; do
    case "$m" in fuera) bad="otro.txt" ;; traversal) bad="../x" ;; git) bad=".git/hooks/x" ;; esac
    modo "$m"
    d="$base/$m"; armar_juguete "$d"
    ruta_ollama "$d" "$CFG" "$m" "$d/reg.jsonl"
    afirma "$m: sale 3 (rc=$RC)" rc_es 3
    afirma "$m: nombra '$bad' por stderr" tiene "$m.err" "$bad"
    afirma "$m: no escribió salida.txt" [ ! -e "$d/repo/salida.txt" ]
    afirma "$m: no escribió ../x ni .git/hooks/x" [ ! -e "$d/x" -a ! -e "$d/repo/.git/hooks/x" ]
    afirma "$m: el registro quedó vacío" vacio "$d/reg.jsonl"
  done

  printf 'decí hola\n' > "$base/p.txt"
  modo ok
  correr pedir-ok env AGENTES_CONFIG="$CFG" node "$SRC/scripts/agentes" pedir --agente ollama --prompt-file "$base/p.txt" --schema "$base/schema.json"
  afirma "pedir con respuesta válida sale 0 (rc=$RC)" rc_es 0
  afirma "pedir imprime una línea {agente, model, respuesta, ms}" jsonl_es "$base/pedir-ok.out" 1 \
    'r.agente === "ollama" && typeof r.model === "string" && r.respuesta && Array.isArray(r.respuesta.archivos) && typeof r.ms === "number"'
  for m in sin-schema no-json; do
    modo "$m"
    correr "pedir-$m" env AGENTES_CONFIG="$CFG" node "$SRC/scripts/agentes" pedir --agente ollama --prompt-file "$base/p.txt" --schema "$base/schema.json"
    afirma "$m: pedir sale 4 (rc=$RC)" rc_es 4
    d="$base/$m"; armar_juguete "$d"
    ruta_ollama "$d" "$CFG" "ruta-$m" "$d/reg.jsonl"
    afirma "$m: ruta sale 3 (rc=$RC)" rc_es 3
    afirma "$m: no escribió salida.txt" [ ! -e "$d/repo/salida.txt" ]
    afirma "$m: el registro quedó vacío" vacio "$d/reg.jsonl"
  done

  correr sin-schema-flag env AGENTES_CONFIG="$CFG" node "$SRC/scripts/agentes" pedir --agente ollama --prompt-file "$base/p.txt"
  afirma "pedir sin --schema sale 2 (rc=$RC)" rc_es 2
  kill "$FAKE_PID" 2>/dev/null || true
  wait "$FAKE_PID" 2>/dev/null || true
  FAKE_PID=""
  correr muerto env AGENTES_CONFIG="$CFG" node "$SRC/scripts/agentes" pedir --agente ollama --url "$url" --prompt-file "$base/p.txt" --schema "$base/schema.json"
  afirma "pedir contra el puerto del fake muerto sale 3 (rc=$RC)" rc_es 3
  fin ;;

# --- CA-07: guardas ---------------------------------------------------------
guardas)
  R="$SRC/scripts/ruta"
  REGG="$base/reg.jsonl"
  # Un codex en el PATH que, si alguna guarda fallara en el repo real, sólo
  # graba y sale con 8 sin escribir (FAKE_CODEX_ROOT no es ningún toplevel).
  mkdir -p "$base/bin-real" "$base/fake-real"
  printf '#!/usr/bin/env bash\nexec env FAKE_CODEX_DIR="%s" FAKE_CODEX_ROOT="%s" bash "%s/fake-codex" "$@"\n' \
    "$base/fake-real" "$base/no-es-un-repo" "$FIX" > "$base/bin-real/codex"
  chmod +x "$base/bin-real/codex"
  PR="$base/bin-real:$PATH"

  correr sin-valor en "$SRC" env PATH="$PR" "$R" directo 0028 --registro "$REGG" --agent
  afirma "--agent sin valor sale 2 (rc=$RC)" rc_es 2
  afirma "--agent sin valor lo dice" tiene sin-valor.err '--agent requiere un valor'
  # Con --dry-run, la guarda de estado de 0028 (verified) no corre: el 2 sólo
  # puede venir de la validación del nombre.
  correr vacio en "$SRC" env PATH="$PR" "$R" directo 0028 --registro "$REGG" --agent '' --dry-run
  afirma "--agent vacío sale 2 (rc=$RC)" rc_es 2
  afirma "--agent vacío no cae en la guarda de estado" no_tiene vacio.err 'scripts/spec start'
  correr mayus en "$SRC" env PATH="$PR" "$R" directo 0028 --registro "$REGG" --agent CLAUDE --dry-run
  afirma "--agent CLAUDE sale 2 (rc=$RC)" rc_es 2
  correr grok en "$SRC" env PATH="$PR" "$R" directo 0028 --registro "$REGG" --agent grok
  afirma "--agent grok sale 2 (rc=$RC)" rc_es 2
  afirma "--agent grok nombra el agente desconocido" tiene grok.err "agente desconocido 'grok'"
  correr exh en "$SRC" env PATH="$PR" "$R" exhaustivo 0028 --agent codex --dry-run --registro "$REGG"
  afirma "exhaustivo --agent codex sale 2 (rc=$RC)" rc_es 2
  afirma "exhaustivo --agent codex dice 'sólo con --agent claude'" tiene exh.err 'sólo con --agent claude'
  correr exh9999 en "$SRC" env PATH="$PR" "$R" exhaustivo 9999 --agent codex --registro "$REGG"
  afirma "exhaustivo 9999 --agent codex sale 2 (rc=$RC)" rc_es 2
  afirma "exhaustivo 9999 --agent codex: el mensaje de exhaustivo va antes que el de spec inexistente" tiene exh9999.err 'sólo con --agent claude'
  correr s9999 en "$SRC" env PATH="$PR" "$R" directo 9999 --agent codex --registro "$REGG"
  afirma "directo 9999 --agent codex sale 2 (rc=$RC)" rc_es 2
  correr verif en "$SRC" env PATH="$PR" "$R" directo 0028 --agent codex --registro "$REGG"
  afirma "directo 0028 --agent codex (verified) sale 2 (rc=$RC)" rc_es 2
  afirma "directo 0028 --agent codex sugiere scripts/spec start" tiene verif.err 'scripts/spec start'
  afirma "en el repo real ningún codex llegó a correr" [ ! -e "$base/fake-real/argv-1" ]

  d="$base/roto"; armar_juguete "$d"
  correr roto env PATH="$d/bin:$PATH" AGENTES_CONFIG="$FIX/agentes-roto.yaml" "$d/repo/scripts/ruta" directo 9086 --agent codex --registro "$REGG"
  afirma "binario ausente sale 2 (rc=$RC)" rc_es 2
  afirma "binario ausente nombra codex-inexistente-0086" tiene roto.err 'codex-inexistente-0086'
  afirma "binario ausente dice 'por usuario'" tiene roto.err 'por usuario'

  port="$(node -e 'const s=require("net").createServer();s.listen(0,"127.0.0.1",()=>{const p=s.address().port;s.close(()=>process.stdout.write(String(p)))})')"
  sed "s#__PORT__#$port#" "$FIX/agentes-valida.yaml" > "$base/cerrado.yaml"
  d="$base/cerrado"; armar_juguete "$d"
  ruta_ollama "$d" "$base/cerrado.yaml" cerrado "$REGG"
  afirma "ollama en un puerto cerrado sale 2 (rc=$RC)" rc_es 2
  afirma "ollama en un puerto cerrado nombra la url" tiene cerrado.err "http://127.0.0.1:$port"
  afirma "ollama en un puerto cerrado no escribió salida.txt" [ ! -e "$d/repo/salida.txt" ]

  d="$base/commitea"; armar_juguete "$d"
  ruta_codex "$d" commitea commitea "$REGG"
  afirma "un fake que commitea sale 3 (rc=$RC)" rc_es 3
  afirma "un fake que commitea: lo dice ('commiteó')" tiene commitea.err 'commiteó'
  cuenta="$(git -C "$d/repo" rev-list --count HEAD)"
  afirma "el commit del agente queda, no se revierte (commits: $cuenta)" [ "$cuenta" = "2" ]

  afirma "en ningún caso de error se escribió el registro" vacio "$REGG"
  fin ;;

# --- CA-08: lint de permisos ------------------------------------------------
lint)
  correr real en "$SRC" node scripts/agentes --lint
  afirma "--lint con la config real sale 0 (rc=$RC)" rc_es 0
  correr valida en "$SRC" env AGENTES_CONFIG="$FIX/agentes-valida.yaml" node scripts/agentes --lint
  afirma "--lint con agentes-valida.yaml sale 0 (rc=$RC)" rc_es 0
  correr prohibida en "$SRC" env AGENTES_CONFIG="$FIX/agentes-flag-prohibida.yaml" node scripts/agentes --lint
  afirma "--lint con agentes-flag-prohibida.yaml sale 2 (rc=$RC)" rc_es 2
  cat "$base/prohibida.out" "$base/prohibida.err" > "$base/prohibida.all"
  grep '^\[FAIL\] agentes:' "$base/prohibida.all" > "$base/fails" || true
  n="$(wc -l < "$base/fails" | tr -d ' ')"
  afirma "exactamente dos líneas '[FAIL] agentes:' (hay $n)" [ "$n" = "2" ]
  afirma "una nombra codex y --yolo" grep -qE '^\[FAIL\] agentes: codex: .*--yolo' "$base/fails"
  afirma "otra nombra libre y danger-full-access" grep -qE '^\[FAIL\] agentes: libre: .*danger-full-access' "$base/fails"
  fin ;;

# --- CA-11: el costo estimado no se contamina -------------------------------
registro)
  REGR="$base/reg.jsonl"
  # fila <run_id> <tokens> <notas>: una corrida de ruta-directo.js en banda directo.
  fila() {
    node -e '
      const [run_id, tokens, notas] = process.argv.slice(1);
      process.stdout.write(JSON.stringify({
        run_id, logged_at: "2026-10-27T00:00:00Z", spec_id: "9001", spec_version: 1,
        workflow: "ruta-directo.js", modo: "directo", agentes: 4, agentes_error: 0,
        tokens: Number(tokens), duracion_ms: 60000, tool_uses: 10, pasa: true,
        ca_total: 1, ca_pass: 1, segunda_vuelta: false, notas, perfiles: { banda: "directo" },
      }) + "\n");
    ' "$1" "$2" "$3" >> "$REGR"
  }
  perfiles() { correr "$1" en "$SRC" scripts/rutas perfiles --spec tests/fixtures/spec/valid-approved.md --registro "$REGR"; }

  fila base-1 100000 "headless scripts/ruta"
  fila base-2 120000 "headless scripts/ruta"
  fila base-3 140000 "headless scripts/ruta"
  perfiles p0
  afirma "perfiles con el registro base sale 0 (rc=$RC)" rc_es 0
  afirma "estimado base: tokens 120000, corridas_base 3" jsonl_es "$base/p0.out" 1 \
    'r.banda === "directo" && r.estimado.tokens === 120000 && r.estimado.corridas_base === 3'

  fila ollama-1 0 "agente=ollama model=x; headless scripts/ruta"
  fila ollama-2 0 "agente=ollama model=x; headless scripts/ruta"
  afirma "sin el filtro la mediana bajaría a 100000 (el caso no pasa en el vacío)" node -e '
    const fs = require("fs");
    const t = fs.readFileSync(process.argv[1], "utf8").split("\n").filter((l) => l.trim()).map((l) => JSON.parse(l))
      .filter((r) => r.workflow === "ruta-directo.js" && r.perfiles && r.perfiles.banda === "directo").map((r) => r.tokens).sort((a, b) => a - b);
    const n = t.length, m = n % 2 ? t[(n - 1) / 2] : Math.round((t[n / 2 - 1] + t[n / 2]) / 2);
    process.exit(n === 5 && m === 100000 ? 0 : 1);
  ' "$REGR"
  perfiles p1
  afirma "perfiles con filas agente=ollama sale 0 (rc=$RC)" rc_es 0
  afirma "las filas agente=ollama no cambian la salida de perfiles" cmp -s "$base/p0.out" "$base/p1.out"

  fila claude-1 200000 "agente=claude model=y; headless scripts/ruta"
  perfiles p2
  afirma "perfiles con una fila agente=claude sale 0 (rc=$RC)" rc_es 0
  afirma "la fila agente=claude sí cuenta: tokens 130000, corridas_base 4" jsonl_es "$base/p2.out" 1 \
    'r.estimado.tokens === 130000 && r.estimado.corridas_base === 4'
  afirma "las claves de perfiles quedan en el mismo orden" node -e '
    const fs = require("fs");
    const a = JSON.parse(fs.readFileSync(process.argv[1], "utf8")), b = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
    const k = (o) => JSON.stringify([Object.keys(o), Object.keys(o.estimado)]);
    const want = JSON.stringify([["banda","score","rule","panel","planificador","implementador","verificador","refutador","sintesis","estimado"],["agentes","tokens","corridas_base"]]);
    process.exit(k(a) === k(b) && k(a) === want ? 0 : 1);
  ' "$base/p0.out" "$base/p2.out"
  fin ;;

# --- CA-12: prompt para agentes sin herramientas (RF-06b, v2) ---------------
prompt-sin-herramientas)
  J=tests/fixtures/agentes/repo-juguete/specs/9086-juguete.md
  correr base9086 en "$SRC" node scripts/agentes prompt --rol implementador --spec "$J"
  afirma "sin la flag sale 0 (rc=$RC)" rc_es 0
  correr sh9086 en "$SRC" node scripts/agentes prompt --rol implementador --spec "$J" --sin-herramientas
  afirma "con --sin-herramientas sale 0 (rc=$RC)" rc_es 0
  printf '\n## Archivos permitidos (§5.1)\n\n- `salida.txt`\n\n## Criterios a cumplir\n\n- CA-01: `grep -qx hola salida.txt`\n' > "$base/cola"
  cat "$base/base9086.out" "$base/cola" > "$base/esperado9086"
  afirma "con la flag = prompt de RF-06 + archivos de §5.1 + cmd de los CA, byte a byte" cmp -s "$base/esperado9086" "$base/sh9086.out"
  for t in 'status: implementing' 'id: "9086"' '## 6. Criterios' '## 1. Objetivo' 'Ninguna.'; do
    afirma "no trae el resto de la spec ('$t')" no_tiene sh9086.out "$t"
  done

  printf 'salida de verify\n' > "$base/extra"
  correr ex9086 en "$SRC" node scripts/agentes prompt --rol implementador --spec "$J" --sin-herramientas --extra "$base/extra"
  afirma "con --extra sale 0 (rc=$RC)" rc_es 0
  printf '\n## Resultado de la vuelta anterior\n\nsalida de verify\n' > "$base/cola-extra"
  cat "$base/esperado9086" "$base/cola-extra" > "$base/esperado-extra"
  afirma "--extra va después de Criterios a cumplir" cmp -s "$base/esperado-extra" "$base/ex9086.out"

  correr sh0086 en "$SRC" node scripts/agentes prompt --rol implementador --spec 0086 --sin-herramientas
  afirma "sobre la propia 0086 sale 0 (rc=$RC)" rc_es 0
  afirma "un cmd multilínea va en un bloque de código bajo su id" node -e '
    const t = require("fs").readFileSync(process.argv[1], "utf8");
    const i = t.indexOf("\n- CA-02:\n");
    process.exit(i >= 0 && /^- CA-02:\n\n  ```\n[\s\S]*scripts\/verify 0023 --ca CA-01[\s\S]*?\n  ```\n/m.test(t.slice(i + 1)) ? 0 : 1);
  ' "$base/sh0086.out"
  afirma "un CA manual (CA-10) no va" no_tiene sh0086.out "CA-10"
  afirma "las entradas indentadas de §5.1 no van (fake-codex)" no_tiene sh0086.out '`fake-codex`'
  afirma "las no indentadas sí (scripts/agentes)" tiene sh0086.out '- `scripts/agentes`'

  correr p0028 en "$SRC" node scripts/agentes prompt --rol implementador --spec 0028
  afirma "sin la flag el prompt de 0028 sigue siendo el de v1" [ "$(sha_de "$base/p0028.out")" = fed182176e6d501f3fd1426fc5fb07e6466378d7d38accc41794ccf02b817ac3 ]
  correr s0028 en "$SRC" node scripts/agentes prompt --rol implementador --spec 0028 --sin-herramientas
  correr dro en "$SRC" scripts/ruta directo 0028 --agent ollama --dry-run
  afirma "dry-run de ollama sale 0 (rc=$RC)" rc_es 0
  afirma "PROMPT_SHA de ollama = sha del prompt con --sin-herramientas" tiene dro.out "PROMPT_SHA=$(sha_de "$base/s0028.out")"
  correr drc en "$SRC" scripts/ruta directo 0028 --agent codex --dry-run
  afirma "PROMPT_SHA de codex no cambia" tiene drc.out "PROMPT_SHA=fed182176e6d501f3fd1426fc5fb07e6466378d7d38accc41794ccf02b817ac3"
  fin ;;

# --- CA-10 (manual): copia del juguete para correr contra Ollama real --------
preparar-juguete)
  armar_juguete "$base"
  echo "siguiente: $base/repo/scripts/ruta directo 9086 --agent ollama --registro $base/repo/registro.jsonl" >&2
  printf '%s\n' "$base/repo" ;;
esac
