#!/usr/bin/env bash
# Helpers de scripts/verify. RF-01..RF-05 de spec 0005 (not in this snapshot)
# (implementa RF-09 de specs/0001-repo-maestro.md).
# RNF-01 (0005): sólo awk/grep/coreutils, sin parser YAML real.
# shellcheck source=common.sh
# shellcheck source=spec.sh
# (asume que common.sh y spec.sh ya fueron sourceados por el caller, para
# REPO_ROOT, yaml_field y section_body)

# --- delimitación de bloques CA (RF-01) --------------------------------------

# Lista, en orden de aparición, los ids "CA-NN" de §6.
ca_ids() {
  local file="$1"
  section_body "$file" 6 | awk '
    /^- \*\*CA-[0-9]+\*\*/ {
      match($0, /CA-[0-9]+/)
      print substr($0, RSTART, RLENGTH)
    }
  '
}

# Texto crudo del bloque de una CA (desde su marcador hasta el próximo
# marcador o el fin de §6), inclusive la línea del marcador.
ca_block() {
  local file="$1" id="$2"
  section_body "$file" 6 | awk -v want="$id" '
    /^- \*\*CA-[0-9]+\*\*/ {
      match($0, /CA-[0-9]+/)
      cur = substr($0, RSTART, RLENGTH)
      if (printing) { exit }
      printing = (cur == want) ? 1 : 0
    }
    printing { print }
  '
}

# Filtro (stdin = bloque de una CA): contenido crudo del primer fenced
# ```yaml, indentación intacta. Vacío si no hay ninguno.
ca_yaml() {
  awk '
    BEGIN { infence = 0; found = 0 }
    !found && /^[ \t]*```yaml[ \t]*$/ { infence = 1; found = 1; next }
    infence && /^[ \t]*```[ \t]*$/ { exit }
    infence { print }
  '
}

# Filtro (stdin = yaml extraído): indentación (string de espacios/tabs) de
# la primera línea no vacía.
yaml_top_indent() {
  awk 'NF { match($0, /^[ \t]*/); print substr($0, RSTART, RLENGTH); exit }'
}

# --- categorización (RF-01: check | manual | malformed) ----------------------

# 0 si el yaml tiene, EN LA INDENTACIÓN DADA, una línea que matchea el
# patrón de clave; 1 si no. Anclado a esa indentación exacta para no
# confundir contenido anidado (p. ej. un cmd: | cuyo script contenga la
# palabra "manual:") con una clave de nivel superior.
yaml_has_key_at_indent() {
  local yaml="$1" indent="$2" keyre="$3"
  printf '%s\n' "$yaml" | awk -v ind="$indent" -v kre="$keyre" '
    $0 ~ ("^" ind kre) { found = 1; exit }
    END { exit(found ? 0 : 1) }
  '
}

# Categoriza un bloque de CA. Imprime "check", "manual", o
# "malformed<TAB><motivo>".
ca_category() {
  local block="$1" yaml indent has_check=0 has_manual=0
  yaml="$(printf '%s\n' "$block" | ca_yaml)"
  if [ -z "$yaml" ]; then
    printf 'malformed\tsin bloque yaml\n'
    return
  fi
  indent="$(printf '%s\n' "$yaml" | yaml_top_indent)"
  yaml_has_key_at_indent "$yaml" "$indent" 'check:[ \t]*$' && has_check=1
  yaml_has_key_at_indent "$yaml" "$indent" 'manual:[ \t]*true[ \t]*$' && has_manual=1

  if [ "$has_check" -eq 1 ] && [ "$has_manual" -eq 1 ]; then
    printf 'malformed\tcheck: y manual: true no pueden coexistir\n'
  elif [ "$has_check" -eq 1 ]; then
    echo check
  elif [ "$has_manual" -eq 1 ]; then
    echo manual
  else
    printf 'malformed\tsin check: ni manual: true\n'
  fi
}

