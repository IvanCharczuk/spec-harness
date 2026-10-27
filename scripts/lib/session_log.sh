#!/usr/bin/env bash
# Helpers de scripts/session. RF-01..RF-09 de spec 0006 (not in this snapshot)
# (implementa RF-23 de specs/0001-repo-maestro.md).
# RNF-01 (0006): sólo coreutils/awk/grep/git, sin jq/python/node.
# shellcheck source=common.sh
# (asume que common.sh ya fue sourceado por el caller, para REPO_ROOT)

gen_session_id() {
  local ts hex
  ts="$(date -u +%Y%m%dT%H%M%SZ)"
  hex="$(od -An -tx1 -N4 /dev/urandom 2>/dev/null | tr -d ' \n')"
  printf '%s-%s\n' "$ts" "$hex"
}

# Extrae un campo "KEY=valor" (sin espacios) de una línea tipo la de route.
route_extract() {
  printf '%s\n' "$1" | grep -oE "${2}=[^ ]+" | head -1 | cut -d= -f2- || true
}

# "S1:3,S2:2,..." -> {"S1":3,"S2":2,...}
signals_to_json() {
  printf '{%s}' "$(printf '%s' "$1" | sed -E 's/([A-Z][0-9]):([0-9]+)/"\1":\2/g')"
}

# Escapado JSON (RF-06 de 0006), orden exacto:
#   \  ->  \\
#   "  ->  \"
#   tab (0x09) -> \t
#   CR (0x0D)  -> \r
#   LF (0x0A)  -> \n
#   resto de control chars (0x00-0x1F) -> espacio
# RS="\0" para que awk trate todo el input como un solo record (preserva
# saltos de línea embebidos en vez de partirlos como separador de registro).
json_escape() {
  printf '%s' "$1" | awk '
    BEGIN { RS="\0"; ORS="" }
    { s=$0
      gsub(/\\/,"\\\\",s); gsub(/"/,"\\\"",s)
      gsub(/\t/,"\\t",s); gsub(/\r/,"\\r",s); gsub(/\n/,"\\n",s)
      print s
    }' | tr '[:cntrl:]' ' '
}

# build_session_line (RF-01 de spec 0008 (not in this snapshot)): arma la línea
# JSON de los 19 campos de §5.5 madre, en el mismo orden exacto que
# scripts/session ya usaba antes de esta extracción (line construction
# original: on_exit(), previa al refactor de 0008). Función pura — sólo
# interpola, no escapa nada por sí misma (los campos string ya vienen
# pre-escapados por el caller, mismo criterio que override_reason/
# workspace siempre tuvieron) y no toca filesystem ni locks. Usada por
# scripts/session (sesiones normales, escalated_from/notes vacíos =
# "null"/"") y por scripts/escalate (línea de corrección, RF-07 de
# 0008, y línea de la sesión Tier B nueva vía scripts/session con
# --escalated-from) — una sola fuente de verdad para el orden de los 19
# campos, así las comparaciones posicionales de las CA de 0008 (CA-06/
# CA-08/CA-09) no dependen de dos formatos independientes que puedan
# divergir.
#
# Posiciones (17 args — 19 campos menos model_backend/approvals_denied,
# que quedan hardcodeados a null adentro: nada en el alcance de 0006 u
# 0008 los necesita variar):
#   1  session_id            10 score
#   2  spec_id               11 signals_json      ({"S1":n,...})
#   3  spec_version          12 escalated_from_json (null o "\"id\"")
#   4  started_at            13 workspace          (ya escapado)
#   5  ended_at              14 files_touched      (entero o null)
#   6  tier                  15 verify_result
#      (ya completo, "TIER_A"/"TIER_B" — el caller arma el prefijo,
#      no esta función, así escalate puede pasar el valor de la línea
#      original tal cual sin tener que separar el prefijo)
#   7  profile               16 outcome
#   8  routing_rule          17 notes              (ya escapado)
#   9  override_reason_json  (null o "\"texto\"")
build_session_line() {
  printf '{"session_id":"%s","spec_id":"%s","spec_version":%s,"started_at":"%s","ended_at":"%s","tier":"%s","profile":"%s","routing_rule":"%s","override_reason":%s,"score":%s,"signals":%s,"escalated_from":%s,"workspace":"%s","model_backend":null,"files_touched":%s,"approvals_denied":null,"verify_result":"%s","outcome":"%s","notes":"%s"}' \
    "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$9" "${10}" "${11}" "${12}" "${13}" "${14}" "${15}" "${16}" "${17}"
}

