#!/usr/bin/env zsh
# WO-CLS-0005: OCR Approval Consumer (Simplified)
setopt NULL_GLOB EXTENDED_GLOB

ROOT="$HOME/02luka"
INBOX="$ROOT/bridge/inbox/CLC"
WORK="$ROOT/bridge/processing"
DONE="$ROOT/bridge/processed"
FAIL="$ROOT/bridge/failed"
TELEM="$ROOT/g/telemetry"
LOG="$ROOT/g/logs/ocr_consumer.log"

ts(){ date +'%Y-%m-%dT%H:%M:%S%z'; }
log(){ echo "[$(ts)] $*" | tee -a "$LOG"; }

log "START: OCR Consumer scan"

# Process files
found=0
for json in "$INBOX"/OCR_APPROVED_*.json; do
  [[ -f "$json" ]] || continue
  (( found++ ))
  
  base=$(basename "$json")
  log "FOUND: $base"
  
  # Move to processing
  mv "$json" "$WORK/$base" 2>/dev/null || { log "ERR: could not move $base"; continue; }
  log "MOVED: $base → processing/"
  
  # Extract data
  wo_id=$(jq -r '.wo_id // "unknown"' "$WORK/$base")
  action=$(jq -r '.action // "unknown"' "$WORK/$base")
  
  # Verify files exist and match hashes
  all_ok=true
  jq -r '.files[]? | [.path,.sha256] | @tsv' "$WORK/$base" 2>/dev/null | while IFS=$'\t' read -r fpath expect; do
    if [[ ! -f "$fpath" ]]; then
      log "ERR: missing file $fpath"
      all_ok=false
    else
      have=$(shasum -a 256 "$fpath" | awk '{print $1}')
      if [[ "$have" == "$expect" ]]; then
        log "OK: sha256 verified $fpath"
      else
        log "ERR: sha256 mismatch $fpath"
        all_ok=false
      fi
    fi
  done
  
  # Execute action
  rc=0
  case "$action" in
    publish)
      if [[ -x "$ROOT/tools/publish_doc.zsh" ]]; then
        log "ACTION: executing publish_doc.zsh for $wo_id"
        "$ROOT/tools/publish_doc.zsh" "$WORK/$base" || rc=$?
      else
        log "WARN: publish_doc.zsh not found or not executable"
      fi
      ;;
    ingest)
      if [[ -x "$ROOT/tools/ingest_doc.zsh" ]]; then
        log "ACTION: executing ingest_doc.zsh for $wo_id"
        "$ROOT/tools/ingest_doc.zsh" "$WORK/$base" || rc=$?
      else
        log "WARN: ingest_doc.zsh not found or not executable"
      fi
      ;;
    archive)
      if [[ -x "$ROOT/tools/archive_doc.zsh" ]]; then
        log "ACTION: executing archive_doc.zsh for $wo_id"
        "$ROOT/tools/archive_doc.zsh" "$WORK/$base" || rc=$?
      else
        log "WARN: archive_doc.zsh not found or not executable"
      fi
      ;;
    *)
      log "WARN: unknown action=$action (noop)"
      ;;
  esac

  # Move to processed or failed based on action result
  if [[ "$rc" -eq 0 ]]; then
    out="$DONE/OCR_APPROVED_${wo_id}_$(date +%Y%m%d_%H%M%S).json"
    mv "$WORK/$base" "$out"
    log "DONE: $base → $(basename "$out")"

    # Telemetry
    echo "{\"kind\":\"ocr_execution\",\"wo_id\":\"$wo_id\",\"status\":\"ok\",\"action\":\"$action\",\"when\":\"$(ts)\"}" >> "$TELEM/ocr_execution_$(date +%Y%m%d).ndjson"
  else
    mv "$WORK/$base" "$FAIL/$base"
    log "ERR: action failed for $wo_id (rc=$rc)"
    echo "{\"kind\":\"ocr_execution\",\"wo_id\":\"$wo_id\",\"status\":\"failed\",\"action\":\"$action\",\"reason\":\"action_rc\",\"when\":\"$(ts)\"}" >> "$TELEM/ocr_execution_$(date +%Y%m%d).ndjson"
  fi
done

log "SCAN: complete (found=$found)"
