#!/usr/bin/env bash
# CA-01 a CA-07 de spec 0089 (not in this snapshot)
#   bash tests/agentes/refutar.sh {confirmado|derivacion|allowlist|caido|ruta|guardas|sin-cambios}
#
# Cada subcomando imprime `[ok]` o `[x] <qué falló>` por aserción y sale con
# 0 o 1. Reentrante: todo estado (copias, fakes, registros, canarios) vive
# bajo un `mktemp -d` propio que el trap borra. Los comandos del modelo se
# corren SIEMPRE desde la copia ($d/repo/scripts/agentes): la raíz de
# `refutar` es la del script, así que un canario nunca cae en el repo real.
#
# REFUTAR_SCRIPTS=<dir> (sólo para ver el rojo): copia esos scripts/ en vez
# de los del working tree, p. ej. los de `git archive d8dc6f3 scripts`.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FIX="$SRC/tests/fixtures/refutar"
FIX_AG="$SRC/tests/fixtures/agentes"
FIX_RUTA="$SRC/tests/fixtures/ruta"
SCRIPTS_SRC="${REFUTAR_SCRIPTS:-$SRC/scripts}"
SUB="${1:-}"
case "$SUB" in
  confirmado|derivacion|allowlist|caido|ruta|guardas|sin-cambios) ;;
  *) echo "uso: tests/agentes/refutar.sh {confirmado|derivacion|allowlist|caido|ruta|guardas|sin-cambios}" >&2; exit 2 ;;
esac

unset AGENTES_CONFIG AGENTES_REFUTAR_TOPE_MS FAKE_CLAUDE_CASE GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE

PIDS=()
base="$(mktemp -d)" || exit 1
trap 'for p in "${PIDS[@]:-}"; do [ -n "$p" ] && kill "$p" 2>/dev/null || true; done; rm -rf "$base"' EXIT
base="$(cd "$base" && pwd -P)"

FALLAS=0
ok()  { printf '[ok] %s\n' "$1"; }
mal() { printf '[x] %s\n' "$1"; FALLAS=$((FALLAS + 1)); }
afirma() { local d="$1"; shift; if "$@"; then ok "$d"; else mal "$d"; fi; }
fin() { [ "$FALLAS" -eq 0 ] || { echo "$FALLAS fallas" >&2; exit 1; }; exit 0; }

RC=0
correr() { local n="$1"; shift; RC=0; "$@" >"$base/$n.out" 2>"$base/$n.err" || RC=$?; }
en() { local d="$1"; shift; ( cd "$d" && "$@" ); }
rc_es() { [ "$RC" -eq "$1" ]; }
tiene() { grep -qF -- "$2" "$base/$1"; }
no_tiene() { ! grep -qF -- "$2" "$base/$1"; }
pasa_es() { grep -qE "^RUTA=.* PASA=$2( |\$)" "$base/$1.out"; }
lineas_fake() { if [ -f "$1" ]; then grep -c . "$1" || true; else echo 0; fi; }

GITC=(-c user.name=Tester -c user.email=tester@localhost -c core.hooksPath=/dev/null -c commit.gpgsign=false)

# js <archivo> <expresión sobre j>: j es la ÚNICA línea JSON del archivo.
js() {
  node -e '
    const fs = require("fs");
    const [f, expr] = process.argv.slice(1);
    let j;
    try {
      const ls = fs.readFileSync(f, "utf8").split("\n").filter((l) => l.trim() !== "");
      if (ls.length !== 1) process.exit(1);
      j = JSON.parse(ls[0]);
    } catch (e) { process.exit(1); }
    process.exit(Function("j", "return (" + expr + ");")(j) ? 0 : 1);
  ' "$1" "$2"
}

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

