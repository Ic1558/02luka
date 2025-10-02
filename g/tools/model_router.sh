#!/usr/bin/env bash
# Route requested goals to the most appropriate local model (or fallback).
# Usage: model_router.sh "<task description>" "<complexity>"

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $(basename "$0") <task> [complexity]" >&2
  exit 2
fi

TASK_RAW="$1"
COMPLEXITY_RAW="${2:-medium}"
COMPLEXITY_LC="$(printf '%s' "$COMPLEXITY_RAW" | tr '[:upper:]' '[:lower:]')"

task_lc="$(printf '%s' "$TASK_RAW" | tr '[:upper:]' '[:lower:]')"

selected_model="llama3.1"
selection_reason="default"

if [[ "$task_lc" =~ (refactor|code|api|server|js|ts) ]]; then
  selected_model="qwen2.5-coder"
  selection_reason="coding keywords detected"
elif [[ "$task_lc" =~ (plan|design|spec|architecture) ]]; then
  selected_model="deepseek-coder"
  selection_reason="planning keywords detected"
else
  selected_model="llama3.1"
  selection_reason="general task"
fi

confidence="0.6"
availability_reason="ollama-available"

have_ollama=0
tmp_list=""
if command -v ollama >/dev/null 2>&1; then
  tmp_list="$(mktemp 2>/dev/null || printf '/tmp/ollama_list.$$')"
  if ollama list >"$tmp_list" 2>/dev/null; then
    have_ollama=1
    if ! grep -q "^$selected_model" "$tmp_list"; then
      availability_reason="model-missing"
      confidence="0.4"
    else
      confidence="0.9"
      availability_reason="model-present"
    fi
  else
    availability_reason="ollama-unreachable"
  fi
else
  availability_reason="ollama-missing"
fi

if [[ -n "$tmp_list" ]]; then
  rm -f "$tmp_list" 2>/dev/null || true
fi

if [[ "$have_ollama" -ne 1 || "$availability_reason" == "model-missing" || "$availability_reason" == "ollama-unreachable" ]]; then
  selected_model="external-claude-sonnet"
  confidence="0.3"
  selection_reason="$availability_reason"
fi

export SELECTED_MODEL="$selected_model"
export CONFIDENCE="$confidence"
export SELECTION_REASON="$selection_reason"
export AVAIL_REASON="$availability_reason"
export COMPLEXITY="$COMPLEXITY_LC"
export TASK_RAW="$TASK_RAW"

python3 - <<'PY'
import json
import os

payload = {
    "task": os.environ["TASK_RAW"],
    "model": os.environ["SELECTED_MODEL"],
    "confidence": float(os.environ["CONFIDENCE"]),
    "reason": os.environ["SELECTION_REASON"],
    "availability": os.environ["AVAIL_REASON"],
    "complexity": os.environ["COMPLEXITY"]
}

print(json.dumps(payload, ensure_ascii=False))
PY
exit 0

