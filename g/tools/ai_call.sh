#!/usr/bin/env bash
# ai_call.sh — helper to invoke external AI connectors from shell tooling.

set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: ai_call.sh <model> <prompt>

MODEL examples:
  gemini            Route through the Gemini connector.

PROMPT is treated as the raw text payload to send to the connector.
USAGE
}

MODEL="${1:-}"
shift || true
PROMPT="$*"

if [[ -z "$MODEL" || -z "$PROMPT" ]]; then
  usage >&2
  exit 2
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SOT_PATH="${SOT_PATH:-$ROOT_DIR}"

case "$MODEL" in
  gemini)
    python3 "$SOT_PATH/g/connectors/gemini_connector.py" "$PROMPT"  # AICALL_GEMINI_V1
    ;;
  *)
    echo "Unsupported model: $MODEL" >&2
    exit 65
    ;;
esac