# armar_copia <dir>: <dir>/repo es una copia de scripts, config, agentes,
# AGENTS.md y los workflows más el juguete 9089, con un commit propio.
armar_copia() {
  local d="$1"
  mkdir -p "$d/repo/.claude"
  cp -Rp "$SCRIPTS_SRC" "$d/repo/scripts"
  cp -Rp "$SRC/config" "$SRC/agentes" "$SRC/AGENTS.md" "$d/repo/"
  cp -Rp "$SRC/.claude/workflows" "$d/repo/.claude/"
  cp -Rp "$FIX/repo-juguete/." "$d/repo/"
  git -c init.defaultBranch=main -C "$d/repo" init -q
  git -C "$d/repo" add -A
  git -C "$d/repo" "${GITC[@]}" commit -q -m "juguete 9089"
}

# levantar_fake <script> <dir> <arg3>: arranca un fake de Ollama y deja su
# puerto en FAKE_PORT.
FAKE_PORT=""
levantar_fake() {
  local js="$1" dir="$2" a3="$3"
  mkdir -p "$dir"
  node "$js" "$dir/port" "$dir/requests.jsonl" "$a3" >/dev/null 2>"$dir/fake.err" &
  PIDS+=("$!")
  for _ in $(seq 1 50); do [ -s "$dir/port" ] && break; sleep 0.1; done
  [ -s "$dir/port" ] || { mal "el fake $js no escribió el puerto"; fin; }
  FAKE_PORT="$(tr -d '\n' < "$dir/port")"
}

puerto_muerto() {
  node -e 'const s=require("net").createServer();s.listen(0,"127.0.0.1",()=>{const p=s.address().port;s.close(()=>process.stdout.write(String(p)))})'
}

# config <salida> <puerto ollama> [<puerto ollama-refutador>]
config() {
  sed "s#__PORT__#$2#" "$FIX_AG/agentes-valida.yaml" > "$1"
  if [ -n "${3:-}" ]; then
    printf '  ollama-refutador:\n    url: "http://127.0.0.1:%s"\n    model: "qwen2.5-coder:7b"\n    tools: false\n' "$3" >> "$1"
  fi
}

# Fake del refutador + copia + config, para los subcomandos de `refutar` solo.
preparar_refutar() {
  RESP="$base/resp.json"
  : > "$RESP"
  levantar_fake "$FIX/fake-ollama-archivo.js" "$base/fake" "$RESP"
  REQS="$base/fake/requests.jsonl"
  config "$base/agentes.yaml" "$FAKE_PORT"
  CFG="$base/agentes.yaml"
  D="$base/c"; armar_copia "$D"; R="$D/repo"
}
resp() { cp "$FIX/respuestas/$1.json" "$RESP"; }
resp_json() { printf '%s\n' "$1" > "$RESP"; }
# refutar <nombre> <CA> [VAR=valor...]
refutar() {
  local n="$1" ca="$2"; shift 2
  correr "$n" en "$R" env AGENTES_CONFIG="$CFG" "$@" node scripts/agentes refutar --spec 9089 --ca "$ca" --agente ollama
}

case "$SUB" in

# --- CA-01: refutación confirmada --------------------------------------------
confirmado)
  preparar_refutar
  for k in exit contiene no-contiene; do
    resp "confirmado-$k"
    refutar "c-$k" CA-01
    afirma "$k: refutar sale 0 (rc=$RC)" rc_es 0
    afirma "$k: refutado true, clase bug, no escalado" js "$base/c-$k.out" 'j.refutado === true && j.clase === "bug" && j.escalado === false'
    afirma "$k: exit 1 y salida real '0' (grep -c sin hola)" js "$base/c-$k.out" 'j.exit === 1 && /^0\s*$/.test(j.salida)'
    afirma "$k: la salida no es la que inventó el modelo" no_tiene "c-$k.out" "inventado"
    afirma "$k: trae ca, comando, espera, contradice y ms" js "$base/c-$k.out" 'j.ca === "CA-01" && Array.isArray(j.comando) && j.espera && typeof j.contradice === "string" && typeof j.ms === "number" && j.agente === "ollama" && j.model === "qwen2.5-coder:7b"'
  done
  afirma "un request por caso al fake (3)" [ "$(lineas_fake "$REQS")" = "3" ]
  afirma "el prompt trae el bloque del CA-01 y la allowlist" node -e '
    const l = require("fs").readFileSync(process.argv[1], "utf8").split("\n").filter(Boolean);
    const c = JSON.parse(l[0]).messages[0].content;
    process.exit(c.includes("saluda con la línea `hola` y nada más") && c.includes("scripts/verify") && !c.includes("trae datos estáticos") ? 0 : 1);
  ' "$REQS"
  fin ;;

