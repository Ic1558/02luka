#!/usr/bin/env zsh
set -euo pipefail

BASE="${LUKA_SOT:-$HOME/02luka}"
INBOX="$BASE/bridge/inbox/LPE"
PROCESSED="$BASE/bridge/processed/LPE"
OUTBOX="$BASE/bridge/outbox/LPE"
LOG_FILE="$BASE/logs/lpe_worker.out.log"
REPORT_DIR="$BASE/g/reports/system/lpe"
MLS_LEDGER_DIR="$BASE/mls/ledger"
MLS_LESSONS="$BASE/g/knowledge/mls_lessons.jsonl"
SIP_HELPER="$BASE/g/tools/sip_apply_patch.zsh"
MLS_ADD="$BASE/tools/mls_add.zsh"
POLL_INTERVAL=${LPE_POLL_INTERVAL:-5}

ALLOWED_ROOTS=("g/tools/" "g/docs/" "g/reports/system/")

mkdir -p "$INBOX" "$PROCESSED" "$OUTBOX" "$REPORT_DIR" "$MLS_LEDGER_DIR" "$BASE/logs"

log() {
  local ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  local msg="[$ts] $*"
  echo "$msg" | tee -a "$LOG_FILE" >/dev/null
}

write_result() {
  local wo_id="$1" status="$2" files_json="$3" errors_json="$4" sip_result="$5" mls_event_id="$6"
  local out_file="$OUTBOX/${wo_id}.result.json"
  jq -n \
    --arg id "$wo_id" \
    --arg status "$status" \
    --arg sip_result "$sip_result" \
    --arg mls_event_id "$mls_event_id" \
    --argjson files_touched "${files_json:-[]}" \
    --argjson errors "${errors_json:-[]}" \
    '{id:$id,status:$status,files_touched:$files_touched,sip_result:$sip_result,errors:$errors,mls_event_id:$mls_event_id}' \
    > "$out_file"
  log "📤 wrote result → $out_file (status=$status, sip=$sip_result)"
}

append_mls_lesson() {
  local wo_id="$1" status="$2" summary="$3"
  local ts="$(TZ=Asia/Bangkok date +%Y-%m-%dT%H:%M:%S%z)"
  local lesson_id="MLS-LPE-${ts//[^0-9]/}"
  mkdir -p "$(dirname "$MLS_LESSONS")"
  jq -n \
    --arg id "$lesson_id" \
    --arg type "solution" \
    --arg title "LPE processed $wo_id" \
    --arg description "$summary" \
    --arg context "LPE worker" \
    --arg wo "$wo_id" \
    --arg ts "$ts" \
    '{id:$id,type:$type,title:$title,description:$description,context:$context,related_wo:$wo,related_session:null,timestamp:$ts,tags:["lpe","sip"],verified:false,usefulness_score:0}' \
    >> "$MLS_LESSONS"
}

append_mls_event() {
  local wo_id="$1" status="$2" files="$3" errors="$4"
  local sha
  sha="$(git -C "$BASE" rev-parse --short HEAD 2>/dev/null || echo "unknown")"
  local summary="LPE worker handled $wo_id with status $status; files=${files}; errors=${errors}"
  "$MLS_ADD" \
    --type "solution" \
    --title "LPE: $wo_id ($status)" \
    --summary "$summary" \
    --producer "lpe" \
    --context "lpe_worker" \
    --repo "Ic1558/02luka" \
    --workflow "lpe_worker" \
    --sha "$sha" \
    --artifact "" \
    --artifact-path "" \
    --followup-id "" \
    --wo-id "$wo_id" \
    --tags "lpe,sip" \
    --author "LPE" \
    --confidence "0.8" || log "⚠️ MLS append failed for $wo_id"
}

