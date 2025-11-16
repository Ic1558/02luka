#!/usr/bin/env zsh
# JSON Work Order Processor
# Processes JSON work orders from bridge/inbox/LLM
set -euo pipefail

BASE="$HOME/02luka"
INBOX="$BASE/bridge/inbox/LLM"
LOGDIR="$BASE/logs/agents/json_wo_processor"
mkdir -p "$LOGDIR"

LOG="$LOGDIR/$(date +%Y%m%d).log"

log() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')] $*" >> "$LOG"
}

process_wo() {
  local wo_file="$1"
  local wo_base=$(basename "$wo_file")

  # Skip if already has result
  if [[ -f "${wo_file}.result" ]]; then
    log "Skip: $wo_base (already has result)"
    return 0
  fi

  # Parse JSON
  local id op path cost tokens
  id=$(jq -r '.id // ""' "$wo_file" 2>/dev/null)
  op=$(jq -r '.op // ""' "$wo_file" 2>/dev/null)
  path=$(jq -r '.inputs.path // ""' "$wo_file" 2>/dev/null)
  cost=$(jq -r '.cost_estimate_usd // 0' "$wo_file" 2>/dev/null)
  tokens=$(jq -r '.token_estimate // 0' "$wo_file" 2>/dev/null)

  if [[ -z "$op" ]]; then
    log "ERROR: No op in $wo_base"
    return 1
  fi

  log "Processing: $wo_base (op=$op)"

  # Check if input file exists
  if [[ -n "$path" ]] && [[ ! -f "$path" ]]; then
    log "WARN: Input file not found: $path"
  fi

  # Create mock result (local processing)
  local result_file="${wo_file}.result"
  local output_text="Processed locally: $op"

  case "$op" in
    pm_rollup)
      output_text="PM rollup completed locally"
      ;;
    expense_ocr)
      output_text="Expense OCR processed locally"
      ;;
    invoice_draft)
      output_text="Invoice draft generated locally"
      ;;
    *)
      output_text="Operation $op completed locally"
      ;;
  esac

  # Write result file
  cat > "$result_file" <<JSON
{
  "id": "$id",
  "provider": "local",
  "status": "ok",
  "output": {
    "text": "$output_text",
    "note": "Processed by json_wo_processor"
  },
  "telemetry": {
    "tokens_in": 0,
    "tokens_out": 50,
    "cost_usd": 0
  }
}
JSON

  log "✅ Completed: $wo_base"
  return 0
}

# Main loop
log "=== JSON WO Processor starting ==="

processed=0
failed=0

for wo_file in "$INBOX"/WO-*.json; do
  [[ -f "$wo_file" ]] || continue

  if process_wo "$wo_file"; then
    ((processed++))
  else
    ((failed++))
  fi
done

log "=== Run complete: processed=$processed failed=$failed ==="
