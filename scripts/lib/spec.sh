#!/usr/bin/env bash
# Helpers de parsing de spec (front-matter y secciones) y de resolución de
# id/ruta de spec. Compartido por scripts/route (vía lib/routing.sh, que
# sourcea este archivo) y scripts/spec (RF-02, RF-03, RF-08, RF-10.3 de
# spec 0003 (not in this snapshot)). Movido desde lib/routing.sh por 0003 —
# el contrato de estas funciones no cambia, sólo su ubicación (ver
# spec 0003 (not in this snapshot) §7 D1).
# RNF-01 (0003) / RNF-02 (0002): sólo awk/grep/coreutils, sin jq/python/node.
# shellcheck source=common.sh
# (asume que common.sh ya fue sourceado por el caller, para yaml_field_stdin y REPO_ROOT)

# --- front-matter (maneja specs con y sin bloque ```yaml) --------------------

# Imprime el contenido crudo del primer bloque ```yaml...``` que aparezca
# antes de la primera línea "## 1." del documento. Si no existe (specs sin
# front-matter, ej. specs/0001-repo-maestro.md), no imprime nada.
fm_block() {
  local file="$1"
  awk '
  {
    if (/^## 1\./) { exit }
    if (infence) {
      if (/^```[[:space:]]*$/) { exit }
      print
      next
    }
    if (/^```yaml[[:space:]]*$/) { infence=1 }
  }
  ' "$file"
}

fm_field() {
  local file="$1" key="$2"
  fm_block "$file" | yaml_field_stdin "$key"
}

# --- secciones (funciona igual con o sin front-matter: sólo mira headings) --

# Cuerpo crudo de "## <n>. ..." hasta el próximo "## <dígito>" o "## §...".
section_body() {
  local file="$1" n="$2"
  awk -v n="$n" '
    $0 ~ "^## " n "\\." { insec=1; next }
    insec && /^## [0-9]/ { exit }
    insec && /^## §/ { exit }
    insec { print }
  ' "$file"
}

# --- mutación de front-matter (RF-04 de spec 0003 (not in this snapshot)) -------

# Reescribe "key: value" dentro del bloque ```yaml de front-matter (antes de
# "## 1."), preservando el resto del archivo. Técnica análoga a la de
# apply_force() en routing.sh, pero genérica para cualquier campo — función
# nueva de 0003, no comparte código con apply_force para no ampliar el
# refactor de D1 más allá de lo acordado.
fm_set_field() {
  local file="$1" key="$2" value="$3" tmp
  tmp="$(mktemp)"
  awk -v key="$key" -v value="$value" '
    BEGIN { infence=0; before_h1=1 }
    before_h1 && /^## 1\./ { before_h1=0 }
    before_h1 && infence && $0 ~ "^"key":" { print key ": " value; next }
    before_h1 && infence && /^```[[:space:]]*$/ { infence=0; print; next }
    before_h1 && /^```yaml[[:space:]]*$/ { infence=1; print; next }
    { print }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
}

# --- resolución de id/ruta de spec -------------------------------------------

resolve_spec() {
  local arg="$1" match
  case "$arg" in
    */*|*.md)
      echo "$arg" ;;
    *)
      match=$(ls "$REPO_ROOT"/specs/"$arg"-*.md 2>/dev/null | head -1)
      [ -z "$match" ] && return 1
      echo "$match" ;;
  esac
}