# --- CA-02: derivación ---------------------------------------------------------
derivacion)
  preparar_refutar
  for k in diseno-ca sin-evidencia; do
    resp "$k"
    refutar "d-$k" CA-01
    clase="${k/-/_}"; [ "$k" = "diseno-ca" ] && clase="diseno_ca"
    afirma "$k: sale 0 y clase $clase, sin refutar ni escalar" js "$base/d-$k.out" "j.clase === '$clase' && j.refutado === false && j.escalado === false"
    afirma "$k: no corrió nada (exit null)" js "$base/d-$k.out" 'j.exit === null && j.salida === null'
    afirma "$k: el canario no existe" [ ! -e "$R/canario" ]
  done
  resp contradice-ajeno
  refutar d-ajeno CA-01
  afirma "contradice ajeno: sin_evidencia con motivo" js "$base/d-ajeno.out" 'j.clase === "sin_evidencia" && j.refutado === false && j.escalado === false && j.motivo === "contradice no está en el CA" && j.exit === null'
  resp prediccion-incumplida
  refutar d-incumplida CA-01
  afirma "predicción incumplida: sin_evidencia, pero corrió (exit 1)" js "$base/d-incumplida.out" 'j.clase === "sin_evidencia" && j.refutado === false && j.exit === 1 && /no se cumplió/.test(j.motivo)'
  mkfifo "$R/fifo"
  resp_json '{"clase":"bug","evidencia":"x","contradice":"saluda con la línea `hola`","comando":["cat","fifo"],"espera":{"exit":0}}'
  t0=$(date +%s)
  refutar d-tope CA-01 AGENTES_REFUTAR_TOPE_MS=500
  t1=$(date +%s)
  afirma "tope de tiempo: sin_evidencia con motivo de tope" js "$base/d-tope.out" 'j.clase === "sin_evidencia" && j.refutado === false && /tope de tiempo/.test(j.motivo)'
  afirma "tope de tiempo: cortó en menos de 10 s ($((t1 - t0)) s)" [ $((t1 - t0)) -lt 10 ]
  head -c 300000 /dev/zero | tr '\0' 'a' > "$R/grande.txt"
  resp_json '{"clase":"bug","evidencia":"x","contradice":"saluda con la línea `hola`","comando":["cat","grande.txt"],"espera":{"exit":0}}'
  refutar d-buffer CA-01
  afirma "tope de salida: sin_evidencia con motivo de tope (256 KB)" js "$base/d-buffer.out" 'j.clase === "sin_evidencia" && /tope de salida/.test(j.motivo) && Buffer.byteLength(j.salida) <= 4096'
  fin ;;

# --- CA-03: allowlist ----------------------------------------------------------
allowlist)
  preparar_refutar
  printf 'secreto\n' > "$D/fuera"
  printf 'uno\n' > "$R/.env"
  mkdir -p "$R/.state"; printf 'uno\n' > "$R/.state/x"
  ln -s "$D/fuera" "$R/link-afuera"
  CANARIO="$R/canario"
  sha_datos="$(shasum "$R/datos.txt")"
  intacto() { [ ! -e "$CANARIO" ] && [ "$(shasum "$R/datos.txt" 2>/dev/null)" = "$sha_datos" ]; }
  # nombre<TAB>argv JSON. Todos con un `contradice` VÁLIDO: RF-04.2 va antes.
  while IFS=$'\t' read -r nombre argv; do
    [ -n "$nombre" ] || continue
    resp_json "{\"clase\":\"bug\",\"evidencia\":\"x\",\"contradice\":\"saluda con la línea \`hola\`\",\"comando\":$argv,\"espera\":{\"exit\":0}}"
    ca=CA-01
    refutar "v-$nombre" "$ca"
    afirma "$nombre: escalado, no refutado, no corrió (rc=$RC)" js "$base/v-$nombre.out" 'j.escalado === true && j.refutado === false && j.exit === null && /allowlist regla/.test(j.motivo)'
    afirma "$nombre: el canario no existe y datos.txt sigue igual" intacto
  done <<'VECTORES'
