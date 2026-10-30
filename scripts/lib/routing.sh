#!/usr/bin/env bash
# Helpers de scripts/route. RF-01..RF-04 de spec 0002 (not in this snapshot).
# RNF-02 (0002): sólo awk/grep/coreutils, sin jq/python/node.
# shellcheck source=common.sh
# (asume que common.sh ya fue sourceado por el caller, para yaml_field_stdin y REPO_ROOT)
SELF_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=spec.sh
# fm_field/fm_block/section_body/resolve_spec viven en spec.sh (movidos ahí
# por spec 0003 (not in this snapshot), compartidos con scripts/spec — ver §7 D1
# de esa spec). El contrato no cambia, sólo la ubicación.
source "$SELF_LIB_DIR/spec.sh"

# true/false; ausente -> false (documentado [SUPUESTO] en docs/complexity-scoring.md:
# ausencia de metadata se trata como "sin evidencia de disparador", no como disparador).
fm_bool() {
  local file="$1" key="$2" v
  v="$(fm_field "$file" "$key")"
  case "$v" in
    true) echo true ;;
    *) echo false ;;
  esac
}

# entero; ausente o no numérico -> $3 (default)
fm_int() {
  local file="$1" key="$2" default="$3" v
  v="$(fm_field "$file" "$key")"
  case "$v" in
    ''|*[!0-9]*) echo "$default" ;;
    *) echo "$v" ;;
  esac
}

# title del front-matter; si no hay, primera línea "# " del documento.
fm_title() {
  local file="$1" t
  t="$(fm_field "$file" title)"
  if [ -z "$t" ]; then
    t="$(grep -m1 '^# ' "$file" | sed 's/^# //')"
  fi
  printf '%s' "$t"
}

# --- señales S1-S5 (RF-01 de 0002) ------------------------------------------

signal_s1() {
  section_body "$1" 3 | grep -oE 'RF-[0-9]+' | sort -u | wc -l | tr -d ' '
}

signal_s2() {
  # El "|| true" final evita que pipefail propague el exit 1 que grep emite
  # cuando cero líneas matchean (caso legítimo: §5 sin ningún path declarado,
  # p. ej. una spec mínima sin bloque de código — RNF-09 madre). Sin esto,
  # bajo el "set -euo pipefail" de scripts/route, ese exit 1 aborta el script
  # entero al asignarse en compute_score (s2=$(signal_s2 ...)) sin ningún
  # mensaje de error. Bug encontrado y corregido durante specs/0004
  # (session-gate), documentado en su §7 D9 — no cambia el conteo impreso,
  # sólo el exit status de la función.
  #
  # RF-01 de specs/0027 (amend fechado a 0002 RF-01 punto 4): S2 sólo cuenta
  # el árbol de entregables. Si §5 tiene un "### 5.1", el cuerpo a analizar
  # es desde esa línea hasta la siguiente "### " o el fin de §5; si no, todo
  # §5 (las fixtures de 0002 y las specs sin subsecciones siguen igual). El
  # recorte se aplica ANTES de recorrer fences: specs/0025 tiene un fence de
  # 4 backticks en su §5.2 que desordenaría el estado si se recorriera todo
  # §5 de una. Dentro del cuerpo recortado, sólo abren conteo los fences
  # cuya línea de apertura es exactamente ``` (sin info-string); un fence
  # con info-string (```yaml, ```diagrama, ```mermaid, ...) entra en "dentro
  # de fence" pero no cuenta, y su cierre pelado tampoco puede abrir un
  # conteo nuevo — por eso se llevan dos estados por separado: `infence`
  # (dentro/fuera de cualquier fence, alterna con cada línea ^```) y
  # `cuenta` (fijado sólo al abrir, verdadero sólo si esa apertura fue ```
  # pelado). Dentro de un fence que cuenta, las líneas de tabla (que
  # empiezan con "|") se descartan antes del filtro de "/" o extensión.
  section_body "$1" 5 | awk '
    { l[NR]=$0 }
    END {
      start=1; end=NR
      for (i=1;i<=NR;i++) if (l[i] ~ /^### 5\.1/) { start=i; end=NR;
        for (j=i+1;j<=NR;j++) if (l[j] ~ /^### /) { end=j-1; break }
        break }
      infence=0; cuenta=0
      for (i=start;i<=end;i++) { line=l[i]
        if (line ~ /^```/) { if (!infence) { infence=1; cuenta=(line ~ /^```[ \t]*$/) } else { infence=0; cuenta=0 } ; continue }
        if (infence && cuenta && line !~ /^\|/) print line
      }
    }' | grep -Ev '^[[:space:]]*(#.*)?$' | grep -E '/|\.[A-Za-z0-9]+$' | sort -u | wc -l | tr -d ' ' || true
}

signal_s3() {
  section_body "$1" 6 | grep -oE 'CA-[0-9]+' | sort -u | wc -l | tr -d ' '
}

