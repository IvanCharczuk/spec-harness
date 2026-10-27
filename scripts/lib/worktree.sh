#!/usr/bin/env bash
# RF-01 de spec 0037 (not in this snapshot);
# RF-04/RF-05/RF-07 de spec 0039 (not in this snapshot).
# Funciones compartidas por scripts/tmux-spec y the worktree helper (not in this snapshot) new:
# ninguna tiene efectos al sourcearse (sólo definen funciones). La mayoría
# sólo lee git y el filesystem; la excepción es wt_reservar (RF-07), que sí
# escribe: toma un lock atómico con mkdir, agrega una línea a
# sessions/ids-reservados.jsonl en el working tree de wt_main y la
# commitea ahí (sólo ese archivo, sin tocar el resto del working tree).
# RNF-02/CA-09: nada de flags ni comandos destructivos acá (ni forzar un
# borrado, ni un borrado recursivo), ni siquiera mencionados en comentarios.
# shellcheck source=common.sh
# (asume que common.sh ya fue sourceado por el caller, para REPO_ROOT)

# --- wt_main: checkout principal --------------------------------------------

# Primer "worktree " de `git worktree list --porcelain`, sea cual sea el
# worktree desde el que se corra (todos comparten el mismo .git).
# awk lee toda la salida: un exit temprano cierra el pipe y, con muchos
# worktrees, git muere por SIGPIPE (141 bajo pipefail; spec 0082 RF-01).
wt_main() {
  git worktree list --porcelain | awk '!m && /^worktree /{m=substr($0, 10)} END{print m}'
}

# --- wt_path: path del worktree hermano de una spec -------------------------

# $(dirname MAIN)/$(basename MAIN)-<id> — p. ej. desde
# ~/repo-maestro, wt_path 0037 da ~/repo-maestro-0037.
wt_path() {
  local id="$1" main
  main="$(wt_main)"
  printf '%s/%s-%s\n' "$(dirname "$main")" "$(basename "$main")" "$id"
}

# --- wt_next_id: reserva de id ------------------------------------------------

