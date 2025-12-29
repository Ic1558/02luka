#!/usr/bin/env zsh
# ======================================================================
# Codex Task Logger
# Purpose: Log Codex task execution for metrics tracking
# Usage: log_codex_task.zsh "task_type" "command" [quality_score]
#        log_codex_task.zsh "code_review" "codex-system 'review X'" 9
# ======================================================================

set -euo pipefail

LOG_FILE="${HOME}/02luka/g/reports/codex_routing_log.jsonl"

# Input
TASK_TYPE="${1:-other}"
COMMAND="${2:-unknown}"
QUALITY="${3:-0}"  # 0 = not rated yet

# Generate task ID
TASK_ID="task-$(date +%Y%m%d-%H%M%S)"

# Detect zone from command (simple heuristic)
ZONE="non-locked"
if echo "$COMMAND" | grep -qE "CLC/|core/governance/|launchd/|memory/"; then
    ZONE="locked"
fi

# Detect engine from command
ENGINE="codex"
if echo "$COMMAND" | grep -qE "^clc|^claude"; then
    ENGINE="clc"
elif echo "$COMMAND" | grep -qE "^gemini|^gg"; then
    ENGINE="gemini"
fi

# Create log entry
cat >> "$LOG_FILE" <<EOF
{"timestamp":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","task_id":"$TASK_ID","task_type":"$TASK_TYPE","zone":"$ZONE","engine":"$ENGINE","command":"$COMMAND","duration_sec":0,"success":true,"quality_score":$QUALITY,"prompts_triggered":0,"clc_quota_saved":true,"notes":""}
EOF

echo "✅ Logged: $TASK_ID ($TASK_TYPE via $ENGINE)"