sh-c	["sh","-c","touch canario"]
bash-c	["bash","-c","touch canario"]
node-e	["node","-e","require('fs').writeFileSync('canario','')"]
python3	["python3","-c","open('canario','w')"]
touch	["touch","canario"]
rm	["rm","datos.txt"]
sed-w	["sed","-n","w canario","datos.txt"]
sed-e	["sed","-n","1e touch canario","datos.txt"]
sed-i	["sed","-i","","1d","datos.txt"]
sed-s-w	["sed","-n","s/uno/x/w canario","datos.txt"]
git-c	["git","-c","core.pager=touch canario","log"]
git-output	["git","diff","--output=canario"]
git-ext-diff	["git","log","--ext-diff"]
git-textconv	["git","show","--textconv"]
git-C	["git","-C","/","log"]
git-otro	["git","checkout","datos.txt"]
cat-fuera	["cat","../fuera"]
cat-abs	["cat","/etc/hosts"]
cat-env	["cat",".env"]
cat-state	["cat",".state/x"]
cat-git	["cat",".git/config"]
cat-symlink	["cat","link-afuera"]
git-show-env	["git","show","HEAD:.env"]
sustitucion	["cat","$(touch canario)"]
backtick	["cat","`touch canario`"]
salto	["cat","datos.txt\ntouch canario"]
pipe	["cat","datos.txt","|","touch","canario"]
redir	["cat","datos.txt",">","canario"]
verify-otro-id	["scripts/verify","0001","--ca","CA-01"]
verify-otro-ca	["scripts/verify","9089","--ca","CA-02"]
grep-sin-ruta	["grep","hola"]
grep-flag-pegada	["grep","-ni","hola","datos.txt"]
head-mas	["tail","-n","+2","datos.txt"]
VECTORES
  # Formas permitidas: se aceptan y corren (exit no nulo, no escalado). La
  # predicción exit 99 no se cumple: clase sin_evidencia, pero corrió.
  while IFS=$'\t' read -r nombre argv; do
    [ -n "$nombre" ] || continue
    resp_json "{\"clase\":\"bug\",\"evidencia\":\"x\",\"contradice\":\"saluda con la línea \`hola\`\",\"comando\":$argv,\"espera\":{\"exit\":99}}"
    refutar "p-$nombre" CA-01
    afirma "permitido $nombre: no escalado y corrió (rc=$RC)" js "$base/p-$nombre.out" 'j.escalado === false && typeof j.exit === "number"'
  done <<'PERMITIDOS'
verify	["scripts/verify","9089","--ca","CA-01"]
grep	["grep","-n","-i","-w","-x","-F","uno","datos.txt"]
grep-e	["grep","-c","-E","-e","u.o","datos.txt"]
grep-ctx	["grep","-A","1","-B","1","-C","1","dos","datos.txt"]
grep-l	["grep","-l","uno","datos.txt"]
grep-r	["grep","-r","-n","uno","."]
sed	["sed","-n","2p","datos.txt"]
sed-rango	["sed","-n","1,2p","datos.txt"]
cat	["cat","datos.txt","salida.txt"]
head	["head","-n","1","datos.txt"]
tail	["tail","-n","1","datos.txt"]
wc	["wc","-l","-c","datos.txt"]
git-log	["git","log","--oneline","-n","1"]
git-log-p	["git","log","-p","--","datos.txt"]
git-show	["git","show","HEAD:datos.txt"]
git-show-stat	["git","show","--stat","HEAD"]
git-diff	["git","diff","--name-only","HEAD","--","datos.txt"]
PERMITIDOS
  afirma "grep -r excluye .state, .git y .env (inyectados)" js "$base/p-grep-r.out" '!/\.state|\.git\/|\.env/.test(j.salida) && /datos\.txt/.test(j.salida)'
  afirma "git show corre con --no-ext-diff --no-textconv" js "$base/p-git-show.out" 'j.exit === 0 && /uno/.test(j.salida)'
  fin ;;