# max + 1 a cuatro dígitos, con max = el mayor id entre:
#   (a) specs/NNNN-*.md de MAIN
#   (b) ramas locales y remotas ya conocidas spec/NNNN-* (sin fetch)
#   (c) worktrees registrados cuyo path termina en -NNNN
#   (b') RF-04 de 0039: cualquier ref (local o remota) con "spec-NNNN-" o
#        "spec/NNNN-" después de un "/" o al inicio de la rama — la forma
#        que usa Orca, que antepone su propio prefijo (D3 de 0039)
#   (c') RF-04 de 0039: worktrees cuyo path tenga un segmento que empiece
#        con "spec-NNNN-", no sólo al final como en (c)
#   (d) RF-04/RF-07 de 0039: ids de sessions/ids-reservados.jsonl, leídos
#        del working tree de MAIN, de refs/heads/main y de
#        refs/remotes/*/main (reservas ya hechas en otra máquina, traídas
#        con fetch pero no fusionadas a esta rama — ver D4 de 0039)
# Aritmética con base 10 explícita ("10#") porque '0008'/'0009' son
# octales inválidos en bash.
wt_next_id() {
  local main max=0 v

  main="$(wt_main)"

  # (a) specs/NNNN-*.md de MAIN
  while IFS= read -r v; do
    [ -n "$v" ] || continue
    v=$((10#$v))
    [ "$v" -gt "$max" ] && max="$v"
  done < <(ls "$main"/specs/*.md 2>/dev/null | xargs -n1 basename 2>/dev/null | grep -oE '^[0-9]{4}' || true)

  # (b) ramas locales y remotas ya conocidas spec/NNNN-* (sin fetch: sólo
  # mira refs/remotes/* ya presentes)
  while IFS= read -r v; do
    [ -n "$v" ] || continue
    v=$((10#$v))
    [ "$v" -gt "$max" ] && max="$v"
  done < <(git for-each-ref --format='%(refname)' refs/heads/spec/ 'refs/remotes/*/spec/*' 2>/dev/null \
              | grep -oE 'spec/[0-9]{4}-' | grep -oE '[0-9]{4}' || true)

  # (c) worktrees registrados cuyo path termina en -NNNN (falso positivo
  # aceptado: un path ajeno que termine en -NNNN también cuenta — ver §7 RF-01)
  while IFS= read -r v; do
    [ -n "$v" ] || continue
    v=$((10#$v))
    [ "$v" -gt "$max" ] && max="$v"
  done < <(git worktree list --porcelain | awk '/^worktree /{print $2}' | grep -oE '[0-9]{4}$' || true)

  # (b') refs (locales o remotas) con forma de Orca: "spec-NNNN-" o
  # "spec/NNNN-" después de un "/" o al inicio del nombre de la rama, sin
  # acotar el prefijo a "refs/heads/spec/" como en (b) — Orca antepone su
  # propio prefijo de usuario de GitHub (p. ej.
  # "refs/heads/operator/spec-0039-x"). No da falso positivo
  # con algo como "notspec-0005-x": exige el "/" justo antes de "spec".
  while IFS= read -r v; do
    [ -n "$v" ] || continue
    v=$((10#$v))
    [ "$v" -gt "$max" ] && max="$v"
  done < <(git for-each-ref --format='%(refname)' refs/heads refs/remotes 2>/dev/null \
              | grep -oE '/spec[-/][0-9]{4}-' | grep -oE '[0-9]{4}' || true)

  # (c') worktrees cuyo path tenga un segmento que empiece con
  # "spec-NNNN-" en cualquier posición, no sólo al final del path como en
  # (c) — la forma de Orca (p. ej. ".../spec-0039-prueba-ca-11"). No cuenta
  # algo como ".../myspec-0005-x": exige el "/" justo antes de "spec".
  while IFS= read -r v; do
    [ -n "$v" ] || continue
    v=$((10#$v))
    [ "$v" -gt "$max" ] && max="$v"
  done < <(git worktree list --porcelain | awk '/^worktree /{print $2}' | grep -oE '/spec-[0-9]{4}-' | grep -oE '[0-9]{4}' || true)

  # (d) ids reservados en sessions/ids-reservados.jsonl (RF-07): puede
  # existir sólo en el working tree de MAIN (reserva recién hecha, todavía
  # sin push desde acá), en la punta de refs/heads/main, o en
  # refs/remotes/*/main (ya traído con fetch pero no fusionado a esta
  # rama). Cada fuente se guarda con "|| true" propio: bajo un caller con
  # "set -e", que una de las tres no exista es el caso normal, no un error
  # (mismo motivo que el resto de esta función).
  while IFS= read -r v; do
    [ -n "$v" ] || continue
    v=$((10#$v))
    [ "$v" -gt "$max" ] && max="$v"
  done < <(
    {
      if [ -f "$main/sessions/ids-reservados.jsonl" ]; then
        cat "$main/sessions/ids-reservados.jsonl"
      fi
      git show refs/heads/main:sessions/ids-reservados.jsonl 2>/dev/null || true
      for ref in $(git for-each-ref --format='%(refname)' 'refs/remotes/*/main' 2>/dev/null); do
        git show "$ref:sessions/ids-reservados.jsonl" 2>/dev/null || true
      done
    } | grep -oE '"id":"[0-9]{4}"' | grep -oE '[0-9]{4}' || true
  )

  printf '%04d\n' $((max + 1))
}

# --- wt_branch_slug: slug de rama a partir de un título ----------------------

# Título hasta el primer ':' (o entero si no hay ':'), con la misma
# normalización que cmd_new en scripts/spec (minúsculas, sin tildes/ñ/ü,
# [^a-z0-9]+ -> '-', recorte de guiones en los bordes); recortado a 40
# caracteres y con el guión final (si el corte cayó justo ahí) quitado de
# nuevo. Puede devolver vacío si el título normalizado queda vacío (p. ej.
# "¿?"); el caller decide qué hacer con eso (no es esta función la que corta
# la ejecución: se mantiene pura).
wt_branch_slug() {
  local title="$1" head slug

  head="${title%%:*}"

  slug="$(printf '%s' "$head" | tr '[:upper:]' '[:lower:]')"
  slug="$(printf '%s' "$slug" | sed -e 's/á/a/g' -e 's/é/e/g' -e 's/í/i/g' -e 's/ó/o/g' -e 's/ú/u/g' -e 's/ñ/n/g' -e 's/ü/u/g')"
  slug="$(printf '%s' "$slug" | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')"

  slug="${slug:0:40}"
  slug="$(printf '%s' "$slug" | sed -E 's/-+$//')"

  printf '%s' "$slug"
}

# --- wt_reservar: reserva de un id en main (RF-07 de 0039) -------------------

# wt_reservar <id> <rama> <titulo>
#
# Pensada para correr desde el checkout principal, después de calcular
# <id> con wt_next_id y antes de crear el worktree nuevo (orca-spec/
# tmux-spec new). Toma un lock atómico (mkdir en el .git común, compartido
# por el checkout principal y todos sus worktrees — D5 de 0039), revalida
# <id> bajo lock con un wt_next_id fresco (otra sesión pudo reservar en el
# medio), agrega una línea a sessions/ids-reservados.jsonl en el working
# tree de wt_main y la commitea ahí — "git add" + "git commit --only --"
# sobre ese único path, así queda afuera cualquier otro cambio sin
# commitear del working tree de main — y libera el lock.
#
# El commit usa "Spec-Id: none" / "Spec-Id-Reason: ...": una reserva de id
# todavía no tiene una spec creada (specs/<id>-*.md no existe hasta que
# "rmaestro new" corre en el worktree nuevo), así que no hay un Spec-Id
# real para poner en el trailer que exige .githooks/commit-msg.
#
# Sale:
#   3 si no consigue el lock en $WT_LOCK_TIMEOUT segundos (default 30) —
#     el mensaje va con la ruta del lock, para poder borrarlo a mano si
#     quedó huérfano (D5 de 0039);
#   4 si al revalidar bajo lock el id ya no es el siguiente disponible
#     (el caller puede reintentar con un wt_next_id fresco);
#   1 si el commit falla.
# En cualquier salida propia (3, 4, 1 o éxito) libera el lock: nunca lo
# deja tomado al retornar.
wt_reservar() {
  local id="$1" rama="$2" titulo="$3"
  local git_common lockdir timeout waited=0

  git_common="$(git rev-parse --git-common-dir)"
  lockdir="$git_common/repo-maestro-reserva.lock"
  timeout="${WT_LOCK_TIMEOUT:-30}"

  until mkdir "$lockdir" 2>/dev/null; do
    if [ "$waited" -ge "$timeout" ]; then
      echo "no se pudo tomar el lock de reserva ($lockdir); si quedó huérfano de una corrida anterior, se borra a mano" >&2
      return 3
    fi
    sleep 1
    waited=$((waited + 1))
  done

  local expected
  expected="$(wt_next_id)"
  if [ "$expected" != "$id" ]; then
    rmdir "$lockdir" 2>/dev/null || true
    echo "el id $id ya no es el siguiente disponible (otra sesión reservó primero; ahora es $expected) — recalculá e intentá de nuevo" >&2
    return 4
  fi

  local main file reservado_at host esc_rama esc_titulo
  main="$(wt_main)"
  file="$main/sessions/ids-reservados.jsonl"
  reservado_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  host="$(hostname -s 2>/dev/null || uname -n)"

  # JSON armado a mano: escapa backslash antes que comilla doble (si no,
  # el escape de la comilla se re-escaparía a sí mismo).
  esc_rama="$(printf '%s' "$rama" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')"
  esc_titulo="$(printf '%s' "$titulo" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')"

  printf '{"id":"%s","rama":"%s","titulo":"%s","reservado_at":"%s","host":"%s"}\n' \
    "$id" "$esc_rama" "$esc_titulo" "$reservado_at" "$host" >> "$file"

  if ! (
    cd "$main" \
      && git add -- sessions/ids-reservados.jsonl \
      && git commit --only --quiet \
           -m "reserva: id $id ($rama)" \
           -m "Spec-Id: none" \
           -m "Spec-Id-Reason: reserva de id de sesión nueva (RF-07 de spec 0039 (not in this snapshot)); todavía no existe una spec para ese id" \
           -- sessions/ids-reservados.jsonl
  ); then
    rmdir "$lockdir" 2>/dev/null || true
    echo "no se pudo commitear la reserva del id $id en $main" >&2
    return 1
  fi

  local short
  short="$(cd "$main" && git rev-parse --short HEAD)"
  rmdir "$lockdir" 2>/dev/null || true

  echo "reservado $id en main ($short); corré git push para que lo vea la otra máquina" >&2
}

# --- wt_bloquear_push: deny de git push en un worktree ------------------------

# RF-03 de spec 0052 (not in this snapshot).
# Agrega "Bash(git push *)" al permissions.deny de <ruta>/.claude/settings.local.json
# (git-ignorado). Conserva el resto de las claves, crea el archivo si falta e
# es idempotente.
wt_bloquear_push() {
  local ruta="${1:?wt_bloquear_push: falta la ruta}"
  mkdir -p "$ruta/.claude"
  node -e '
const fs = require("fs");
const f = process.argv[1];
let s = {};
if (fs.existsSync(f)) {
  const raw = fs.readFileSync(f, "utf8").trim();
  if (raw) s = JSON.parse(raw);
}
s.permissions = s.permissions || {};
s.permissions.deny = s.permissions.deny || [];
const r = "Bash(git push *)";
if (!s.permissions.deny.includes(r)) s.permissions.deny.push(r);
fs.writeFileSync(f, JSON.stringify(s, null, 2) + "\n");
' "$ruta/.claude/settings.local.json"
}
