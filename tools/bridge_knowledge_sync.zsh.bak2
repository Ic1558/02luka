#!/usr/bin/env zsh
# WO: WO-251107-PHASE-14-RAG-UNIFICATION
# Task: Phase 14.3 – Knowledge ↔ MCP Bridge Sync
# Classification: Safe Idempotent Patch (SIP)
# Deployed by: CLS (Cognitive Local System Orchestrator)
# Maintainer: GG Core (02LUKA Automation)
# Version: v1.3-bridge
# Revision: r1
# Author: cls
# Identity: CLS
# Created: 2025-11-07
set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Options:
  --config PATH          Path to bridge_knowledge.yaml (required)
  --dry-run              Preview mode (no actual POST)
  --batch N             Batch size (default: 200)
  --limit N             Limit number of items to process
  --resume               Resume from last manifest
  --max-fail N          Stop after N failures (default: 20)
  --verbose              Verbose output

Examples:
  $0 --config config/bridge_knowledge.yaml --dry-run --limit 500
  $0 --config config/bridge_knowledge.yaml --batch 200 --resume
EOF
  exit 1
}

# Parse arguments
CONFIG=""
DRY_RUN=0
BATCH_SIZE=200
LIMIT=0
RESUME=0
MAX_FAIL=20
VERBOSE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config) CONFIG="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --batch) BATCH_SIZE="$2"; shift 2 ;;
    --limit) LIMIT="$2"; shift 2 ;;
    --resume) RESUME=1; shift ;;
    --max-fail) MAX_FAIL="$2"; shift 2 ;;
    --verbose) VERBOSE=1; shift ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

[[ -z "$CONFIG" ]] && { echo "ERROR: --config required"; usage; }