# --- CA-04: refutador caído y uso ---------------------------------------------
caido)
  preparar_refutar
  muerto="$(puerto_muerto)"
  config "$base/muerto.yaml" "$muerto"
  correr k-apagado en "$R" env AGENTES_CONFIG="$base/muerto.yaml" node scripts/agentes refutar --spec 9089 --ca CA-01 --agente ollama
  afirma "Ollama apagado: exit 3 (rc=$RC)" rc_es 3
  resp no-json; refutar k-nojson CA-01
  afirma "respuesta que no es JSON: exit 4 (rc=$RC)" rc_es 4
  resp bug-sin-comando; refutar k-sincmd CA-01
  afirma "bug sin comando: exit 4 (rc=$RC)" rc_es 4
  afirma "bug sin comando: stdout vacío" [ ! -s "$base/k-sincmd.out" ]
  resp confirmado-exit
  correr k-sinca en "$R" env AGENTES_CONFIG="$CFG" node scripts/agentes refutar --spec 9089 --agente ollama
  afirma "sin --ca: exit 2 (rc=$RC)" rc_es 2
  refutar k-ca99 CA-99
  afirma "CA inexistente: exit 2 (rc=$RC)" rc_es 2
  refutar k-ca1 CA-1
  afirma "CA-1 no matchea CA-10: exit 2 (rc=$RC)" rc_es 2
  for a in claude codex desconocido; do
    correr "k-$a" en "$R" env AGENTES_CONFIG="$CFG" node scripts/agentes refutar --spec 9089 --ca CA-01 --agente "$a"
    afirma "--agente $a: exit 2 (rc=$RC)" rc_es 2
  done
  fin ;;

