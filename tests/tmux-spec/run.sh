#!/usr/bin/env bash
# RNF-03 de
# spec 0037 (not in this snapshot)
# Corre contra un clon temporal de MAIN (no el repo real) con un socket de
# tmux privado y "--agent true" (o un agente falso que registra su prompt);
# limpia el clon, el socket y los worktrees al salir. No toca el repo real
# ni la sesión de tmux del operador.
set -euo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_REPO="$(cd "$SELF_DIR/../.." && pwd)"

usage() {
  echo "uso: tests/tmux-spec/run.sh {lib|open|new|close|spec-new}" >&2
}

SUB="${1:-}"

# Sin subcomando: corre las cinco suites en secuencia, cada una con su
# propio clon temporal aislado (CA-05 de
# spec 0039 (not in this snapshot) pide poder invocar
# "bash tests/tmux-spec/run.sh" a secas). Cualquier suite que falle deja
# el exit code final en 1, pero no corta a las demás: da el panorama
# completo de una sola corrida.
if [ -z "$SUB" ]; then
  rc=0
  for s in lib open new close spec-new; do
    bash "$SELF_DIR/run.sh" "$s" || rc=1
  done
  exit "$rc"
fi

case "$SUB" in
  lib|open|new|close|spec-new) : ;;
  *) usage; exit 2 ;;
esac

fail() {
  echo "tests/tmux-spec ($SUB): FAIL: $*" >&2
  exit 1
}

# --- raíz de trabajo + limpieza (trap) ---------------------------------------

TMPBASE="${TMPDIR:-/tmp}"
ROOT="$(mktemp -d "$TMPBASE/tmux-spec-test.XXXXXX")"

cleanup() {
  if [ -n "${TMUX_SPEC_SOCKET:-}" ]; then
    tmux -L "$TMUX_SPEC_SOCKET" kill-server >/dev/null 2>&1 || true
  fi
  # guarda de prefijo: nunca se borra nada fuera de lo que mktemp acaba de crear
  case "$ROOT" in
    "$TMPBASE"/tmux-spec-test.*) rm -rf "$ROOT" ;;
  esac
}
trap cleanup EXIT INT TERM

# --- clon temporal: sólo main, con el scripts/ del working tree bajo prueba --
# encima (commiteado en el clon, no en el repo real) — así se prueba el
# código actual sin necesidad de commitear nada acá.

MAIN_CHECKOUT="$(git -C "$SRC_REPO" worktree list --porcelain | awk '/^worktree /{print $2; exit}')"
CLONE="$ROOT/repo"

git clone --quiet --branch main "$MAIN_CHECKOUT" "$CLONE"
rm -rf "$CLONE/scripts"
cp -a "$SRC_REPO/scripts" "$CLONE/scripts"
git -C "$CLONE" add scripts
# Con 0037 ya fusionada, main puede tener exactamente estos scripts: sin
# cambios no hay commit (y "git commit" vacío saldría con 1).
git -C "$CLONE" diff --cached --quiet || \
  git -C "$CLONE" -c user.name="tmux-spec tests" -c user.email="tmux-spec-tests@localhost" \
    commit --quiet -m "test: scripts/ del working tree bajo prueba"

# El symlink "node_modules" no queda ignorado por ".gitignore:node_modules/"
# (la barra final sólo matchea directorios): se replica el arreglo que ya
# tiene el checkout real en su .git/info/exclude (ver §7 de la spec).
echo "/node_modules" >> "$CLONE/.git/info/exclude"

# Fixtures de RF-04: en un clon nuevo estas rutas no existen (a diferencia
# del checkout real, donde son symlinks a .state real); se fabrican acá
# para poder probar el symlink/la copia.
mkdir -p "$CLONE/node_modules"
echo fixture > "$CLONE/node_modules/MARCA"
mkdir -p "$CLONE/.state/dsh"
echo fixture > "$CLONE/.state/dsh/MARCA"
mkdir -p "$CLONE/.claude"
echo '{}' > "$CLONE/.claude/settings.local.json"

# --- agente falso: registra el prompt exacto que recibió (argv[1]) ----------