BASE="$HOME/02luka"
CFG="$BASE/$CONFIG"
[[ "$CFG" != /* ]] && CFG="$BASE/$CONFIG"

[[ -f "$CFG" ]] || { echo "ERROR: Config not found: $CFG"; exit 1; }

need() { command -v "$1" >/dev/null || { echo "Missing dependency: $1"; exit 1; }; }
need jq; need yq || true

# Load config
SOURCE_PATH=$(yq -r '.sources[0].path' "$CFG" | sed "s|~|$HOME|g")
TARGET_URL=$(yq -r '.targets[0].base_url' "$CFG")
ENDPOINT=$(yq -r '.targets[0].endpoint_ingest' "$CFG")
BATCH_CONFIG=$(yq -r '.targets[0].batch_size // 200' "$CFG")
[[ "$BATCH_SIZE" -eq 200 ]] && BATCH_SIZE="$BATCH_CONFIG"

LOG_DIR=$(yq -r '.observability.log_dir // "~/02luka/g/bridge"' "$CFG" | sed "s|~|$HOME|g")
MANIFEST_DIR=$(yq -r '.observability.manifest_dir // "~/02luka/g/bridge"' "$CFG" | sed "s|~|$HOME|g")

mkdir -p "$LOG_DIR" "$MANIFEST_DIR"

LOG_FILE="$LOG_DIR/bridge_knowledge_sync.$(date +%Y%m%d_%H%M%S).log"
MANIFEST_FILE="$MANIFEST_DIR/last_ingest_manifest.json"

# Telemetry helpers
emit_telemetry() {
  local event="$1"
  local data="$2"
  local ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local json=$(jq -n \
    --arg event "$event" \
    --arg ts "$ts" \
    --arg agent "bridge_knowledge_sync" \
    --arg phase "14.3" \
    --argjson data "$data" \
    '{event:$event, timestamp:$ts, agent:$agent, phase:$phase, __source:"bridge_knowledge_sync", __normalized:true} + $data')
  echo "$json" >> "$LOG_DIR/bridge_knowledge_sync.log"
  [[ "$VERBOSE" -eq 1 ]] && echo "[TELEMETRY] $event: $json" >&2
}

# Idempotency key
idempotency_key() {
  local content="$1"
  echo -n "$content" | shasum -a 256 | awk '{print $1}'
}

# POST to MCP endpoint
post_batch() {
  local batch_file="$1"
  local batch_id="$2"
  
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[DRY-RUN] Would POST batch $batch_id ($(wc -l < "$batch_file" | tr -d ' ') items) to $TARGET_URL$ENDPOINT"
    return 0
  fi
  
  local response
  local status_code
  response=$(curl -s -w "\n%{http_code}" \
    -X POST \
    -H "Content-Type: application/json" \
    -H "X-Idempotency-Key: $batch_id" \
    -d @"$batch_file" \
    "$TARGET_URL$ENDPOINT" 2>&1) || true
  
  status_code=$(echo "$response" | tail -n 1)
  response_body=$(echo "$response" | sed '$d')
  
  if [[ "$status_code" -ge 200 && "$status_code" -lt 300 ]]; then
    echo "$response_body" | jq -r '.ingested // .count // "?"' 2>/dev/null || echo "?"
    return 0
  else
    echo "ERROR: HTTP $status_code" >&2
    [[ "$VERBOSE" -eq 1 ]] && echo "$response_body" >&2
    return 1
  fi
}

# Main execution
echo "== bridge_knowledge_sync start =="
echo "Config: $CFG"
echo "Source: $SOURCE_PATH"
echo "Target: $TARGET_URL$ENDPOINT"
echo "Batch size: $BATCH_SIZE"
echo "Dry-run: $DRY_RUN"
echo "Log: $LOG_FILE"
echo ""

[[ -f "$SOURCE_PATH" ]] || { echo "ERROR: Source not found: $SOURCE_PATH"; exit 1; }

# Emit start event
emit_telemetry "bridge.sync.start" '{"batch_size":'$BATCH_SIZE',"source":"'$SOURCE_PATH'"}'

# Process file
count=0
batch_count=0
total_fail=0
batch_items=()
batch_id=""

tmp_batch=$(mktemp)
trap 'rm -f "$tmp_batch"' EXIT

> "$MANIFEST_FILE"
echo "[]" > "$MANIFEST_FILE"

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  [[ "$LIMIT" -gt 0 && "$count" -ge "$LIMIT" ]] && break
  
  # Add to batch
  batch_items+=("$line")
  count=$((count + 1))
  
  # Process batch when full
  if [[ ${#batch_items[@]} -ge "$BATCH_SIZE" ]]; then
    batch_id="batch_$(date +%s)_$batch_count"
    batch_count=$((batch_count + 1))
    
    # Create batch JSON array
    : > "$tmp_batch"
    for item in "${batch_items[@]}"; do
      echo "$item" >> "$tmp_batch"
    done
    
    # Convert to JSON array
    batch_json=$(jq -s '.' "$tmp_batch" 2>/dev/null || echo "[]")
    echo "$batch_json" > "$tmp_batch"
    
    # POST batch
    if post_batch "$tmp_batch" "$batch_id"; then
      ingested=$(post_batch "$tmp_batch" "$batch_id" 2>/dev/null || echo "?")
      emit_telemetry "ingest.ok" "{\"batch_id\":\"$batch_id\",\"count\":${#batch_items[@]},\"ingested\":\"$ingested\"}"
      
      # Record in manifest
      jq --arg id "$batch_id" --argjson count ${#batch_items[@]} \
        '. += [{"batch_id":$id,"count":$count,"status":"ok","timestamp":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}]' \
        "$MANIFEST_FILE" > "$MANIFEST_FILE.tmp" && mv "$MANIFEST_FILE.tmp" "$MANIFEST_FILE"
    else
      total_fail=$((total_fail + 1))
      emit_telemetry "ingest.fail" "{\"batch_id\":\"$batch_id\",\"count\":${#batch_items[@]},\"error\":\"HTTP error\"}"
      
      # Record failure in manifest
      jq --arg id "$batch_id" --argjson count ${#batch_items[@]} \
        '. += [{"batch_id":$id,"count":$count,"status":"fail","timestamp":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}]' \
        "$MANIFEST_FILE" > "$MANIFEST_FILE.tmp" && mv "$MANIFEST_FILE.tmp" "$MANIFEST_FILE"
      
      if [[ "$total_fail" -ge "$MAX_FAIL" ]]; then
        echo "ERROR: Max failures reached ($total_fail >= $MAX_FAIL)" >&2
        emit_telemetry "bridge.sync.end" "{\"status\":\"failed\",\"total\":$count,\"batches\":$batch_count,\"failures\":$total_fail,\"reason\":\"max_fail_reached\"}"
        exit 1
      fi
    fi
    
    batch_items=()
  fi
done < "$SOURCE_PATH"

# Process remaining items
if [[ ${#batch_items[@]} -gt 0 ]]; then
  batch_id="batch_$(date +%s)_$batch_count"
  batch_count=$((batch_count + 1))
  
  : > "$tmp_batch"
  for item in "${batch_items[@]}"; do
    echo "$item" >> "$tmp_batch"
  done
  
  batch_json=$(jq -s '.' "$tmp_batch" 2>/dev/null || echo "[]")
  echo "$batch_json" > "$tmp_batch"
  
  if post_batch "$tmp_batch" "$batch_id"; then
    emit_telemetry "ingest.ok" "{\"batch_id\":\"$batch_id\",\"count\":${#batch_items[@]}}"
    jq --arg id "$batch_id" --argjson count ${#batch_items[@]} \
      '. += [{"batch_id":$id,"count":$count,"status":"ok","timestamp":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}]' \
      "$MANIFEST_FILE" > "$MANIFEST_FILE.tmp" && mv "$MANIFEST_FILE.tmp" "$MANIFEST_FILE"
  else
    total_fail=$((total_fail + 1))
    emit_telemetry "ingest.fail" "{\"batch_id\":\"$batch_id\",\"count\":${#batch_items[@]}}"
  fi
fi

# Emit end event
emit_telemetry "bridge.sync.end" "{\"status\":\"complete\",\"total\":$count,\"batches\":$batch_count,\"failures\":$total_fail}"

echo ""
echo "== bridge_knowledge_sync complete =="
echo "Processed: $count items"
echo "Batches: $batch_count"
echo "Failures: $total_fail"
echo "Manifest: $MANIFEST_FILE"
echo "Log: $LOG_FILE"

exit $((total_fail > 0 ? 1 : 0))