# --- CA-05: scripts/ruta --refutador ------------------------------------------
ruta)
  RESP="$base/resp.json"; : > "$RESP"
  levantar_fake "$FIX/fake-ollama-archivo.js" "$base/fref" "$RESP"; PREF="$FAKE_PORT"
  levantar_fake "$FIX_AG/fake-ollama.js" "$base/fimpl" "$base/modo-impl"; PIMPL="$FAKE_PORT"
  printf 'ok\n' > "$base/modo-impl"
  muerto="$(puerto_muerto)"
  config "$base/claude.yaml" "$PREF"
  config "$base/claude-muerto.yaml" "$muerto"
  config "$base/agent.yaml" "$PIMPL" "$PREF"
  config "$base/agent-muerto.yaml" "$PIMPL" "$muerto"

  # claude falso con el output.json del juguete (no se toca tests/fixtures/ruta).
  FC="$base/fc"; mkdir -p "$FC"
  cp "$FIX_RUTA/fake-claude" "$FIX_RUTA/ok-directo.jsonl" "$FC/"
  salida_claude() { # salida_claude <json de ca[]> <pasa> <ca_pass> <ca_total>
    printf '{"result":{"spec":"9089","ca":%s,"lint_ok":true,"doctor_ok":true,"pasa":%s,"ca_total":%s,"ca_pass":%s,"segunda_vuelta":false},"agentCount":2,"totalTokens":100,"totalToolCalls":3}\n' "$1" "$2" "$4" "$3" > "$FC/ok-directo.output.json"
  }
  ruta_claude() { # ruta_claude <nombre> <cfg> <args...>
    local n="$1" cfg="$2"; shift 2
    local d="$base/$n"; armar_copia "$d"
    correr "$n" en "$d/repo" env AGENTES_CONFIG="$cfg" FAKE_CLAUDE_CASE=ok-directo \
      scripts/ruta "$@" --claude "$FC/fake-claude" --registro "$d/reg.jsonl"
  }
  CA_DIRECTO='[{"id":"CA-01","estado":"PASS"},{"id":"CA-11","estado":"MANUAL"}]'

  # Camino Claude, directo.
  salida_claude "$CA_DIRECTO" true 1 2
  cp "$FIX/respuestas/confirmado-datos.json" "$RESP"
  ruta_claude r-ref "$base/claude.yaml" directo 9089 --refutador ollama
  afirma "claude refutado: exit 0 (rc=$RC)" rc_es 0
  afirma "claude refutado: [REFUTADO] CA-01" grep -q '^\[REFUTADO\] CA-01 grep -c hola datos.txt' "$base/r-ref.out"
  afirma "claude refutado: PASA=false y CA_PASS=0/2" pasa_es r-ref false
  afirma "claude refutado: CA_PASS descontado" tiene r-ref.out "CA_PASS=0/2"
  afirma "claude refutado: RUTA= con REFUTADOR=ollama REFUTADOS=1 ESCALADOS=0 SIN_VEREDICTO=0" grep -q '^RUTA=.* REFUTADOR=ollama REFUTADOS=1 ESCALADOS=0 SIN_VEREDICTO=0$' "$base/r-ref.out"
  afirma "claude refutado: registro con pasa false y refutados=CA-01" jsonl_es "$base/r-ref/reg.jsonl" 1 'r.pasa === false && r.ca_pass === 0 && /refutador=ollama refutados=CA-01 escalados= sin_veredicto=/.test(r.notas)'
  afirma "claude refutado: [REFUTADO] va antes de RUTA=" node -e '
    const l = require("fs").readFileSync(process.argv[1], "utf8").split("\n");
    const a = l.findIndex((x) => x.startsWith("[REFUTADO]")), b = l.findIndex((x) => x.startsWith("RUTA="));
    process.exit(a >= 0 && b > a ? 0 : 1);' "$base/r-ref.out"

  cp "$FIX/respuestas/escalado-touch.json" "$RESP"
  ruta_claude r-esc "$base/claude.yaml" directo 9089 --refutador ollama
  afirma "claude escalado: [ESCALADO] CA-01" grep -q '^\[ESCALADO\] CA-01 touch canario → allowlist regla' "$base/r-esc.out"
  afirma "claude escalado: PASA y CA_PASS como sin la flag (true, 1/2)" grep -q '^RUTA=.* PASA=true CA_PASS=1/2 .* ESCALADOS=1 ' "$base/r-esc.out"
  afirma "claude escalado: no se creó el canario" [ ! -e "$base/r-esc/repo/canario" ]
  afirma "claude escalado: registro pasa true, escalados=CA-01" jsonl_es "$base/r-esc/reg.jsonl" 1 'r.pasa === true && r.ca_pass === 1 && /escalados=CA-01/.test(r.notas)'

  ruta_claude r-sinv "$base/claude-muerto.yaml" directo 9089 --refutador ollama
  afirma "claude Ollama apagado: exit 0 (rc=$RC)" rc_es 0
  afirma "claude Ollama apagado: [SIN_VEREDICTO] CA-01" grep -q '^\[SIN_VEREDICTO\] CA-01 → refutar salió con 3' "$base/r-sinv.out"
  afirma "claude Ollama apagado: PASA=false" pasa_es r-sinv false
  afirma "claude Ollama apagado: corrida registrada" jsonl_es "$base/r-sinv/reg.jsonl" 1 'r.pasa === false && /sin_veredicto=CA-01/.test(r.notas)'

  # Camino Claude, exhaustivo --fase impl: el CA ya refutado por el workflow
  # y el MANUAL no se refutan por afuera; sólo CA-02.
  salida_claude '[{"id":"CA-01","estado":"PASS","refutado":true},{"id":"CA-02","estado":"PASS","refutado":false},{"id":"CA-11","estado":"MANUAL"}]' false 2 3
  printf '{"plan":{"grupos":[{"nombre":"G1","archivos":["salida.txt"],"descripcion":"x"}],"casos_borde":[],"supuestos":[]}}\n' > "$base/plan.json"
  antes="$(lineas_fake "$base/fref/requests.jsonl")"
  ruta_claude r-impl "$base/claude.yaml" exhaustivo 9089 --fase impl --plan "$base/plan.json" --refutador ollama
  despues="$(lineas_fake "$base/fref/requests.jsonl")"
  afirma "impl: exit 0 (rc=$RC)" rc_es 0
  afirma "impl: un solo request al refutador (CA-02), no CA-01 ni CA-11 ($antes → $despues)" [ $((despues - antes)) -eq 1 ]
  afirma "impl: el request es del CA-02" node -e '
    const l = require("fs").readFileSync(process.argv[1], "utf8").split("\n").filter(Boolean);
    process.exit(JSON.parse(l[l.length - 1]).messages[0].content.includes("CA-02 pasa.") ? 0 : 1);' "$base/fref/requests.jsonl"
  afirma "impl: RUTA= con REFUTADOR=ollama" grep -q '^RUTA=.* REFUTADOR=ollama ' "$base/r-impl.out"

  # Camino --agent ollama: implementador con el fake de 0086, refutador con
  # el de esta spec (ollama-refutador, otro puerto).
  cp "$FIX/respuestas/confirmado-datos.json" "$RESP"
  ruta_agent() { local n="$1" cfg="$2"; local d="$base/$n"; armar_copia "$d"
    correr "$n" en "$d/repo" env AGENTES_CONFIG="$cfg" scripts/ruta directo 9089 --agent ollama --refutador ollama-refutador --registro "$d/reg.jsonl"; }
  ruta_agent a-ref "$base/agent.yaml"
  afirma "agent refutado: exit 0 (rc=$RC)" rc_es 0
  afirma "agent refutado: [REFUTADO] CA-01" grep -q '^\[REFUTADO\] CA-01 ' "$base/a-ref.out"
  afirma "agent refutado: PASA=false, CA_PASS=2/4" grep -q '^RUTA=.* PASA=false CA_PASS=2/4 .* REFUTADOR=ollama-refutador REFUTADOS=1 ESCALADOS=0 SIN_VEREDICTO=0$' "$base/a-ref.out"
  afirma "agent refutado: registro con agente= adelante y refutados=CA-01" jsonl_es "$base/a-ref/reg.jsonl" 1 'r.pasa === false && /^agente=ollama model=.*refutador=ollama-refutador refutados=CA-01 /.test(r.notas)'
  cp "$FIX/respuestas/escalado-touch.json" "$RESP"
  ruta_agent a-esc "$base/agent.yaml"
  afirma "agent escalado: [ESCALADO] CA-01" grep -q '^\[ESCALADO\] CA-01 touch canario' "$base/a-esc.out"
  # Base sin --refutador: el CA-11 manual sin firmar ya da [FAIL] por este
  # camino, así que PASA=false viene de antes; el escalado no lo mueve.
  d="$base/a-base"; armar_copia "$d"
  correr a-base en "$d/repo" env AGENTES_CONFIG="$base/agent.yaml" scripts/ruta directo 9089 --agent ollama --registro "$d/reg.jsonl"
  pc() { grep '^RUTA=' "$base/$1.out" | grep -oE 'PASA=[a-z]+ CA_PASS=[0-9]+/[0-9]+'; }
  igual_base() { [ -n "$(pc a-base)" ] && [ "$(pc a-esc)" = "$(pc a-base)" ]; }
  afirma "agent escalado: PASA y CA_PASS iguales a sin la flag ($(pc a-base))" igual_base
  afirma "agent escalado: ESCALADOS=1" grep -q '^RUTA=.* ESCALADOS=1 ' "$base/a-esc.out"
  ruta_agent a-sinv "$base/agent-muerto.yaml"
  afirma "agent refutador apagado: exit 0 (rc=$RC)" rc_es 0
  afirma "agent refutador apagado: tres [SIN_VEREDICTO] y PASA=false" grep -q '^RUTA=.* PASA=false CA_PASS=0/4 .* SIN_VEREDICTO=3$' "$base/a-sinv.out"
  afirma "agent refutador apagado: corrida registrada con pasa false" jsonl_es "$base/a-sinv/reg.jsonl" 1 'r.pasa === false'
  fin ;;