signal_s4() {
  local file="$1" sec7 sec8 b_count pre_count post_count
  sec7="$(section_body "$file" 7)"
  sec8="$(section_body "$file" 8)"
  b_count=$(printf '%s\n' "$sec7" | grep -oE '^\*\*B-[0-9]+' | sed -E 's/^\*\*//' | sort -u | wc -l | tr -d ' ')
  pre_count=$(printf '%s\n' "$sec7" | awk '/^\*\*B-[0-9]+/{exit} {print}' | grep -o '\[SIN CONFIRMAR\]' | wc -l | tr -d ' ')
  post_count=$(printf '%s\n' "$sec8" | grep -o '\[SIN CONFIRMAR\]' | wc -l | tr -d ' ')
  echo $((b_count + pre_count + post_count))
}

signal_s5() {
  local loc
  loc="$(fm_int "$1" loc_estimate 0)"
  echo $(( (loc + 99) / 100 ))
}

# --- config/routing.yaml: pesos, umbrales, hard_exclusions ------------------

yaml_nested_field() {
  local file="$1" parent="$2" key="$3"
  awk -v p="$parent" -v k="$key" '
    $0 ~ "^"p":" { inp=1; next }
    inp && $0 ~ "^[ \t]+"k":" {
      v=$0; sub("^[ \t]+"k":[ \t]*", "", v); sub(/[ \t]*#.*/, "", v); gsub(/^"|"$/, "", v); print v; exit
    }
    inp && $0 !~ "^[ \t]" { inp=0 }
  ' "$file"
}

yaml_list_field() {
  local file="$1" key="$2"
  awk -v k="$key" '
    $0 ~ "^"k":" {
      line=$0; sub("^"k":[ \t]*", "", line); sub(/[ \t]*#.*/, "", line)
      if (line ~ /^\[/) {
        gsub(/^\[|\][ \t]*$/, "", line)
        n = split(line, arr, ",")
        for (i=1;i<=n;i++) { v=arr[i]; gsub(/^[ \t"]+|[ \t"]+$/, "", v); if (v!="") print v }
        exit
      }
      inlist=1; next
    }
    inlist && /^[[:space:]]*-/ {
      v=$0; sub(/^[[:space:]]*-[[:space:]]*/, "", v); sub(/[ \t]*#.*/, "", v); gsub(/^"|"$/, "", v); print v; next
    }
    inlist && /^[^[:space:]]/ { inlist=0 }
  ' "$file"
}

# --- score ---------------------------------------------------------------

# Imprime "score s1 s2 s3 s4 s5" en una línea.
compute_score() {
  local file="$1" cfg="$2"
  local s1 s2 s3 s4 s5 w1 w2 w3 w4 w5 score
  s1=$(signal_s1 "$file"); s2=$(signal_s2 "$file"); s3=$(signal_s3 "$file")
  s4=$(signal_s4 "$file"); s5=$(signal_s5 "$file")
  w1=$(yaml_nested_field "$cfg" weights S1); w1=${w1:-0}
  w2=$(yaml_nested_field "$cfg" weights S2); w2=${w2:-0}
  w3=$(yaml_nested_field "$cfg" weights S3); w3=${w3:-0}
  w4=$(yaml_nested_field "$cfg" weights S4); w4=${w4:-0}
  w5=$(yaml_nested_field "$cfg" weights S5); w5=${w5:-0}
  score=$(( s1*w1 + s2*w2 + s3*w3 + s4*w4 + s5*w5 ))
  printf '%s %s %s %s %s %s\n' "$score" "$s1" "$s2" "$s3" "$s4" "$s5"
}

# Imprime "TIER RULE" a partir del score y los umbrales de $cfg.
decide_from_score() {
  local score="$1" cfg="$2" ts tc
  ts=$(yaml_field "$cfg" threshold_simple)
  tc=$(yaml_field "$cfg" threshold_complex)
  if [ "$score" -ge "$tc" ]; then
    echo "B score-complex"
  elif [ "$score" -le "$ts" ]; then
    echo "A score-simple"
  else
    echo "B default-conservative"
  fi
}

# --- disparadores duros y hard_exclusions (RF-01.2/.3 de 0002) -------------

hard_trigger_rule() {
  local file="$1" sc arch tb sec7
  sc="$(fm_bool "$file" schema_change)"
  if [ "$sc" = "true" ]; then echo hard-schema-change; return 0; fi
  arch="$(fm_bool "$file" arch_decision)"
  if [ "$arch" = "true" ]; then echo hard-arch-decision; return 0; fi
  tb="$(fm_field "$file" target_branch)"
  if [ -n "$tb" ]; then
    # */spec-NNNN-*: rama que deriva `the worktree helper (not in this snapshot) new` (0039), p. ej.
    # "operator/spec-0045-tp-negocios-internacionales". Se trata
    # igual que spec/* y no dispara el hard trigger (0047).
    case "$tb" in
      personal/*|spec/*|sandbox/*|*/spec-[0-9][0-9][0-9][0-9]-*) : ;;
      *) echo hard-target-branch; return 0 ;;
    esac
  fi
  sec7="$(section_body "$file" 7)"
  if printf '%s' "$sec7" | grep -q '\[BLOQUEO EXTERNO\]'; then
    echo hard-external-block; return 0
  fi
  echo ""
}

# Imprime "source<TAB>patrón" y devuelve 0 si matchea; 1 si no matchea nada.
hard_exclusions_match() {
  local file="$1" cfg="$2" title alcance pat
  title="$(fm_title "$file")"
  alcance="$(section_body "$file" 2)"
  while IFS= read -r pat; do
    [ -z "$pat" ] && continue
    if printf '%s' "$title" | grep -qi -F -- "$pat"; then
      printf 'title\t%s\n' "$pat"; return 0
    fi
    if printf '%s' "$alcance" | grep -qi -F -- "$pat"; then
      printf 'alcance\t%s\n' "$pat"; return 0
    fi
  done < <(yaml_list_field "$cfg" hard_exclusions)
  return 1
}

# --- --force (RF-03 de 0002) ------------------------------------------------

apply_force() {
  local file="$1" tier="$2" reason="$3" today tmp tmp2
  today="$(date +%Y-%m-%d)"
  tmp="$(mktemp)"
  tmp2="$(mktemp)"

  awk -v tier="$tier" '
    BEGIN { infence=0; before_h1=1 }
    before_h1 && /^## 1\./ { before_h1=0 }
    before_h1 && infence && /^tier_locked:/ { print "tier_locked: " tier; next }
    before_h1 && infence && /^```[[:space:]]*$/ { infence=0; print; next }
    before_h1 && /^```yaml[[:space:]]*$/ { infence=1; print; next }
    { print }
  ' "$file" > "$tmp"

  awk -v today="$today" -v reason="$reason" '
    /^## §Historial/ { print; state=1; next }
    state==1 && /^[[:space:]]*$/ { print; next }
    state==1 {
      print today " — " reason " — manual-override"
      if ($0 !~ /^\*\(vacío/) { print }
      state=0
      next
    }
    { print }
  ' "$tmp" > "$tmp2"

  mv "$tmp2" "$file"
  rm -f "$tmp"
}

# --- --stats (RF-04 de 0002) ------------------------------------------------

json_str() {
  printf '%s' "$1" | grep -oE "\"$2\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | head -1 | sed -E 's/.*:[[:space:]]*"([^"]*)"/\1/'
}

json_num() {
  printf '%s' "$1" | grep -oE "\"$2\"[[:space:]]*:[[:space:]]*[0-9]+" | head -1 | sed -E 's/.*:[[:space:]]*//'
}

pct() {
  local num="$1" den="$2"
  if [ "$den" -eq 0 ]; then echo 0; return; fi
  echo $(( (num * 100 + den / 2) / den ))
}

run_stats() {
  local sessions="$1" specs_dir="$2"
  local total=0 tier_a=0 tier_b=0 esc_a=0 overroute_b=0
  local line tier outcome files_touched

  if [ -f "$sessions" ]; then
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      total=$((total + 1))
      tier=$(json_str "$line" tier)
      outcome=$(json_str "$line" outcome)
      files_touched=$(json_num "$line" files_touched)
      if [ "$tier" = "TIER_A" ]; then
        tier_a=$((tier_a + 1))
        [ "$outcome" = "escalated" ] && esc_a=$((esc_a + 1))
      elif [ "$tier" = "TIER_B" ]; then
        tier_b=$((tier_b + 1))
        if [ -n "$files_touched" ] && [ "$files_touched" -le 5 ]; then
          overroute_b=$((overroute_b + 1))
        fi
      fi
    done < "$sessions"
  fi

  local rework_num=0 rework_den=0 f status version
  if [ -d "$specs_dir" ]; then
    for f in "$specs_dir"/*.md; do
      [ -e "$f" ] || continue
      status="$(fm_field "$f" status)"
      version="$(fm_int "$f" version 1)"
      case "$status" in
        approved|implementing|verified|archived|superseded|discarded)
          rework_den=$((rework_den + 1))
          [ "$version" -gt 1 ] && rework_num=$((rework_num + 1))
          ;;
      esac
    done
  fi

  printf 'SPEC_STATS SESSIONS=%s TIER_A=%s TIER_B=%s TIER_A_PCT=%s TIER_B_PCT=%s ESCALATION_RATE=%s OVERROUTE_RATE=%s SPEC_REWORK_RATE=%s\n' \
    "$total" "$tier_a" "$tier_b" \
    "$(pct "$tier_a" "$total")" "$(pct "$tier_b" "$total")" \
    "$(pct "$esc_a" "$tier_a")" "$(pct "$overroute_b" "$tier_b")" \
    "$(pct "$rework_num" "$rework_den")"
}
