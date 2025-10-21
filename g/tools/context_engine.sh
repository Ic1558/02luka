#!/usr/bin/env bash
# context_engine.sh — Context aggregation entrypoint (Phase-1 safe rollout)
# Version: 6.0
# Environment Flags:
#   AUTO_PRUNE=1        # enable readiness for automated pruning (disabled in safe mode)
#   ADVANCED_FEATURES=1 # surface advanced routing toggles downstream
# Default behaviour: pass-through (no prune, no format mutation)

set -euo pipefail

SCRIPT_NAME="context_engine"
VERSION="6.0"

AUTO_PRUNE="${AUTO_PRUNE:-1}"
ADVANCED_FEATURES="${ADVANCED_FEATURES:-1}"

usage() {
  cat <<'USAGE'
Usage: context_engine.sh [--input PATH] [--output PATH] [--version] [--help]

Phase-1 safe mode leaves content untouched. Future phases may enable
selective pruning/formatting once validated.
USAGE
}

log_info() {
  printf '[v6] %s\n' "$*" >&2
}

INPUT_PATH="/dev/stdin"
OUTPUT_PATH="/dev/stdout"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --input|-i)
      shift
      [[ $# -gt 0 ]] || { echo "--input requires a path" >&2; exit 2; }
      INPUT_PATH="$1"
      ;;
    --output|-o)
      shift
      [[ $# -gt 0 ]] || { echo "--output requires a path" >&2; exit 2; }
      OUTPUT_PATH="$1"
      ;;
    --version)
      echo "$SCRIPT_NAME/$VERSION"
      exit 0
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    --prune|--format)
      log_info "Flag $1 acknowledged but inactive in Phase-1 safe mode"
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift || true
done

log_info "Starting $SCRIPT_NAME v$VERSION (AUTO_PRUNE=$AUTO_PRUNE, ADVANCED_FEATURES=$ADVANCED_FEATURES)"

if [[ "$INPUT_PATH" != "/dev/stdin" && ! -f "$INPUT_PATH" ]]; then
  echo "Input not found: $INPUT_PATH" >&2
  exit 66
fi

# Safe-mode passthrough — copies input to output without mutation
# Use atomic write for regular files (not stdout)
if [[ "$OUTPUT_PATH" != "/dev/stdout" ]]; then
  tmp_output="$(mktemp "${TMPDIR:-/tmp}/02luka-export.XXXXXX")"
  if ! cat "$INPUT_PATH" > "$tmp_output"; then
    rm -f "$tmp_output"
    echo "Failed to copy context payload" >&2
    exit 70
  fi
  mv "$tmp_output" "$OUTPUT_PATH"
else
  # Direct passthrough for stdout
  if ! cat "$INPUT_PATH" > "$OUTPUT_PATH"; then
    echo "Failed to copy context payload" >&2
    exit 70
  fi
fi

log_info "Completed safe pass-through"