# --- CA-06: guardas y --dry-run ----------------------------------------------
guardas)
  RESP="$base/resp.json"; : > "$RESP"
  levantar_fake "$FIX/fake-ollama-archivo.js" "$base/f" "$RESP"
  config "$base/a.yaml" "$FAKE_PORT"
  D="$base/c"; armar_copia "$D"; R="$D/repo"
  g() { local n="$1"; shift; correr "$n" en "$R" env AGENTES_CONFIG="$base/a.yaml" scripts/ruta "$@"; }
  g g-sinvalor directo 9089 --dry-run --refutador
  afirma "--refutador sin valor: exit 2 (rc=$RC)" rc_es 2
  for a in desconocido claude codex; do
    g "g-$a" directo 9089 --dry-run --refutador "$a"
    afirma "--refutador $a: exit 2 (rc=$RC)" rc_es 2
  done
  g g-plan exhaustivo 9089 --fase plan --dry-run --refutador ollama
  afirma "exhaustivo --fase plan --refutador: exit 2 (rc=$RC)" rc_es 2
  afirma "exhaustivo --fase plan: dice que sólo refuta CA" tiene g-plan.err "sólo refuta CA"
  g g-plan-def exhaustivo 9089 --dry-run --refutador ollama
  afirma "exhaustivo sin --fase (plan): exit 2 (rc=$RC)" rc_es 2
  g g-dry directo 9089 --dry-run --refutador ollama
  afirma "dry-run claude: exit 0 (rc=$RC)" rc_es 0
  afirma "dry-run claude: REFUTADOR=ollama justo antes de CMD=" node -e '
    const l = require("fs").readFileSync(process.argv[1], "utf8").split("\n");
    const i = l.findIndex((x) => x.startsWith("CMD="));
    process.exit(i > 0 && /^REFUTADOR=ollama MODEL=qwen2\.5-coder:7b URL=http:\/\/127\.0\.0\.1:\d+$/.test(l[i - 1]) ? 0 : 1);' "$base/g-dry.out"
  g g-dry-agent directo 9089 --dry-run --agent ollama --refutador ollama
  afirma "dry-run --agent: exit 0 y REFUTADOR= justo antes de CMD=" node -e '
    const l = require("fs").readFileSync(process.argv[1], "utf8").split("\n");
    const i = l.findIndex((x) => x.startsWith("CMD="));
    process.exit(i > 0 && /^REFUTADOR=ollama MODEL=/.test(l[i - 1]) ? 0 : 1);' "$base/g-dry-agent.out"
  afirma "dry-run no llamó al fake" [ "$(lineas_fake "$base/f/requests.jsonl")" = "0" ]
  fin ;;

