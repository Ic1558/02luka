#!/usr/bin/env zsh
set -euo pipefail

# Usage:
#   zsh tools/catalog_lookup.zsh <alias> [--catalog <path>]
#
# Output:
#   prints the script path from tools/CATALOG.md that matches the alias.

alias_name="${1:-}"
shift || true

catalog_path="tools/CATALOG.md"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --catalog)
      catalog_path="${2:-}"
      shift 2
      ;;
    *)
      echo "ERROR: unknown arg: $1" >&2
      exit 2
      ;;
  esac
done

if [[ -z "${alias_name}" ]]; then
  echo "ERROR: alias required" >&2
  exit 2
fi

if [[ ! -f "${catalog_path}" ]]; then
  echo "ERROR: catalog not found: ${catalog_path}" >&2
  exit 2
fi

# Parse markdown tables:
# - Find rows like: | alias | ... | tools/something.zsh |
# - Accept the first cell as alias, and the first cell that looks like tools/* as script path.
# - Skip header separator lines.
found_path="$(
  awk -v want="${alias_name}" '
    function trim(s){ gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
    BEGIN{ IGNORECASE=1 }
    /^\|/ {
      line=$0
      # skip separator rows like | --- | --- |
      if (line ~ /^\|[[:space:]]*[-:]+[[:space:]]*\|/) next

      # split by |
      n=split(line, a, "|")
      # a[1] is empty (before first |)
      # a[2] is first cell
      alias=trim(a[2])
      if (tolower(alias) != tolower(want)) next

      # find a cell that looks like a path under tools/
      for (i=3; i<=n; i++) {
        cell=trim(a[i])
        if (cell ~ /^tools\/[A-Za-z0-9._\/-]+$/) { print cell; exit 0 }
      }

      # fallback: maybe second cell is the path
      for (i=2; i<=n; i++) {
        cell=trim(a[i])
        if (cell ~ /^tools\/[A-Za-z0-9._\/-]+$/) { print cell; exit 0 }
      }
    }
  ' "${catalog_path}"
)"

if [[ -z "${found_path}" ]]; then
  echo "ERROR: alias not found in catalog: ${alias_name}" >&2
  exit 3
fi

print -r -- "${found_path}"