# RF-04 de specs/0070: 0 si el bloque YAML del CA tiene `compat: true` como
# clave de primer nivel (hermana de check:); 1 si no. No altera la
# categorización ni la extracción del comando.
ca_compat() {
  local block="$1" yaml indent
  yaml="$(printf '%s\n' "$block" | ca_yaml)"
  [ -n "$yaml" ] || return 1
  indent="$(printf '%s\n' "$yaml" | yaml_top_indent)"
  yaml_has_key_at_indent "$yaml" "$indent" 'compat:[ \t]*true[ \t]*$'
}

# --- categoría check: extracción de cmd/expect_exit ---------------------------

# Cuerpo bajo "check:" (líneas con indentación mayor que `indent`, hasta la
# próxima línea al mismo nivel o el fin del yaml).
check_body() {
  local yaml="$1" indent="$2"
  printf '%s\n' "$yaml" | awk -v ind="$indent" '
    $0 ~ ("^" ind "check:[ \t]*$") { inchk = 1; next }
    inchk {
      if ($0 ~ ("^" ind "[^ \t]")) { exit }
      print
    }
  '
}

# Extrae "cmd" del check_body ya aislado. Imprime el comando (puede ser
# multilínea) en stdout. Exit 0 = ok; 1 = cmd: ausente o estilo no
# soportado; 2 = "cmd: |" reconocido pero con indentación inconsistente en
# el bloque literal (RF-01 D-ajuste: nunca se trunca contenido en silencio,
# se falla explícito).
extract_cmd() {
  local body="$1"

  if printf '%s\n' "$body" | grep -qE '^[ \t]*cmd:[ \t]*".*"[ \t]*$'; then
    printf '%s\n' "$body" | awk '
      /^[ \t]*cmd:[ \t]*".*"[ \t]*$/ {
        line = $0
        sub(/^[ \t]*cmd:[ \t]*"/, "", line)
        sub(/"[ \t]*$/, "", line)
        gsub(/\\\\/, "\\", line)
        gsub(/\\"/, "\"", line)
        print line
        exit
      }
    '
    return 0
  fi

  if printf '%s\n' "$body" | grep -qE '^[ \t]*cmd:[ \t]*\|[ \t]*$'; then
    local out
    if ! out="$(printf '%s\n' "$body" | awk '
      BEGIN { incmd = 0; cmdind = -1; base = -1 }
      /^[ \t]*cmd:[ \t]*\|[ \t]*$/ { match($0, /^[ \t]*/); cmdind = RLENGTH; incmd = 1; next }
      incmd {
        if (NF == 0) { print ""; next }
        match($0, /^[ \t]*/); ind = RLENGTH
        if (ind <= cmdind) { exit 0 }
        if (base < 0) { base = ind }
        if (ind < base) { exit 1 }
        print substr($0, base + 1)
      }
    ')"; then
      return 2
    fi
    printf '%s\n' "$out"
    return 0
  fi

  return 1
}

# Extrae expect_exit del check_body ya aislado. Nunca sale ≠0: "ausente" se
# señaliza con string vacío (mismo criterio que el "|| true" de signal_s2
# en lib/routing.sh, spec 0004 (not in this snapshot) §7 D9), no con exit code.
extract_expect_exit() {
  printf '%s\n' "$1" | grep -m1 -oE '^[ \t]*expect_exit:[ \t]*[0-9]+' | grep -oE '[0-9]+$' || true
}

# --- categoría manual: extracción de firma -----------------------------------

extract_signed_off_by() {
  local yaml="$1" indent="$2"
  printf '%s\n' "$yaml" | awk -v ind="$indent" '
    $0 ~ ("^" ind "signed_off_by:") {
      line = $0
      sub("^" ind "signed_off_by:[ \t]*", "", line)
      sub(/[ \t]*#.*/, "", line)
      gsub(/^"|"$/, "", line)
      sub(/[ \t]+$/, "", line)
      print line
      exit
    }
  '
}

extract_signed_off_at() {
  local yaml="$1" indent="$2"
  printf '%s\n' "$yaml" | awk -v ind="$indent" '
    $0 ~ ("^" ind "signed_off_at:") {
      line = $0
      sub("^" ind "signed_off_at:[ \t]*", "", line)
      sub(/[ \t]*#.*/, "", line)
      gsub(/^"|"$/, "", line)
      sub(/[ \t]+$/, "", line)
      print line
      exit
    }
  '
}

valid_date() {
  printf '%s' "$1" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
}

# --- evaluación de una CA -----------------------------------------------------

# Evalúa una CA. Imprime "<PASS|FAIL><TAB><categoría><TAB><detalle>"
# (detalle vacío en PASS).
evaluate_ca() {
  local file="$1" id="$2" block cat_out cat
  block="$(ca_block "$file" "$id")"
  cat_out="$(ca_category "$block")"
  cat="${cat_out%%$'\t'*}"

  case "$cat" in
    malformed)
      local detail="${cat_out#*$'\t'}"
      printf 'FAIL\tmalformed\t%s\n' "$detail"
      ;;
    check)
      local yaml indent body rc=0 cmd expect real_exit
      yaml="$(printf '%s\n' "$block" | ca_yaml)"
      indent="$(printf '%s\n' "$yaml" | yaml_top_indent)"
      body="$(check_body "$yaml" "$indent")"

      cmd="$(extract_cmd "$body")" || rc=$?
      case "$rc" in
        1) printf 'FAIL\tcheck\tcheck: malformado (cmd: ausente o estilo no soportado)\n'; return ;;
        2) printf 'FAIL\tcheck\tcheck: malformado (cmd: bloque literal con indentación inconsistente)\n'; return ;;
      esac

      expect="$(extract_expect_exit "$body")"
      if [ -z "$expect" ]; then
        printf 'FAIL\tcheck\tcheck: malformado (expect_exit: ausente)\n'
        return
      fi

      real_exit=0
      ( cd "$REPO_ROOT" && bash -c "$cmd" ) >/dev/null 2>&1 || real_exit=$?
      if [ "$real_exit" -eq "$expect" ]; then
        printf 'PASS\tcheck\t\n'
      else
        printf 'FAIL\tcheck\texit=%s esperado=%s\n' "$real_exit" "$expect"
      fi
      ;;
    manual)
      local yaml indent by at
      yaml="$(printf '%s\n' "$block" | ca_yaml)"
      indent="$(printf '%s\n' "$yaml" | yaml_top_indent)"
      by="$(extract_signed_off_by "$yaml" "$indent")"
      at="$(extract_signed_off_at "$yaml" "$indent")"
      if [ -z "$by" ]; then
        printf 'FAIL\tmanual\tmanual sin firmar\n'
      elif ! valid_date "$at"; then
        printf 'FAIL\tmanual\tsigned_off_at inválida o ausente\n'
      else
        printf 'PASS\tmanual\t\n'
      fi
      ;;
  esac
}

