#!/usr/bin/env bash
# model_router.sh — lightweight routing shim for Codex/Ollama pipelines
# Routes tasks to specialised local models:
#   generate → qwen2.5-coder
#   review   → deepseek-coder
#   optimize → llama3.1
# Inputs: TASK_TYPE (positional or env), HINTS (optional hints string)

set -euo pipefail

SCRIPT_NAME="model_router"

usage() {
  cat <<'USAGE'
Usage: model_router.sh <TASK_TYPE> [HINTS]

TASK_TYPE values (case-insensitive): generate, review, optimize.
HINTS (optional) can reinforce routing keywords.
Outputs a JSON object: {"model","reason","confidence"}.
USAGE
}

TASK_TYPE="${1:-${TASK_TYPE:-}}"
HINTS="${2:-${HINTS:-}}"

if [[ -z "$TASK_TYPE" ]]; then
  usage >&2
  exit 2
fi

lower() {
  printf '%s' "$1" | tr 'A-Z' 'a-z'
}

norm_task="$(lower "$TASK_TYPE")"

if [[ -z "$HINTS" ]]; then
  norm_hints=""
else
  norm_hints=" $(lower "$HINTS") "
fi

case "$norm_task" in
  review|code_review|audit) norm_task="review" ;;
  optimize|refine|improve) norm_task="optimize" ;;
  generate|gen|default) norm_task="generate" ;;
  *)
    if [[ "$norm_hints" == *" review "* || "$norm_hints" == *" critique "* ]]; then
      norm_task="review"
    elif [[ "$norm_hints" == *" optimize "* || "$norm_hints" == *" optimise "* || "$norm_hints" == *" refine "* ]]; then
      norm_task="optimize"
    else
      norm_task="generate"
    fi
    ;;
esac

case "$norm_task" in
  review)
    MODEL="deepseek-coder"
    REASON="Task flagged as review; preferring critique-oriented DeepSeek"
    ;;
  optimize)
    MODEL="llama3.1"
    REASON="Task targets optimisation/refinement; routing to Llama 3.1"
    ;;
  generate|*)
    MODEL="qwen2.5-coder"
    REASON="Defaulting to Qwen2.5-Coder for general code generation"
    ;;
esac

CONFIDENCE="0.85"

check_model() {
  local desired="$1"

  if ! command -v ollama >/dev/null 2>&1; then
    echo "missing_ollama"
    return
  fi

  if ! ollama list 2>/dev/null | awk 'NR>1 {print tolower($1)}' | grep -Fxq "$(lower "$desired")"; then
    echo "missing_model"
    return
  fi

  echo "ok"
}

availability="$(check_model "$MODEL")"
FALLBACK=""

if [[ "$availability" == "missing_model" ]]; then
  while IFS= read -r candidate; do
    [[ "$(lower "$candidate")" == "$(lower "$MODEL")" ]] && continue
    if [[ "$(check_model "$candidate")" == "ok" ]]; then
      FALLBACK="$candidate"
      break
    fi
  done < <(printf '%s\n' "qwen2.5-coder" "deepseek-coder" "llama3.1")

  if [[ -n "$FALLBACK" ]]; then
    REASON="Requested model '$MODEL' unavailable; rerouted to '$FALLBACK'"
    MODEL="$FALLBACK"
    CONFIDENCE="0.55"
    availability="ok"
  else
    REASON="Requested model '$MODEL' unavailable on Ollama host"
    CONFIDENCE="0.20"
  fi
elif [[ "$availability" == "missing_ollama" ]]; then
  REASON="Ollama CLI not found; cannot resolve local model"
  MODEL=""
  CONFIDENCE="0.10"
fi

python3 - <<'PY' "$MODEL" "$REASON" "$CONFIDENCE"
import json, sys
model, reason, confidence = sys.argv[1], sys.argv[2], float(sys.argv[3])
print(json.dumps({"model": model, "reason": reason, "confidence": confidence}))
PY
