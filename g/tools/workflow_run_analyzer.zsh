#!/usr/bin/env zsh
# workflow_run_analyzer.zsh
# Analyze workflow runs for Protocol v3.2 compliance
set -euo pipefail

SOT="${SOT:-$HOME/02luka}"
RUN_ID="${1:-}"
WORKFLOW="${2:-bridge-selfcheck.yml}"

if [[ -z "$RUN_ID" ]]; then
  echo "Usage: $0 <run_id> [workflow_file]" >&2
  echo "Example: $0 19444054508 bridge-selfcheck.yml" >&2
  exit 1
fi

echo "[analyzer] Workflow Run Analyzer"
echo "[analyzer] Run ID: $RUN_ID"
echo "[analyzer] Workflow: $WORKFLOW"

# Fetch workflow run logs
LOG_FILE="/tmp/workflow_run_${RUN_ID}.log"
gh run view "$RUN_ID" --log > "$LOG_FILE" 2>&1 || {
  echo "[analyzer] ERROR: Failed to fetch workflow run logs" >&2
  exit 1
}

# Check for escalation prompts
if grep -q "NEEDS ELEVATION\|ATTENTION.*Mary/GC" "$LOG_FILE"; then
  echo "[analyzer] ✅ Escalation prompts found"
  grep -E "NEEDS ELEVATION|ATTENTION.*Mary/GC" "$LOG_FILE" | head -5
else
  echo "[analyzer] ⚠️  No escalation prompts found"
fi

# Check for MLS events
if grep -q "context-protocol-v3.2" "$LOG_FILE"; then
  echo "[analyzer] ✅ MLS events with context-protocol-v3.2 tag found"
  grep -c "context-protocol-v3.2" "$LOG_FILE" | xargs echo "[analyzer]   Count:"
else
  echo "[analyzer] ⚠️  No MLS events with context-protocol-v3.2 tag"
fi

# Check for routing references
if grep -q "Mary/GC\|CLC\|Gemini" "$LOG_FILE"; then
  echo "[analyzer] ✅ Protocol v3.2 routing references found"
else
  echo "[analyzer] ⚠️  No Protocol v3.2 routing references"
fi

echo "[analyzer] Analysis complete"
rm -f "$LOG_FILE"
exit 0