# files_touched (RF-03 de 0006): null si no se puede medir, nunca 0 por
# default — 0 afirma "confirmado que no se tocó nada", no es lo mismo que
# "no se pudo medir".
files_touched_count() {
  local start="$1" workspace="$2" head cnt
  [ -z "$start" ] && { echo null; return; }
  head="$(git -C "$workspace" rev-parse HEAD 2>/dev/null || true)"
  [ -z "$head" ] && { echo null; return; }
  cnt="$(git -C "$workspace" diff --name-only "$start" "$head" -- . 2>/dev/null | wc -l | tr -d ' ')" || true
  case "$cnt" in
    ''|*[!0-9]*) echo null ;;
    *) echo "$cnt" ;;
  esac
}

# verify_result (RF-04 de 0006): sólo corre scripts/verify si
# outcome=completed — correr la suite completa de CA en una sesión que no
# completó no es proporcional y el resultado no sería significativo.
verify_result_for() {
  local outcome="$1" spec_file="$2"
  if [ "$outcome" != "completed" ]; then echo not_run; return; fi
  echo "session: corriendo verificación final..." >&2
  if "$REPO_ROOT/scripts/verify" "$spec_file" >/dev/null 2>&1; then
    echo pass
  else
    echo fail
  fi
}

# --- lock corto de append (RF-07 de 0006) ------------------------------------
# Mismo primitivo que el lock de tier (RF-03 de 0004): mkdir atómico, sin
# flock (no viene por default en macOS). Vida muy corta: se adquiere, se
# hace un único append, se libera.

acquire_index_lock() {
  local locks_dir="$1" lockdir pid i=0
  lockdir="$locks_dir/sessions-index.lock"
  mkdir -p "$locks_dir"
  while [ "$i" -lt 50 ]; do
    if mkdir "$lockdir" 2>/dev/null; then
      echo "$$" > "$lockdir/pid"
      return 0
    fi
    pid="$(cat "$lockdir/pid" 2>/dev/null || true)"
    if [ -n "$pid" ] && ! kill -0 "$pid" 2>/dev/null; then
      rm -rf "$lockdir"
      continue
    fi
    i=$((i + 1))
    sleep 0.1
  done
  # 5s sin poder adquirir: se trata como huérfano, se reclama una vez más.
  rm -rf "$lockdir"
  if mkdir "$lockdir" 2>/dev/null; then
    echo "$$" > "$lockdir/pid"
    return 0
  fi
  echo "session: no se pudo adquirir sessions-index.lock, se escribe sin lock" >&2
  return 1
}

release_index_lock() { rm -rf "$1/sessions-index.lock"; }

append_session_line() {
  local sessions_log="$1" locks_dir="$2" line="$3" rc=0
  mkdir -p "$(dirname "$sessions_log")"
  acquire_index_lock "$locks_dir" || rc=$?
  printf '%s\n' "$line" >>"$sessions_log"
  # Sólo libera si el lock es propio: si acquire_index_lock devolvió 1
  # (falla real, "se escribe sin lock"), el lock que existe en el
  # filesystem pertenece a OTRO proceso vivo — un release incondicional
  # acá le rompería la exclusión mutua a ese otro proceso justo en el
  # escenario de alta contención que RF-07 existe para proteger.
  [ "$rc" -eq 0 ] && release_index_lock "$locks_dir"
}
