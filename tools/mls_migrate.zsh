#!/usr/bin/env zsh
set -euo pipefail

print_usage() {
  cat <<'HELP'
mls_migrate.zsh — MLS (Memory/Log/Status) migration helper

USAGE:
  tools/mls_migrate.zsh [--plan] [--apply] [--src <dir>] [--dst <dir>]

OPTIONS:
  --plan           Dry-run; print the actions that would be taken.
  --apply          Execute the migration (requires --src and --dst).
  --src <dir>      Source directory (e.g. run/context_cache).
  --dst <dir>      Destination directory (e.g. memory/).

NOTES:
  • This is a scaffold replacement because the original script content was overwritten.
  • It performs only safe checks until you pass --apply with explicit src/dst.
  • Customize the MOVE_LIST below to match the repo layout once confirmed.

EXITS:
  0 on success, 1 on usage error, 2 if running in plan-only mode, >=3 on operational errors.
HELP
}

# Defaults
PLAN=0
APPLY=0
SRC=""
DST=""

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --plan) PLAN=1; shift ;;
    --apply) APPLY=1; shift ;;
    --src) SRC="${2:-}"; shift 2 ;;
    --dst) DST="${2:-}"; shift 2 ;;
    -h|--help) print_usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; print_usage; exit 1 ;;
  esac
done

# Safety checks
if [[ "$APPLY" -eq 1 && ( -z "${SRC}" || -z "${DST}" ) ]]; then
  echo "ERROR: --apply requires both --src and --dst" >&2
  exit 1
fi

if [[ -n "${SRC}" && ! -d "${SRC}" ]]; then
  echo "ERROR: SRC not found: ${SRC}" >&2
  exit 3
fi
if [[ -n "${DST}" && ! -d "${DST}" ]]; then
  echo "ERROR: DST not found: ${DST}" >&2
  exit 3
fi

# Example planned moves (edit to taste)
MOVE_LIST=()
[[ -n "${SRC}" && -n "${DST}" ]] && MOVE_LIST+=("${SRC}/context_cache:${DST}/context_cache")
[[ -n "${SRC}" && -n "${DST}" ]] && MOVE_LIST+=("${SRC}/context_metrics:${DST}/context_metrics")

if [[ "${#MOVE_LIST[@]}" -eq 0 ]]; then
  echo "No actions — provide --src and --dst to plan/apply." >&2
  exit 2
fi

echo "== PLAN =="
for pair in "${MOVE_LIST[@]}"; do
  src_dir="${pair%%:*}"
  dst_dir="${pair##*:}"
  echo "Would sync: ${src_dir}  →  ${dst_dir}"
done

if [[ "$PLAN" -eq 1 && "$APPLY" -eq 0 ]]; then
  exit 2
fi

if [[ "$APPLY" -eq 1 ]]; then
  for pair in "${MOVE_LIST[@]}"; do
    src_dir="${pair%%:*}"
    dst_dir="${pair##*:}"
    mkdir -p "${dst_dir}"
    rsync -a --info=NAME,STATS2 "${src_dir}/" "${dst_dir}/"
  done
  echo "Migration completed."
fi