# --- CA superados (RF-01/RF-02/RF-03 de specs/0046) --------------------------
#
# Decisión de conteo (no la fija la spec): un CA superado no suma a
# CA_TOTAL ni a manual_count — scripts/verify lo excluye del loop antes de
# incrementar esos contadores. Así MANUAL_RATIO se calcula igual que hoy
# sobre los CA que de verdad se evaluaron, y CA_SUPERADOS es un contador
# aparte que sólo se imprime si es > 0 (RNF-01: sin superados, la línea
# final no cambia un byte).

# Ruta del registro: $VERIFY_SUPERADOS (fixtures) o config/ca-superados.yaml.
ca_superados_registry_path() {
  if [ -n "${VERIFY_SUPERADOS:-}" ]; then
    printf '%s' "$VERIFY_SUPERADOS"
  else
    printf '%s/config/ca-superados.yaml' "$REPO_ROOT"
  fi
}

# Busca en el registro (lista plana "- spec: ...\n  ca: ...\n
# superado_por: ...\n  motivo: ...", un bloque por entrada) la primera
# entrada con spec == want_spec y ca == want_ca. Imprime
# "<superado_por><TAB><motivo>" si la encuentra; nada si no hay ninguna o
# si el registro no existe.
ca_superados_lookup() {
  local registry="$1" want_spec="$2" want_ca="$3"
  [ -f "$registry" ] || return 0
  awk -v want_spec="$want_spec" -v want_ca="$want_ca" '
    function strip(v) {
      sub(/^[ \t]*/, "", v); sub(/[ \t]*$/, "", v)
      gsub(/^"|"$/, "", v)
      return v
    }
    function reset() { ca = ""; sp = "" ; motivo = "" }
    /^-[ \t]*spec:/ {
      if (found) exit
      if (spec == want_spec && ca == want_ca && sp != "") { found = 1; exit }
      v = $0; sub(/^-[ \t]*spec:[ \t]*/, "", v); spec = strip(v)
      reset()
      next
    }
    /^[ \t]+ca:/      { v = $0; sub(/^[ \t]+ca:[ \t]*/, "", v); ca = strip(v); next }
    /^[ \t]+superado_por:/ { v = $0; sub(/^[ \t]+superado_por:[ \t]*/, "", v); sp = strip(v); next }
    /^[ \t]+motivo:/  { v = $0; sub(/^[ \t]+motivo:[ \t]*/, "", v); motivo = strip(v); next }
    END {
      if (!found && spec == want_spec && ca == want_ca && sp != "") found = 1
      if (found) printf "%s\t%s\n", sp, motivo
    }
  ' "$registry"
}

