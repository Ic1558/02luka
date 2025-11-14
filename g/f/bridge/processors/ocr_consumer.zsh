#!/usr/bin/env zsh
# == WO-CLS-0005 : OCR Approval Consumer ==
# File: ~/02luka/f/bridge/processors/ocr_consumer.zsh
set -euo pipefail
setopt NULL_GLOB EXTENDED_GLOB

ROOT="$HOME/02luka"
INBOX="$ROOT/bridge/inbox/CLC"
WORK="$ROOT/bridge/processing"
DONE="$ROOT/bridge/processed"
FAIL="$ROOT/bridge/failed"
TELEM="$ROOT/g/telemetry"
LOG="$ROOT/g/logs/ocr_consumer.log"
LOCK="$ROOT/g/locks/ocr_consumer.lock"

mkdir -p "$WORK" "$DONE" "$FAIL" "$TELEM" "$ROOT/g/logs" "$ROOT/g/locks"

ts(){ date +'%Y-%m-%dT%H:%M:%S%z'; }
log(){ print -r -- "[$(ts)] $*" | tee -a "$LOG" >/dev/null; }

# Single-instance guard
exec {lfd}>"$LOCK"
if ! flock -n $lfd; then
  log "SKIP: another instance running"
  exit 0
fi

need() { command -v "$1" >/dev/null 2>&1 || { log "ERR: missing tool '$1'"; exit 1; } }
need jq
need shasum

# Validate JSON shape (minimal)
validate_json(){
  local f="$1"
  jq -e '
    .wo_id and (.wo_id | type=="string") and
    .action and (.action | IN("publish","ingest","archive")) and
    .approved_by and (.approved_by | type=="string") and
    .approved_at and (.approved_at | type=="string") and
    .files and (.files | type=="array" and length>0) and
    (all(.files[]; .path and .sha256))
  ' "$f" >/dev/null
}

sha256_of(){ shasum -a 256 "$1" | awk '{print $1}'; }

process_one(){
  local src="$1"
  local base="$(basename "$src")"
  local tmp="$WORK/${base%.json}_$RANDOM.json"

  # Atomic move into processing
  mv "$src" "$tmp" 2>/dev/null || { log "RACE: $base already moved"; return 0; }
  log "PICK: $base → $(basename "$tmp")"

  # JSON sanity
  if ! validate_json "$tmp"; then
    log "ERR: json schema failed: $base"
    mv "$tmp" "$FAIL/$base"
    return 1
  fi

  local wo_id action approved_by approved_at
  wo_id=$(jq -r '.wo_id' "$tmp")
  action=$(jq -r '.action' "$tmp")
  approved_by=$(jq -r '.approved_by' "$tmp")
  approved_at=$(jq -r '.approved_at' "$tmp")

  # Verify file hashes
  local bad=0
  while IFS=$'\t' read -r p expect; do
    if [[ ! -f "$p" ]]; then
      log "ERR: missing file: $p"
      bad=1
      continue
    fi
    have=$(sha256_of "$p")
    if [[ "$have" != "$expect" ]]; then
      log "ERR: sha256 mismatch: $p have=$have expect=$expect"
      bad=1
    else
      log "OK : sha256 $p"
    fi
  done < <(jq -r '.files[] | [.path,.sha256] | @tsv' "$tmp")

  # If any hash failed → move to failed
  if [[ "$bad" == "1" ]]; then
    mv "$tmp" "$FAIL/$base"
    jq -c --arg status "failed" --arg reason "sha256" \
      --arg when "$(ts)" --arg wo "$wo_id" \
      '{kind:"ocr_execution",wo_id:$wo,status:$status,reason:$reason,when:$when}' \
      >> "$TELEM/ocr_execution_$(date +%Y%m%d).ndjson"
    return 1
  fi

  # Execute action (pluggable)
  # You can implement these scripts later; we log + succeed if absent.
  local rc=0
  case "$action" in
    publish) [[ -x "$ROOT/tools/publish_doc.zsh" ]] && "$ROOT/tools/publish_doc.zsh" "$tmp" || log "WARN: publish_doc.zsh missing, noop";;
    ingest)  [[ -x "$ROOT/tools/ingest_doc.zsh"  ]] && "$ROOT/tools/ingest_doc.zsh"  "$tmp" || log "WARN: ingest_doc.zsh missing, noop";;
    archive) [[ -x "$ROOT/tools/archive_doc.zsh" ]] && "$ROOT/tools/archive_doc.zsh" "$tmp" || log "WARN: archive_doc.zsh missing, noop";;
    *) log "WARN: unknown action=$action (noop)";;
  esac || rc=$?

  # Telemetry + finalize
  if [[ "$rc" -eq 0 ]]; then
    local out="$DONE/OCR_APPROVED_${wo_id}_$(date +%Y%m%d_%H%M%S).json"
    mv "$tmp" "$out"
    jq -c --arg status "ok" --arg action "$action" \
      --arg who "$approved_by" --arg when "$(ts)" --arg wo "$wo_id" \
      '{kind:"ocr_execution",wo_id:$wo,status:$status,action:$action,who:$who,when:$when}' \
      >> "$TELEM/ocr_execution_$(date +%Y%m%d).ndjson"
    log "DONE: $wo_id → $(basename "$out")"
  else
    mv "$tmp" "$FAIL/$base"
    jq -c --arg status "failed" --arg reason "action_rc" --arg when "$(ts)" --arg wo "$wo_id" \
      '{kind:"ocr_execution",wo_id:$wo,status:$status,reason:$reason,when:$when}' \
      >> "$TELEM/ocr_execution_$(date +%Y%m%d).ndjson"
    log "ERR: action failed for $wo_id (rc=$rc)"
    return $rc
  fi
}

# Scan inbox for OCR approvals
found=0
for f in "$INBOX"/OCR_APPROVED_*.json(NN); do
  (( found++ ))
  process_one "$f" || true
done

log "SCAN: complete (found=$found)"
