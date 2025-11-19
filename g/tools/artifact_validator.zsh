#!/usr/bin/env zsh
# artifact_validator.zsh
# Validate escalation prompt artifacts from workflow runs
set -euo pipefail

SOT="${SOT:-$HOME/02luka}"
RUN_ID="${1:-}"

if [[ -z "$RUN_ID" ]]; then
  echo "Usage: $0 <run_id>" >&2
  echo "Example: $0 19444054508" >&2
  exit 1
fi

echo "[artifact] Artifact Validator"
echo "[artifact] Run ID: $RUN_ID"

# Download escalation prompt artifact
ARTIFACT_DIR="/tmp/artifacts_${RUN_ID}"
mkdir -p "$ARTIFACT_DIR"

gh run download "$RUN_ID" --name escalation-prompt --dir "$ARTIFACT_DIR" 2>&1 || {
  echo "[artifact] ⚠️  No escalation-prompt artifact found"
  exit 0
}

PROMPT_FILE="$ARTIFACT_DIR/escalation_prompt.txt"
if [[ ! -f "$PROMPT_FILE" ]]; then
  echo "[artifact] ⚠️  Escalation prompt file not found in artifact"
  exit 0
fi

echo "[artifact] ✅ Escalation prompt artifact found"

# Validate content
if grep -q "Mary/GC" "$PROMPT_FILE"; then
  echo "[artifact] ✅ Contains Mary/GC routing"
else
  echo "[artifact] ❌ Missing Mary/GC routing"
fi

if grep -q "Protocol v3.2\|Context Protocol v3.2" "$PROMPT_FILE"; then
  echo "[artifact] ✅ References Protocol v3.2"
else
  echo "[artifact] ⚠️  Missing Protocol v3.2 reference"
fi

if grep -q "CLC\|Gemini" "$PROMPT_FILE"; then
  echo "[artifact] ✅ Contains agent routing (CLC/Gemini)"
else
  echo "[artifact] ⚠️  Missing agent routing"
fi

echo "[artifact] Prompt content:"
cat "$PROMPT_FILE"

rm -R -- "$ARTIFACT_DIR"
exit 0