# Valida una entrada del registro (RF-01): el CA existe en §6 de la spec que
# se está verificando (el propio "$file") y "superado_por" existe en
# specs/ y está verified o implementing. Imprime el motivo del rechazo en
# stdout y devuelve 1 si es inválida; stdout vacío y 0 si es válida.
ca_superados_validate() {
  local ca="$1" superado_por="$2" file="$3" sp_file sp_status
  if ! ca_ids "$file" | grep -qxF "$ca"; then
    printf '%s no existe en el §6 de esta spec' "$ca"
    return 1
  fi
  if ! sp_file="$(resolve_spec "$superado_por" 2>/dev/null)" || [ ! -f "$sp_file" ]; then
    printf 'superado_por %s no existe en specs/' "$superado_por"
    return 1
  fi
  sp_status="$(fm_field "$sp_file" status)"
  case "$sp_status" in
    verified|implementing) return 0 ;;
    *)
      printf 'superado_por %s no está verified/implementing (status=%s)' "$superado_por" "$sp_status"
      return 1
      ;;
  esac
}

# Combina lookup + validate. Imprime, separado por TAB:
#   "NONE"                             — sin entrada en el registro
#   "SUPERADO<TAB>superado_por<TAB>motivo" — entrada válida
#   "INVALIDO<TAB>motivo del rechazo"      — entrada inválida
ca_superado_check() {
  local file="$1" spec_id="$2" ca="$3" registry entry sp motivo reason
  registry="$(ca_superados_registry_path)"
  entry="$(ca_superados_lookup "$registry" "$spec_id" "$ca")"
  if [ -z "$entry" ]; then
    echo NONE
    return
  fi
  sp="$(printf '%s' "$entry" | cut -f1)"
  motivo="$(printf '%s' "$entry" | cut -f2-)"
  if reason="$(ca_superados_validate "$ca" "$sp" "$file")"; then
    printf 'SUPERADO\t%s\t%s\n' "$sp" "$motivo"
  else
    printf 'INVALIDO\t%s\n' "$reason"
  fi
}

# --- ratio (RF-04) ------------------------------------------------------------

pct_ratio() {
  local n="$1" d="$2"
  if [ "$d" -eq 0 ]; then echo 0; return; fi
  echo $(( (n * 100 + d / 2) / d ))
}