FAKE_AGENT="$ROOT/fake-agent"
AGENT_LOG="$ROOT/agent-calls.log"
: > "$AGENT_LOG"
cat > "$FAKE_AGENT" <<FAKEAGENTEOF
#!/usr/bin/env bash
printf '%s\n' "\$1" >> "$AGENT_LOG"
FAKEAGENTEOF
chmod +x "$FAKE_AGENT"

# --- socket de tmux privado, servidor precreado con remain-on-exit ----------
# "--agent true" (o el agente falso) sale enseguida: sin remain-on-exit la
# ventana desaparecería antes de poder inspeccionarla.

unset TMUX
export TMUX_SPEC_SOCKET="tmux-spec-test-$$-$(basename "$ROOT")"
tmux -L "$TMUX_SPEC_SOCKET" new-session -d -s _boot -n _boot 'sleep 600' >/dev/null 2>&1
tmux -L "$TMUX_SPEC_SOCKET" set-option -g remain-on-exit on >/dev/null 2>&1

# --- helpers de fixtures ------------------------------------------------------

# Escribe y commitea una spec mínima (sólo lo que lee tmux-spec: id y
# target_branch) en $CLONE/specs. No es una spec real: no tiene las 8
# secciones ni pasaría "spec lint".
write_fixture_spec() {
  local id="$1" title="$2" target_branch="$3" slug file
  slug="$(printf '%s' "$title" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')"
  file="$CLONE/specs/${id}-${slug}.md"
  cat > "$file" <<SPECEOF
# SPEC — $title (fixture de prueba)

\`\`\`yaml
id: "$id"
title: "$title"
version: 1
status: draft
created_at: 2026-01-01
updated_at: 2026-01-01
schema_change: false
arch_decision: false
target_branch: "$target_branch"
loc_estimate: 10
tier_locked: null
supersedes: null
\`\`\`

## 1. Objetivo

Fixture de tests/tmux-spec/run.sh; no es una spec real.
SPECEOF
  git -C "$CLONE" add "$file"
  git -C "$CLONE" -c user.name="tmux-spec tests" -c user.email="tmux-spec-tests@localhost" \
    commit --quiet -m "test: fixture spec $id"
  printf '%s\n' "$file"
}

# Reemplaza, en $1/orca.yaml, el cuerpo del bloque literal "setup: |" (bajo
# "scripts:") por una única línea $2 — bootstrap/doctor reales no dan verde
# en un clon sin dependencias (ver §7 D1 de la spec). Formato preservado.
replace_setup_body() {
  local clone="$1" new_cmd="$2" f tmp
  f="$clone/orca.yaml"
  tmp="$(mktemp)"
  awk -v cmd="$new_cmd" '
    BEGIN { state=0 }
    state==0 && /^scripts:[ \t]*$/ { print; state=1; next }
    state==1 && /^[ \t]+setup:[ \t]*\|[ \t]*$/ { print; print "    " cmd; state=2; next }
    state==2 {
      if ($0 ~ /^[ \t]{4}/) { next }
      state=3
      print
      next
    }
    { print }
  ' "$f" > "$tmp"
  mv "$tmp" "$f"
}

# "tmux new-window" vuelve en cuanto lanza el proceso, no cuando termina:
# el agente falso (o "true") corre asincrónico dentro del pane. Este poll
# espera a que aparezca lo que se busca, con un timeout corto.
wait_until() {
  local tries=50
  while [ "$tries" -gt 0 ]; do
    if "$@" 2>/dev/null; then return 0; fi
    tries=$((tries - 1))
    sleep 0.1
  done
  return 1
}

tmux_priv() { tmux -L "$TMUX_SPEC_SOCKET" "$@"; }

window_exists() {
  tmux_priv list-windows -t rmaestro -F '#{window_name}' 2>/dev/null | grep -qxF "$1"
}

window_count() {
  tmux_priv list-windows -t rmaestro -F '#{window_name}' 2>/dev/null | grep -cxF "$1"
}

# --- lib (CA-03) --------------------------------------------------------------

test_lib() {
  (
    cd "$CLONE"
    # shellcheck source=/dev/null
    source scripts/lib/common.sh
    # shellcheck source=/dev/null
    source scripts/lib/worktree.sh

    # (a) specs/NNNN-*.md manda cuando es la fuente más alta
    printf '# fixture\n' > specs/7001-fixture-specs-alto.md
    got="$(wt_next_id)"
    rm -f specs/7001-fixture-specs-alto.md
    [ "$got" = "7002" ] || { echo "specs/: esperaba 7002, salió '$got'" >&2; exit 1; }

    # (b) rama spec/NNNN- manda cuando es la fuente más alta
    git branch spec/7005-fixture-rama-alta >/dev/null
    got="$(wt_next_id)"
    git branch -D spec/7005-fixture-rama-alta >/dev/null
    [ "$got" = "7006" ] || { echo "rama: esperaba 7006, salió '$got'" >&2; exit 1; }

    # (c) worktree registrado cuyo path termina en -NNNN manda cuando es la
    # fuente más alta
    git worktree add -q -b fixture/wt-alto "$ROOT/repo-7009" main
    got="$(wt_next_id)"
    git worktree remove "$ROOT/repo-7009"
    git branch -D fixture/wt-alto >/dev/null
    [ "$got" = "7010" ] || { echo "worktree: esperaba 7010, salió '$got'" >&2; exit 1; }

    # (b') RF-04 de 0039: rama con forma de Orca (prefijo propio + "spec-NNNN-",
    # sin el "spec/" plano de (b)) manda cuando es la fuente más alta; una rama
    # que sólo "parece" spec (sin la barra justo antes) no cuenta
    git branch -q alguien/spec-7020-fixture-orca-rama
    git branch -q notspec-7099-fixture-falso-positivo
    got="$(wt_next_id)"
    git branch -D alguien/spec-7020-fixture-orca-rama >/dev/null
    git branch -D notspec-7099-fixture-falso-positivo >/dev/null
    [ "$got" = "7021" ] || { echo "rama Orca (b'): esperaba 7021, salió '$got'" >&2; exit 1; }

    # (c') RF-04 de 0039: worktree cuyo path tiene un segmento "spec-NNNN-" que
    # no está al final (a diferencia de (c)) manda cuando es la fuente más
    # alta; un path que sólo "parece" spec no cuenta
    git worktree add -q -b fixture/wt-orca "$ROOT/spec-7025-fixture-orca-path" main
    git worktree add -q -b fixture/wt-falso "$ROOT/myspec-7098-fixture-falso" main
    got="$(wt_next_id)"
    git worktree remove "$ROOT/spec-7025-fixture-orca-path"
    git worktree remove "$ROOT/myspec-7098-fixture-falso"
    git branch -D fixture/wt-orca >/dev/null
    git branch -D fixture/wt-falso >/dev/null
    [ "$got" = "7026" ] || { echo "worktree Orca (c'): esperaba 7026, salió '$got'" >&2; exit 1; }

    # (d) RF-04/RF-07 de 0039: ids de sessions/ids-reservados.jsonl, vistos
    # desde tres fuentes distintas — working tree de MAIN sin commitear,
    # refs/heads/main (commiteado ahí) y refs/remotes/*/main (traído con
    # fetch pero no fusionado a esta rama, simulado con update-ref).

    # (d.1) sólo en el working tree, sin commitear
    printf '{"id":"7030"}\n' > sessions/ids-reservados.jsonl
    got="$(wt_next_id)"
    rm -f sessions/ids-reservados.jsonl
    [ "$got" = "7031" ] || { echo "ids-reservados (d.1 working tree): esperaba 7031, salió '$got'" >&2; exit 1; }

    # (d.2) commiteado en la punta de refs/heads/main
    printf '{"id":"7032"}\n' > sessions/ids-reservados.jsonl
    git add sessions/ids-reservados.jsonl
    git -c user.name="tmux-spec tests" -c user.email="tmux-spec-tests@localhost" \
      commit --quiet -m "test: fixture ids-reservados (d.2)"
    got="$(wt_next_id)"
    [ "$got" = "7033" ] || { echo "ids-reservados (d.2 refs/heads/main): esperaba 7033, salió '$got'" >&2; exit 1; }

    # (d.3) refs/remotes/*/main con un id más alto que refs/heads/main (una
    # reserva ya traída con fetch de otra máquina, todavía sin fusionar acá).
    # El commit remoto se arma sobre un índice privado (GIT_INDEX_FILE) con
    # "commit-tree": no toca el índice real, el working tree ni HEAD — sólo
    # agrega objetos y mueve el ref remoto, que se restaura después.
    blob="$(printf '{"id":"7034"}\n' | git hash-object -w --stdin)"
    priv_index="$ROOT/priv-index-d3"
    GIT_INDEX_FILE="$priv_index" git read-tree HEAD
    GIT_INDEX_FILE="$priv_index" git update-index --add --cacheinfo 100644,"$blob",sessions/ids-reservados.jsonl
    remote_tree="$(GIT_INDEX_FILE="$priv_index" git write-tree)"
    rm -f "$priv_index"
    remote_commit="$(git commit-tree "$remote_tree" -p HEAD -m "test: fixture remoto (d.3)")"
    orig_origin_main="$(git rev-parse refs/remotes/origin/main 2>/dev/null || true)"
    git update-ref refs/remotes/origin/main "$remote_commit"
    got="$(wt_next_id)"
    if [ -n "$orig_origin_main" ]; then
      git update-ref refs/remotes/origin/main "$orig_origin_main"
    fi
    [ "$got" = "7035" ] || { echo "ids-reservados (d.3 refs/remotes/*/main): esperaba 7035, salió '$got'" >&2; exit 1; }

    # wt_branch_slug: corta en el primer ':'
    got="$(wt_branch_slug "Worktree por sesión: abrir una sesión paralela")"
    [ "$got" = "worktree-por-sesion" ] || { echo "slug(:): esperaba 'worktree-por-sesion', salió '$got'" >&2; exit 1; }

    # recorte a 40 caracteres, sin guión final
    got="$(wt_branch_slug "Un título bien largo que a propósito supera los cuarenta caracteres de sobra")"
    [ "${#got}" -le 40 ] || { echo "slug(40): se pasó de 40 caracteres: '$got' (${#got})" >&2; exit 1; }
    case "$got" in
      *-) echo "slug(40): terminó en guión: '$got'" >&2; exit 1 ;;
    esac

    # coincide con el slug de "scripts/spec new" para un título corto sin ':'
    title="Titulo corto sin dos puntos"
    specfile="$(./scripts/spec new "$title")"
    spec_slug="$(basename "$specfile" .md | sed -E 's/^[0-9]{4}-//')"
    rm -f "$specfile"
    got="$(wt_branch_slug "$title")"
    [ "$got" = "$spec_slug" ] || { echo "slug(spec new): '$got' vs '$spec_slug'" >&2; exit 1; }
  )
}

# --- open (CA-04) --------------------------------------------------------------

test_open() {
  write_fixture_spec 8000 "Fixture apertura de worktree" "spec/8000-fixture-apertura" >/dev/null
  write_fixture_spec 8001 "Fixture con placeholder" "spec/0000-slug" >/dev/null

  # placeholder de target_branch -> exit 2 sin tocar nada (cubierto acá de
  # forma explícita: el CA-02 real depende de que $TMPDIR esté seteado al
  # correr scripts/verify — ver §7 de la spec)
  local rc=0
  ( cd "$CLONE" && ./scripts/tmux-spec 8001 --dry-run ) >/dev/null 2>&1 || rc=$?
  [ "$rc" -eq 2 ] || fail "placeholder de target_branch: esperaba exit 2, salió $rc"

  # (1) --dry-run: primero se comprueba que se parsea el orca.yaml REAL del
  # clon (D1), antes de tocarlo para el caso verde de más abajo.
  local out
  out="$( cd "$CLONE" && ./scripts/tmux-spec 8000 --dry-run )"
  printf '%s' "$out" | grep -qF "setup: bash scripts/bootstrap" || fail "dry-run: falta el setup real (bootstrap)"
  printf '%s' "$out" | grep -qF "setup: bash scripts/doctor" || fail "dry-run: falta el setup real (doctor)"
  printf '%s' "$out" | grep -qF "ln -s $CLONE/node_modules" || fail "dry-run: falta el symlink de node_modules"
  printf '%s' "$out" | grep -qF "cp $CLONE/.claude/settings.local.json" || fail "dry-run: falta la copia de .worktreeinclude"

  # (2) caso verde: reemplaza scripts.setup por un comando inocuo (bootstrap/
  # doctor reales no dan verde en un clon sin dependencias)
  replace_setup_body "$CLONE" 'echo ran >> .setup-log'

  ( cd "$CLONE" && ./scripts/tmux-spec 8000 --agent "$FAKE_AGENT" ) >/dev/null

  local wt="$ROOT/repo-8000"
  [ -d "$wt" ] || fail "no se creó el worktree $wt"
  git -C "$CLONE" worktree list --porcelain | grep -qF "worktree $wt" || fail "el worktree no quedó registrado"
  [ -L "$wt/node_modules" ] || fail "no se symlinkeó node_modules"
  [ "$(readlink -f "$wt/node_modules")" = "$(readlink -f "$CLONE/node_modules")" ] || fail "el symlink de node_modules apunta mal"
  [ -L "$wt/.state/dsh" ] || fail "no se symlinkeó .state/dsh"
  [ -f "$wt/.claude/settings.local.json" ] || fail ".worktreeinclude no se copió"
  [ ! -L "$wt/.claude/settings.local.json" ] || fail ".worktreeinclude se symlinkeó en vez de copiarse"
  [ -f "$wt/.setup-log" ] || fail "el setup no corrió"
  [ "$(wc -l < "$wt/.setup-log")" -eq 1 ] || fail "el setup corrió una cantidad de veces inesperada"

  window_exists 8000 || fail "no se abrió la ventana 8000"
  wait_until grep -qxF '/rmaestro 8000' "$AGENT_LOG" || fail "el agente no recibió el prompt esperado"

  # (3) segunda corrida: no duplica ventana ni worktree, no repite el setup
  : > "$AGENT_LOG"
  ( cd "$CLONE" && ./scripts/tmux-spec 8000 --agent "$FAKE_AGENT" ) >/dev/null
  sleep 0.5

  [ "$(window_count 8000)" -eq 1 ] || fail "la segunda corrida duplicó la ventana 8000"
  [ "$(wc -l < "$wt/.setup-log")" -eq 1 ] || fail "la segunda corrida volvió a correr el setup"
  [ -s "$AGENT_LOG" ] && fail "la segunda corrida volvió a invocar al agente (debería reusar la ventana)"

  local wt_count
  wt_count="$(git -C "$CLONE" worktree list --porcelain | grep -cF "worktree $wt")"
  [ "$wt_count" -eq 1 ] || fail "la segunda corrida duplicó el worktree"

  # (4) setup que falla: exit 1, sin ventana, con el path impreso para inspección
  write_fixture_spec 8002 "Fixture con setup roto" "spec/8002-fixture-setup-roto" >/dev/null
  replace_setup_body "$CLONE" 'false'

  rc=0
  local out2
  out2="$( cd "$CLONE" && ./scripts/tmux-spec 8002 --agent "$FAKE_AGENT" 2>/dev/null )" || rc=$?
  [ "$rc" -eq 1 ] || fail "setup roto: esperaba exit 1, salió $rc"
  printf '%s' "$out2" | grep -qF "$ROOT/repo-8002" || fail "setup roto: no se imprimió el path del worktree"
  if window_exists 8002; then
    fail "setup roto: no debería haber abierto ventana"
  fi
  [ -d "$ROOT/repo-8002" ] || fail "setup roto: el worktree tendría que quedar para inspección"
}

# --- new (CA-05) --------------------------------------------------------------

test_new() {
  replace_setup_body "$CLONE" 'true'

  local title="Prueba de sesión nueva vía tmux-spec"
  local -a predicted
  mapfile -t predicted < <(
    cd "$CLONE"
    source scripts/lib/common.sh
    source scripts/lib/worktree.sh
    wt_next_id
    wt_branch_slug "$title"
  )
  local expected_id="${predicted[0]}" expected_slug="${predicted[1]}"
  local expected_branch="spec/${expected_id}-${expected_slug}"
  local expected_wt="$ROOT/repo-${expected_id}"

  : > "$AGENT_LOG"
  ( cd "$CLONE" && ./scripts/tmux-spec new "$title" --agent "$FAKE_AGENT" ) >/dev/null

  [ -d "$expected_wt" ] || fail "no se creó el worktree $expected_wt"
  git -C "$CLONE" worktree list --porcelain | grep -qF "worktree $expected_wt" || fail "worktree no registrado"
  git -C "$CLONE" worktree list --porcelain | grep -qF "branch refs/heads/$expected_branch" || fail "rama inesperada"

  window_exists "$expected_id" || fail "no se abrió la ventana $expected_id"

  local expected_prompt="/rmaestro new \"$title\" --id $expected_id --target-branch $expected_branch"
  wait_until grep -qxF "$expected_prompt" "$AGENT_LOG" || fail "el agente no recibió el prompt esperado (esperaba: $expected_prompt)"

  # RF-11: con el scripts/rmaestro de 78d698f en main (sin --id), new sale
  # con exit 2 antes de crear worktree o ventana; --dry-run sólo avisa.
  git -C "$CLONE" show 78d698f:scripts/rmaestro > "$CLONE/scripts/rmaestro"
  git -C "$CLONE" -c user.name="tmux-spec tests" -c user.email="tmux-spec-tests@localhost" \
    commit -q -am "rmaestro viejo en main (prueba RF-11)"
  local old_title="Prueba con rmaestro viejo" old_id old_wt rc=0 wts_before
  old_id="$( cd "$CLONE" && source scripts/lib/common.sh && source scripts/lib/worktree.sh && wt_next_id )"
  old_wt="$ROOT/repo-${old_id}"
  wts_before="$(git -C "$CLONE" worktree list --porcelain)"
  ( cd "$CLONE" && ./scripts/tmux-spec new "$old_title" --agent "$FAKE_AGENT" ) >/dev/null 2>"$ROOT/rf11.err" || rc=$?
  [ "$rc" -eq 2 ] || fail "RF-11: con rmaestro sin --id en main esperaba exit 2, salió $rc"
  grep -q -- '--id' "$ROOT/rf11.err" || fail "RF-11: el mensaje no menciona --id"
  [ ! -e "$old_wt" ] || fail "RF-11: creó el worktree igual"
  [ "$wts_before" = "$(git -C "$CLONE" worktree list --porcelain)" ] || fail "RF-11: cambió la lista de worktrees"
  window_exists "$old_id" && fail "RF-11: abrió la ventana igual"
  rc=0
  ( cd "$CLONE" && ./scripts/tmux-spec new "$old_title" --dry-run ) >/dev/null 2>"$ROOT/rf11.err" || rc=$?
  [ "$rc" -eq 0 ] && grep -q 'aviso' "$ROOT/rf11.err" || fail "RF-11: --dry-run tendría que avisar y salir 0"
}

# --- close (CA-06) -------------------------------------------------------------

test_close() {
  replace_setup_body "$CLONE" 'true'
  write_fixture_spec 8100 "Fixture de cierre" "spec/8100-fixture-de-cierre" >/dev/null

  ( cd "$CLONE" && ./scripts/tmux-spec 8100 --agent "$FAKE_AGENT" ) >/dev/null

  local wt="$ROOT/repo-8100" branch="spec/8100-fixture-de-cierre"
  [ -d "$wt" ] || fail "no se preparó el worktree de prueba"
  window_exists 8100 || fail "no se abrió la ventana de prueba"

  # la rama diverge de main (si no, is-ancestor daría verdadero de entrada:
  # ver §7 casos borde de la spec)
  echo "cambio" > "$wt/archivo-de-prueba.txt"
  git -C "$wt" add archivo-de-prueba.txt
  git -C "$wt" -c user.name="tmux-spec tests" -c user.email="tmux-spec-tests@localhost" \
    commit --quiet -m "wip en el worktree de prueba"

  # (a) rama sin fusionar -> rechazo en el paso 1, sin tocar la ventana
  local rc=0
  ( cd "$CLONE" && ./scripts/tmux-spec close 8100 ) >/dev/null 2>&1 || rc=$?
  [ "$rc" -eq 1 ] || fail "rama sin fusionar: esperaba exit 1, salió $rc"
  [ -d "$wt" ] || fail "rama sin fusionar: no debería haber tocado el worktree"
  window_exists 8100 || fail "rama sin fusionar: mató la ventana antes del paso 1"

  # fusiona la rama en main (en el clon: no toca el checkout real)
  git -C "$CLONE" merge --quiet --no-ff -m "merge de prueba" "$branch"

  # (b) worktree sucio -> rechazo en el paso 3; el paso 2 sí mata la ventana
  echo "sin commitear" > "$wt/sucio.txt"
  rc=0
  ( cd "$CLONE" && ./scripts/tmux-spec close 8100 ) >/dev/null 2>&1 || rc=$?
  [ "$rc" -eq 1 ] || fail "worktree sucio: esperaba exit 1, salió $rc"
  [ -d "$wt" ] || fail "worktree sucio: el worktree no debería haberse sacado"
  if window_exists 8100; then
    fail "worktree sucio: la ventana debería haberse matado en el paso 2"
  fi

  # (c) limpio -> cierra todo (ventana ya estaba cerrada por el intento anterior)
  rm -f "$wt/sucio.txt"
  ( cd "$CLONE" && ./scripts/tmux-spec close 8100 ) >/dev/null

  [ ! -e "$wt" ] || fail "el worktree debería haber quedado sacado"
  if git -C "$CLONE" worktree list --porcelain | grep -qF "worktree $wt"; then
    fail "el worktree sigue registrado"
  fi
  if git -C "$CLONE" show-ref --verify --quiet "refs/heads/$branch"; then
    fail "la rama debería haberse borrado"
  fi

  # "git worktree remove" no siguió los symlinks de sharedDirectories
  [ -e "$CLONE/node_modules/MARCA" ] || fail "se perdió contenido de MAIN a través del symlink"
  [ -e "$CLONE/.state/dsh/MARCA" ] || fail "se perdió contenido de MAIN a través del symlink"

  # (d) RF-06 v3: sesión de "new" descartada — la spec nunca llegó a main;
  # close <id> toma la rama del worktree registrado en wt_path <id>
  local did dwt dbranch="spec/8200-sesion-descartada"
  did=8200; dwt="$ROOT/repo-$did"
  git -C "$CLONE" worktree add -q -b "$dbranch" "$dwt" main
  # la sesión rmaestro pudo morir al cerrarse su última ventana en (b)/(c)
  if tmux_priv has-session -t rmaestro 2>/dev/null; then
    tmux_priv new-window -d -t rmaestro -n "$did" -- sleep 600
  else
    tmux_priv new-session -d -s rmaestro -n "$did" -- sleep 600
  fi
  ls "$CLONE"/specs/8200-*.md >/dev/null 2>&1 && fail "fixture: no debería existir specs/8200-* en main"

  # Dentro de tmux, con la ventana <id> activa (recién abierta) y close
  # corrido desde otro pane: la guarda de "propia ventana" mira $TMUX_PANE,
  # no la ventana activa del cliente (bug de la prueba real de CA-10).
  local caller_pane did_win
  caller_pane="$(tmux_priv new-window -d -P -F '#{pane_id}' -t rmaestro -n caller -- sleep 600)"
  did_win="$(tmux_priv list-windows -t rmaestro -F '#{window_id} #{window_name}' | awk -v n="$did" '$2==n{print $1; exit}')"
  tmux_priv select-window -t "$did_win"
  rc=0
  local own_pane
  own_pane="$(tmux_priv list-panes -t "$did_win" -F '#{pane_id}' | head -1)"
  ( cd "$CLONE" && TMUX="fake,0,0" TMUX_PANE="$own_pane" ./scripts/tmux-spec close "$did" ) >/dev/null 2>&1 || rc=$?
  [ "$rc" -eq 1 ] || fail "propia ventana: esperaba exit 1 con TMUX_PANE en la ventana $did, salió $rc"
  [ -d "$dwt" ] || fail "propia ventana: no debería haber tocado el worktree"
  ( cd "$CLONE" && TMUX="fake,0,0" TMUX_PANE="$caller_pane" ./scripts/tmux-spec close "$did" ) >/dev/null \
    || fail "otra ventana con <id> activa: close tendría que cerrar (miró la ventana activa, no TMUX_PANE)"
  [ ! -e "$dwt" ] || fail "descartada: el worktree debería haber quedado sacado"
  window_exists "$did" && fail "descartada: la ventana debería haberse matado"
  git -C "$CLONE" show-ref --verify --quiet "refs/heads/$dbranch" && fail "descartada: la rama debería haberse borrado"

  # un worktree en una rama que no es spec/<id>-* no se cierra por id
  git -C "$CLONE" worktree add -q -b "otra-rama" "$ROOT/repo-8300" main
  rc=0
  ( cd "$CLONE" && ./scripts/tmux-spec close 8300 ) >/dev/null 2>&1 || rc=$?
  [ "$rc" -eq 1 ] || fail "rama ajena: esperaba exit 1, salió $rc"
  [ -d "$ROOT/repo-8300" ] || fail "rama ajena: no debería haber tocado el worktree"
}

# --- spec-new (CA-08) ----------------------------------------------------------

test_spec_new() {
  # --id duplicado: exit 1, sin archivo nuevo
  local dup_id before after rc=0
  dup_id="$(ls "$CLONE"/specs/*.md | xargs -n1 basename | grep -oE '^[0-9]{4}' | sort -n | tail -1)"
  before="$(ls "$CLONE"/specs/*.md | wc -l)"
  ( cd "$CLONE" && ./scripts/spec new "Titulo duplicado" --id "$dup_id" ) >/dev/null 2>&1 || rc=$?
  [ "$rc" -eq 1 ] || fail "spec new --id duplicado: esperaba exit 1, salió $rc"
  after="$(ls "$CLONE"/specs/*.md | wc -l)"
  [ "$before" -eq "$after" ] || fail "spec new --id duplicado: creó un archivo de más"

  # --target-branch queda en el front-matter
  local newfile
  newfile="$( cd "$CLONE" && ./scripts/spec new "Prueba de target branch" --target-branch "spec/9500-prueba-target-branch" )"
  grep -qF 'target_branch: "spec/9500-prueba-target-branch"' "$newfile" \
    || fail "spec new --target-branch: no quedó en el front-matter"
  rm -f "$newfile"

  # sin flags: mismo archivo, byte a byte, que "scripts/spec new" en 78d698f
  # (mismo specs/, mismo título, mismo día — ver §7 de la spec)
  # Las dos corridas escriben la misma ruta (mismo id y slug): se guarda una
  # copia de la vieja en otro path antes de borrarla, si no el diff compara
  # un archivo consigo mismo.
  local title="Comparación de spec new contra 78d698f" ref_dir file_old file_new saved_old
  ref_dir="$(mktemp -d "$ROOT/spec-new-ref.XXXXXX")"
  saved_old="$ROOT/spec-new-78d698f.md"
  ( cd "$CLONE" && git archive 78d698f -- scripts templates specs ) | tar -x -C "$ref_dir"
  file_old="$( cd "$ref_dir" && bash scripts/spec new "$title" )"
  cp "$file_old" "$saved_old"
  rm -f "$file_old"
  rm -rf "$ref_dir/scripts" "$ref_dir/templates"
  cp -a "$CLONE/scripts" "$ref_dir/scripts"
  cp -a "$CLONE/templates" "$ref_dir/templates"
  file_new="$( cd "$ref_dir" && bash scripts/spec new "$title" )"
  [ "$file_new" = "$file_old" ] || fail "spec new sin flags: cambió la ruta respecto de 78d698f"
  cmp -s "$saved_old" "$file_new" || fail "spec new sin flags: cambió el contenido respecto de 78d698f"
  rm -f "$saved_old" "$file_new"

  # rmaestro new con flags + --editor true </dev/null
  ( cd "$CLONE" && ./scripts/rmaestro new "Prueba de rmaestro con flags" --id 9600 \
      --target-branch "spec/9600-prueba-rmaestro-flags" --editor true </dev/null >/dev/null 2>&1 ) || true

  local created
  created="$(ls "$CLONE"/specs/9600-*.md 2>/dev/null | head -1)"
  [ -n "$created" ] || fail "rmaestro new --id/--target-branch: no se creó specs/9600-*.md"
  grep -qF 'id: "9600"' "$created" || fail "rmaestro new: el id no quedó en el front-matter"
  grep -qF 'target_branch: "spec/9600-prueba-rmaestro-flags"' "$created" \
    || fail "rmaestro new: el target_branch no quedó en el front-matter"
}

# --- dispatch ------------------------------------------------------------------

case "$SUB" in
  lib) test_lib ;;
  open) test_open ;;
  new) test_new ;;
  close) test_close ;;
  spec-new) test_spec_new ;;
esac

echo "tests/tmux-spec: OK ($SUB)"