# --- CA-07 (parte): sin --refutador, los dry-run no cambian ------------------
# Overlay: misma carpeta, primero los scripts nuevos y después los de d8dc6f3
# (la spec al abrir), así las rutas absolutas no distorsionan.
sin-cambios)
  T="$base/t"; mkdir -p "$T"
  git -C "$SRC" archive HEAD | tar -x -C "$T"
  cp -p "$SCRIPTS_SRC/ruta" "$SCRIPTS_SRC/agentes" "$T/scripts/"
  casos() {
    en "$T" scripts/ruta directo 0028 --dry-run > "$base/$1-directo.out" 2>&1 || echo "rc=$?" >> "$base/$1-directo.out"
    en "$T" scripts/ruta exhaustivo 0028 --fase plan --dry-run > "$base/$1-plan.out" 2>&1 || echo "rc=$?" >> "$base/$1-plan.out"
    en "$T" scripts/ruta directo 0028 --agent ollama --dry-run > "$base/$1-agent.out" 2>&1 || echo "rc=$?" >> "$base/$1-agent.out"
  }
  casos nuevo
  git -C "$SRC" show d8dc6f3:scripts/ruta > "$T/scripts/ruta"
  git -C "$SRC" show d8dc6f3:scripts/agentes > "$T/scripts/agentes"
  casos viejo
  for k in directo plan agent; do
    afirma "dry-run $k sin --refutador: igual byte a byte a d8dc6f3" cmp -s "$base/nuevo-$k.out" "$base/viejo-$k.out"
    afirma "dry-run $k: salió bien (sin rc= agregado)" no_tiene "nuevo-$k.out" "rc="
  done
  fin ;;
esac
