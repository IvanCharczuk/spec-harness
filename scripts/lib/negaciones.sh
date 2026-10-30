#!/usr/bin/env bash
# RF-01 de 0100 (negaciones que no cortan en los CA).
# negaciones_sueltas <spec>: líneas `! cmd` de un `cmd: |` de §6 que no son
# la última y no cortan el check (bajo `set -e` un `! cmd` no dispara).
# Heurística de texto (RNF-01): awk/grep/coreutils, bash 3.2. Sólo lee.
_NEG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$_NEG_DIR/common.sh"
# shellcheck source=spec.sh
source "$_NEG_DIR/spec.sh"
# shellcheck source=verify.sh
source "$_NEG_DIR/verify.sh"

# Imprime "<línea><TAB><CA-NN><TAB><texto>" por caso, nada si no hay.
negaciones_sueltas() {
  local file="$1" fid line ca text sup
  fid="$(fm_field "$file" id 2>/dev/null || true)"
  [ -n "$fid" ] || fid="$(basename "$file" | grep -oE '^[0-9]{4}' || true)"
  awk '
    function flush(   i, t, s, last) {
      last = 0
      for (i = 1; i <= n; i++) if (txt[i] ~ /[^ \t]/) last = i
      for (i = 1; i < last; i++) {
        t = txt[i]; s = t
        sub(/^[ \t]*/, "", s)
        if (s !~ /^! /) continue
        if (s ~ /(\\|&&|\|\||\|)[ \t]*$/) continue
        if (index(s, "||") > 0 || index(s, "$?") > 0) continue
        printf "%d\t%s\t%s\n", num[i], ca, t
      }
      n = 0; inblk = 0
    }
    /^## 6\./ { in6 = 1; next }
    /^## [0-9]+\./ { if (in6) { flush(); in6 = 0 } next }
    !in6 { next }
    /^- \*\*CA-[0-9]+\*\*/ {
      flush()
      match($0, /CA-[0-9]+/); ca = substr($0, RSTART, RLENGTH); next
    }
    inblk {
      match($0, /^[ \t]*/)
      if ($0 ~ /^[ \t]*```/ || ($0 ~ /[^ \t]/ && RLENGTH <= cmdind)) { flush() }
      else { n++; txt[n] = $0; num[n] = NR; next }
    }
    /^[ \t]*cmd:[ \t]*\|[ \t]*$/ {
      match($0, /^[ \t]*/); cmdind = RLENGTH; inblk = 1; n = 0; next
    }
    END { flush() }
  ' "$file" | while IFS="$(printf '\t')" read -r line ca text; do
    sup="$(ca_superado_check "$file" "$fid" "$ca")"
    case "$sup" in SUPERADO*) continue ;; esac
    printf '%s\t%s\t%s\n' "$line" "$ca" "$text"
  done
}
