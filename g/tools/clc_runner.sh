#!/usr/bin/env bash
# Coordinated Luka Change (CLC) runner pipeline.

set -euo pipefail

CONTEXT_ID="CU-2025-10-02"
CHANGE_ID="CU-2025-10-02-luka-clc-runner-v1"

ROOT="${SOT_PATH:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

PATH_RESOLVER="$ROOT/g/tools/path_resolver.sh"
if [[ ! -x "$PATH_RESOLVER" ]]; then
  echo "{\"error\":\"path_resolver_missing\"}" >&2
  exit 2
fi

resolve_path() {
  "$PATH_RESOLVER" "$1"
}

RUN_START="$(python3 - <<'PY'
import time
print(repr(time.time()))
PY
)"
export RUN_START

if [[ $# -gt 0 ]]; then
  GOAL_RAW="$*"
else
  if ! read -r -d '' GOAL_RAW; then
    GOAL_RAW="${GOAL_RAW:-}"
  fi
fi

GOAL="$(printf '%s' "${GOAL_RAW:-}" | tr -d '\r')"
GOAL="${GOAL##$'\n'}"
GOAL="${GOAL#${GOAL%%[![:space:]]*}}"
GOAL="${GOAL%${GOAL##*[![:space:]]}}"

if [[ -z "$GOAL" ]]; then
  echo "{\"error\":\"goal_required\"}" >&2
  exit 3
fi

INBOX_DIR="$(resolve_path human:inbox)"
SENT_DIR="$(resolve_path human:sent)"
REPORTS_DIR="$(resolve_path reports:runtime)"
STATUS_FILE="$(resolve_path status:system)"

mkdir -p "$SENT_DIR" "$REPORTS_DIR"

PREFLIGHT_SCRIPT="$ROOT/.codex/preflight.sh"
if [[ -x "$PREFLIGHT_SCRIPT" ]]; then
  bash "$PREFLIGHT_SCRIPT" >/dev/null 2>&1 || true
fi

CONTEXT_ENGINE="$ROOT/g/tools/context_engine.sh"
CONTEXT_OUTPUT=""
CONTEXT_STATUS="missing"
if [[ -x "$CONTEXT_ENGINE" ]]; then
  if OUTPUT=$("$CONTEXT_ENGINE" generate "$GOAL" 2>&1); then
    CONTEXT_OUTPUT="$OUTPUT"
    CONTEXT_STATUS="ok"
  else
    CONTEXT_OUTPUT="$OUTPUT"
    CONTEXT_STATUS="error"
  fi
else
  CONTEXT_OUTPUT="context_engine.sh not available"
fi

ROUTE_JSON=$("$ROOT/g/tools/model_router.sh" "$GOAL" "medium" 2>/dev/null || echo '{}')

MODEL=$(printf '%s' "$ROUTE_JSON" | jq -r '.model // empty' 2>/dev/null || echo '')
CONFIDENCE=$(printf '%s' "$ROUTE_JSON" | jq -r '.confidence // 0' 2>/dev/null || echo '0')
ROUTE_REASON=$(printf '%s' "$ROUTE_JSON" | jq -r '.reason // "unknown"' 2>/dev/null || echo 'unknown')
ROUTE_AVAIL=$(printf '%s' "$ROUTE_JSON" | jq -r '.availability // "unknown"' 2>/dev/null || echo 'unknown')

if [[ -z "$MODEL" || "$MODEL" == "null" ]]; then
  MODEL="external-claude-sonnet"
fi

RUN_MODE="simulated"
MODEL_OUTPUT=""

if command -v ollama >/dev/null 2>&1 && [[ "$MODEL" != external-claude-sonnet ]]; then
  if ollama list 2>/dev/null | grep -q "^$MODEL"; then
    if MODEL_OUTPUT=$(printf '%s' "$GOAL" | ollama run "$MODEL" 2>&1); then
      RUN_MODE="ollama"
    else
      MODEL_OUTPUT="Simulated output for $MODEL (ollama execution failed)."
    fi
  else
    MODEL_OUTPUT="Simulated output for $MODEL (model not installed)."
  fi
else
  MODEL_OUTPUT="Simulated output for $MODEL (ollama unavailable)."
fi

if [[ -z "$MODEL_OUTPUT" ]]; then
  MODEL_OUTPUT="Simulated output for $MODEL (no response captured)."
fi

TIMESTAMP_ISO="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
FILENAME_TIME="$(date -u +"%Y%m%dT%H%M%SZ")"

SLUG=$(GOAL_TEXT="$GOAL" python3 - <<'PY'
import os
import re

goal = os.environ.get("GOAL_TEXT", "").lower()
slug = re.sub(r"[^a-z0-9]+", "-", goal).strip('-')
if not slug:
    slug = "goal"
print(slug[:48])
PY
)

OUTPUT_FILE="$SENT_DIR/goal_${FILENAME_TIME}_${SLUG}.md"

SYSTEM_STATUS="{}"
if [[ -f "$STATUS_FILE" ]]; then
  SYSTEM_STATUS=$(cat "$STATUS_FILE")
fi

export ROOT
export OUTPUT_FILE
export GOAL
export TIMESTAMP_ISO
export MODEL
export CONFIDENCE
export ROUTE_REASON
export ROUTE_AVAIL
export RUN_MODE
export MODEL_OUTPUT
export CONTEXT_OUTPUT
export CONTEXT_STATUS
export SYSTEM_STATUS
export ROUTE_JSON

python3 - <<'PY'
import json
import os
from pathlib import Path
import textwrap

output_path = Path(os.environ['OUTPUT_FILE'])
route_raw = os.environ['ROUTE_JSON'] or '{}'
try:
    route_json = json.loads(route_raw)
except json.JSONDecodeError:
    route_json = {}
status_raw = os.environ['SYSTEM_STATUS'] or '{}'
try:
    status_json = json.loads(status_raw)
except json.JSONDecodeError:
    status_json = {}

goal_text = os.environ['GOAL']
goal_block = goal_text.replace('\n', '\n  ')
model_output = os.environ['MODEL_OUTPUT']
context_output = os.environ['CONTEXT_OUTPUT']
context_status = os.environ['CONTEXT_STATUS']
route_pretty = json.dumps(route_json, ensure_ascii=False, indent=2)
status_pretty = json.dumps(status_json, ensure_ascii=False, indent=2)

body = textwrap.dedent(f"""\
---
timestamp: {os.environ['TIMESTAMP_ISO']}
model: {os.environ['MODEL']}
confidence: {os.environ['CONFIDENCE']}
route_reason: {os.environ['ROUTE_REASON']}
route_availability: {os.environ['ROUTE_AVAIL']}
run_mode: {os.environ['RUN_MODE']}
context_status: {os.environ['CONTEXT_STATUS']}
goal: |-
  {goal_block}
---

## Goal
{goal_text}

## Route Decision
```json
{route_pretty}
```

## Model Output
{model_output}

## Context Engine Output ({context_status})
{context_output}

## System Status Snapshot
```json
{status_pretty}
```
""")

output_path.write_text(body, encoding='utf-8')
PY

RELATIVE_FILE=$(python3 - <<'PY'
import os
from pathlib import Path

root = Path(os.environ.get('ROOT', '.')).resolve()
file_path = Path(os.environ['OUTPUT_FILE']).resolve()
print(file_path.relative_to(root))
PY
)

MANIFEST_PATH="$ROOT/run/change_units/${CONTEXT_ID}.yml"
if [[ -f "$MANIFEST_PATH" ]]; then
  if ! grep -q "$CHANGE_ID" "$MANIFEST_PATH"; then
    {
      printf '\n- time: "%s"\n' "$TIMESTAMP_ISO"
      printf '  change_id: %s\n' "$CHANGE_ID"
      printf '  summary: "%s"\n' "CLC runner executed goal"
      printf '  files_touched:\n'
      printf '    - %s\n' "$RELATIVE_FILE"
      printf '  tags: ["boss-ui","boss-api","resolver","preflight","clc"]\n'
      printf '  tests_ran: []\n'
      printf '  guardrail_status: pending\n'
      printf '  followups: []\n'
    } >> "$MANIFEST_PATH"
  fi
fi

DAILY_PATH="$ROOT/run/daily_reports/REPORT_$(date +%F).md"
printf -- '- %s → %s (%s)\n' "$TIMESTAMP_ISO" "$RELATIVE_FILE" "$MODEL" >> "$DAILY_PATH"

LOG_FILE="$REPORTS_DIR/clc_runs.log"
printf '%s\t%s\t%s\n' "$TIMESTAMP_ISO" "$MODEL" "$RELATIVE_FILE" >> "$LOG_FILE"

ELAPSED_MS=$(python3 - <<'PY'
import os
import time

start = float(os.environ['RUN_START'])
elapsed = int((time.time() - start) * 1000)
print(elapsed)
PY
)

export RELATIVE_FILE
export ELAPSED_MS

python3 - <<'PY'
import json
import os

payload = {
    "ok": True,
    "file": os.environ['RELATIVE_FILE'],
    "model": os.environ['MODEL'],
    "confidence": float(os.environ['CONFIDENCE']),
    "reason": os.environ['ROUTE_REASON'],
    "run_mode": os.environ['RUN_MODE'],
    "took_ms": int(os.environ['ELAPSED_MS']),
    "goal": os.environ['GOAL'],
    "content": os.environ['MODEL_OUTPUT']
}

print(json.dumps(payload, ensure_ascii=False))
PY
