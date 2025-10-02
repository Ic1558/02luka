#!/usr/bin/env bash
# Validate mapping.json for schema, relative paths, and backing directories.

set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: mapping_drift_guard.sh [--validate] [--explain]

--validate   Run mapping validation checks (default action)
--explain    Print validation summary/details
USAGE
}

EXPLAIN=0
ACTION="validate"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --validate)
      ACTION="validate"
      ;;
    --explain)
      EXPLAIN=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 64
      ;;
  esac
  shift
 done

if [[ "$ACTION" != "validate" ]]; then
  echo "Unknown action: $ACTION" >&2
  exit 64
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required" >&2
  exit 127
fi

# Determine repository root.
if [[ -n "${SOT_PATH:-}" && -d "$SOT_PATH" ]]; then
  ROOT="$SOT_PATH"
elif git rev-parse --show-toplevel >/dev/null 2>&1; then
  ROOT="$(git rev-parse --show-toplevel)"
else
  ROOT="$(pwd)"
fi

MAP="$ROOT/f/ai_context/mapping.json"

if [[ ! -f "$MAP" ]]; then
  echo "ERROR: mapping.json missing at $MAP" >&2
  exit 127
fi

# Collect errors for reporting.
errors=()

# Ensure required schema elements.
VERSION=$(jq -er '.version' "$MAP" 2>/dev/null || true)
if [[ -z "${VERSION:-}" ]]; then
  errors+=("missing .version")
fi

REQUIRED_NAMESPACES=(human bridge reports status)
for ns in "${REQUIRED_NAMESPACES[@]}"; do
  if ! jq -e ".namespaces.$ns" "$MAP" >/dev/null; then
    errors+=("missing namespace: $ns")
  fi
 done

# Define expected keys and whether they should point to directories.
declare -A EXPECTED
EXPECTED["human:dropbox"]=dir
EXPECTED["human:outbox"]=dir
EXPECTED["human:inbox"]=dir
EXPECTED["human:sent"]=dir
EXPECTED["human:deliverables"]=dir
EXPECTED["bridge:inbox"]=dir
EXPECTED["bridge:outbox"]=dir
EXPECTED["bridge:processed"]=dir
EXPECTED["reports:system"]=dir
EXPECTED["reports:runtime"]=dir
EXPECTED["status:system"]=file
EXPECTED["status:tickets"]=dir

resolve_value() {
  local ns_key=$1
  local ns=${ns_key%%:*}
  local key=${ns_key##*:}
  jq -r --arg ns "$ns" --arg key "$key" '.namespaces[$ns][$key] // empty' "$MAP"
}

for nk in "${!EXPECTED[@]}"; do
  value=$(resolve_value "$nk")
  if [[ -z "$value" || "$value" == "null" ]]; then
    errors+=("missing mapping value for $nk")
    continue
  fi

  if [[ "$value" == /* ]]; then
    errors+=("$nk must be relative, found absolute: $value")
  fi

  type=${EXPECTED[$nk]}
  case "$type" in
    dir)
      if [[ "${value: -1}" != "/" ]]; then
        errors+=("$nk directory must end with / (found $value)")
      fi
      abs="$ROOT/$value"
      if [[ ! -d "$abs" ]]; then
        errors+=("$nk directory missing: $abs")
      fi
      ;;
    file)
      if [[ "${value: -1}" == "/" ]]; then
        errors+=("$nk file should not end with / (found $value)")
      fi
      abs="$ROOT/$value"
      if [[ ! -f "$abs" ]]; then
        errors+=("$nk file missing: $abs")
      fi
      ;;
    *)
      errors+=("unknown expected type for $nk")
      ;;
  esac
 done

if [[ ${#errors[@]} -gt 0 ]]; then
  if [[ $EXPLAIN -eq 1 ]]; then
    printf 'mapping validation FAILED:\n' >&2
    for err in "${errors[@]}"; do
      printf ' - %s\n' "$err" >&2
    done
  else
    for err in "${errors[@]}"; do
      printf '%s\n' "$err" >&2
    done
  fi
  exit 1
fi

if [[ $EXPLAIN -eq 1 ]]; then
  echo "mapping validation OK"
fi

exit 0
