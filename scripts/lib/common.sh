#!/usr/bin/env bash
# Helpers compartidos por scripts/bootstrap y scripts/doctor.
# RNF-06: Bash POSIX-compatible, set -euo pipefail en cada script que lo sourcea.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Rango de Node de RNF-01: ^22.19.0 || >=24.0.0
# Cubre 22.19+ y 24+; excluye 22.<19 y todo 23.x (el hueco del rango).
check_node_range() {
  if ! command -v node >/dev/null 2>&1; then
    echo "node no encontrado en PATH" >&2
    return 1
  fi
  local v major rest minor
  v="$(node --version)"
  v="${v#v}"
  major="${v%%.*}"
  rest="${v#*.}"
  minor="${rest%%.*}"
  if { [ "$major" -eq 22 ] && [ "$minor" -ge 19 ]; } || [ "$major" -ge 24 ]; then
    return 0
  fi
  return 1
}

node_version_string() {
  node --version 2>/dev/null || echo "no instalado"
}

# Extrae "clave: valor" de un YAML plano (sin anidamiento) de config/profiles/*.yaml.
# Uso: yaml_field <archivo> <clave>
yaml_field() {
  local file="$1" key="$2"
  [ -f "$file" ] || return 1
  awk -F': ' -v k="$key" '
    $0 ~ "^"k":" { val=$0; sub("^"k": *", "", val); sub(/[[:space:]]*#.*/, "", val); gsub(/^"|"$/, "", val); print val; exit }
  ' "$file"
}

# Extrae un campo simple del front-matter YAML de una spec (entre las dos primeras
# líneas "---"). Si el archivo no tiene front-matter real, no imprime nada.
spec_frontmatter_field() {
  local file="$1" key="$2"
  [ -f "$file" ] || return 1
  head -1 "$file" | grep -q '^---$' || return 0
  awk 'NR==1{next} /^---$/{exit} {print}' "$file" | yaml_field_stdin "$key"
}

yaml_field_stdin() {
  local key="$1"
  awk -F': ' -v k="$key" '
    $0 ~ "^"k":" { val=$0; sub("^"k": *", "", val); sub(/[[:space:]]*#.*/, "", val); gsub(/^"|"$/, "", val); print val; exit }
  '
}

print_pass() { printf '[PASS] %s\n' "$1"; }
print_fail() { printf '[FAIL] %s\n' "$1"; }

write_if_missing() {
  local path="$1"
  if [ -e "$path" ]; then
    echo "  ya existe, se deja igual: $path"
    # Consumir el heredoc del caller sin usarlo, para no dejarlo colgado.
    cat >/dev/null
    return 0
  fi
  mkdir -p "$(dirname "$path")"
  cat > "$path"
  echo "  creado: $path"
  return 0
}

# --- RF-01 de spec 0009 (not in this snapshot): lógica compartida entre
# scripts/doctor (checks 5/10) y .githooks/{pre-commit,commit-msg} -----------

# RF-10.1 madre exige el trailer para commits que tocan "código o
# config", no cualquier archivo fuera de specs/ — docs/ (y cualquier
# otro directorio puramente documental) queda explícitamente afuera del
# disparador. Mismo criterio ya corregido en scripts/doctor (ba9aea0),
# movido acá tal cual — sin efectos de filesystem, sólo evalúa el string
# del path recibido.
is_code_or_config_path() {
  case "$1" in
    specs/*|docs/*) return 1 ;;
    *) return 0 ;;
  esac
}

# Recibe paths por stdin, uno por línea (cualquier fuente — no asume
# git ls-files ni ningún otro origen). Imprime a stdout los que
# matchean el patrón heurístico de credenciales. Sin mktemp, sin
# escritura a ningún archivo — sólo lee los archivos que se le pasan.
scan_credential_hits() {
  local cred_patterns='BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY|sk-ant-[a-zA-Z0-9-]+|sk-[a-zA-Z0-9]{20,}|api[_-]?key[[:space:]]*[:=][[:space:]]*[^ ]+|AKIA[0-9A-Z]{16}'
  local f
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    [ -f "$f" ] || continue
    grep -lE "$cred_patterns" "$f" 2>/dev/null || true
  done
}