validate_path_acl() {
  local rel="$1" constraint_json="$2" acl_allowed="false" default_allowed="false"

  for root in "${ALLOWED_ROOTS[@]}"; do
    if [[ "$rel" == ${root}* ]]; then
      default_allowed="true"
      break
    fi
  done
  [[ "$default_allowed" == "true" ]] || { echo "Path $rel not permitted by default ACL" >&2; return 1; }

  local -a acl_entries
  while IFS= read -r entry; do
    acl_entries+=("$entry")
  done < <(printf '%s' "$constraint_json" | jq -r '.path_acl[]?')

  if (( ${#acl_entries[@]} > 0 )); then
    for root in "${acl_entries[@]}"; do
      if [[ "$rel" == ${root}* ]]; then
        acl_allowed="true"
        break
      fi
    done
    [[ "$acl_allowed" == "true" ]] || { echo "Path $rel violates WO ACL" >&2; return 1; }
  fi
  return 0
}

process_file_patch() {
  local file_json="$1" constraint_json="$2" allow_create allow_delete rel_path patch_type patch_content tmp_patch sip_output sip_status

  rel_path="$(printf '%s' "$file_json" | jq -r '.path // empty')"
  patch_type="$(printf '%s' "$file_json" | jq -r '.patch_type // empty')"
  patch_content="$(printf '%s' "$file_json" | jq -r '.patch // empty')"
  allow_create="$(printf '%s' "$constraint_json" | jq -r '.allow_create // false')"
  allow_delete="$(printf '%s' "$constraint_json" | jq -r '.allow_delete // false')"

  [[ -n "$rel_path" && -n "$patch_type" && -n "$patch_content" ]] || { echo "missing required file fields" >&2; return 1; }
  validate_path_acl "$rel_path" "$constraint_json" || return 1
  [[ "$patch_type" == "unified_diff" ]] || { echo "unsupported patch type: $patch_type" >&2; return 1; }

  tmp_patch="$(mktemp)"
  printf '%s\n' "$patch_content" > "$tmp_patch"

  if ! sip_output=$("$SIP_HELPER" --path "$rel_path" --patch-type "$patch_type" --patch-file "$tmp_patch" --allow-create "$allow_create" --allow-delete "$allow_delete" 2>>"$LOG_FILE"); then
    rm -f "$tmp_patch"
    echo "sip helper failed for $rel_path" >&2
    return 1
  fi

  sip_status="$(printf '%s' "$sip_output" | jq -r '.status // "unknown"' 2>/dev/null || echo "unknown")"
  rm -f "$tmp_patch"

  case "$sip_status" in
    applied|already_applied)
      echo "$sip_status"
      return 0
      ;;
    *)
      echo "sip status error for $rel_path: $sip_status" >&2
      return 1
      ;;
  esac
}

process_work_order() {
  local wo_file="$1" wo_id mode constraints status="success" sip_result="applied" mls_id
  local -a files_touched errors
  local files_json_entry

  if ! jq empty "$wo_file" 2>/tmp/lpe_jq_err.$$; then
    local err_msg="invalid JSON: $(cat /tmp/lpe_jq_err.$$)"
    log "❌ $(basename "$wo_file") invalid JSON"
    write_result "$(basename "$wo_file" .json)" "invalid_wo" "[]" "[\"$err_msg\"]" "skipped" ""
    mv "$wo_file" "$PROCESSED/$(basename "$wo_file")"
    rm -f /tmp/lpe_jq_err.$$
    return
  fi
  rm -f /tmp/lpe_jq_err.$$

  local raw_wo_id
  raw_wo_id="$(jq -r '.id // ""' "$wo_file")"
  wo_id="${raw_wo_id:-$(basename "$wo_file" .json)}"
  mode="$(jq -r '.mode // ""' "$wo_file")"
  constraints="$(jq -c '.constraints // {}' "$wo_file")"

  if [[ -z "$raw_wo_id" ]]; then
    errors=("missing id")
    status="invalid_wo"
    sip_result="skipped"
  elif [[ "$mode" != sip_* ]]; then
    errors=("unsupported mode: $mode")
    status="invalid_wo"
    sip_result="skipped"
  fi

  local -a file_entries
  while IFS= read -r line; do
    [[ -n "$line" ]] && file_entries+=("$line")
  done < <(jq -c '.files[]? // empty' "$wo_file")

  if (( ${#file_entries[@]} == 0 )) && [[ "$status" == "success" ]]; then
    errors=("no files provided")
    status="invalid_wo"
    sip_result="skipped"
  fi

  if [[ "$status" != "success" ]]; then
    local files_json="[]" errors_json
    errors_json=$(printf '%s\n' "${errors[@]:-}" | jq -R . | jq -s .)
    write_result "$wo_id" "$status" "$files_json" "$errors_json" "$sip_result" ""
    mv "$wo_file" "$PROCESSED/$(basename "$wo_file")"
    return
  fi

  local success_count=0 fail_count=0
  for files_json_entry in "${file_entries[@]}"; do
    local rel_path sip_status
    rel_path="$(printf '%s' "$files_json_entry" | jq -r '.path')"
    if sip_status=$(process_file_patch "$files_json_entry" "$constraints"); then
      (( success_count++ ))
      files_touched+=("$rel_path")
      [[ "$sip_status" == "already_applied" && "$sip_result" == "applied" ]] && sip_result="already_applied"
      log "✅ $wo_id applied patch to $rel_path ($sip_status)"
    else
      (( fail_count++ ))
      sip_result="partial"
      errors+=("failure applying patch for $rel_path")
      log "⚠️ $wo_id failed for $rel_path"
    fi
  done

  if (( fail_count > 0 && success_count == 0 )); then
    status="error"
  elif (( fail_count > 0 )); then
    status="partial"
  else
    status="success"
  fi

  local files_json errors_json
  files_json=$(printf '%s\n' "${files_touched[@]:-}" | jq -R . | jq -s .)
  errors_json=$(printf '%s\n' "${errors[@]:-}" | jq -R . | jq -s .)

  mls_id="MLS-LPE-$(date +%Y%m%d-%H%M%S)"
  write_result "$wo_id" "$status" "$files_json" "$errors_json" "$sip_result" "$mls_id"
  mv "$wo_file" "$PROCESSED/$(basename "$wo_file")"

  append_mls_event "$wo_id" "$status" "$files_json" "$errors_json"
  append_mls_lesson "$wo_id" "$status" "status=$status sip=$sip_result files=$files_json"

  local report="$REPORT_DIR/LPE_RUN_$(date +%Y%m%d_%H%M%S).md"
  {
    echo "# LPE Run Report"
    echo "- WO: $wo_id"
    echo "- Status: $status"
    echo "- SIP result: $sip_result"
    echo "- Files: $files_json"
    echo "- Errors: $errors_json"
    echo "- Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  } > "$report"
  log "📝 report saved to $report"
}

log "🚀 LPE worker starting (poll every ${POLL_INTERVAL}s)"

while true; do
  next_file="$(find "$INBOX" -type f -name '*.json' | sort | head -n 1)"
  if [[ -z "$next_file" ]]; then
    sleep "$POLL_INTERVAL"
    continue
  fi

  log "📥 processing $(basename "$next_file")"
  process_work_order "$next_file" || log "⚠️ processing error for $next_file"
  sleep 1
  log "⏳ waiting $POLL_INTERVAL s"
  sleep "$POLL_INTERVAL"
done
