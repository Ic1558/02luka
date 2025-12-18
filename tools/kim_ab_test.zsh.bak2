#!/usr/bin/env zsh
set -euo pipefail

if (( $# == 0 )); then
  echo "Usage: $0 <question>" >&2
  exit 1
fi

QUESTION="$1"
shift || true

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PUBLISHER="$SCRIPT_DIR/kim_nlp_publish.py"

if [[ ! -x "$PUBLISHER" ]]; then
  echo "kim_nlp_publish.py is not executable" >&2
  exit 2
fi

echo "🔁 Kim default profile"
"$PUBLISHER" --profile default "$QUESTION"

echo "🔁 Kim K2 profile"
"$PUBLISHER" --profile kim_k2_poc "$QUESTION"

echo "A/B dispatch complete. Check kim:requests consumers for replies."
