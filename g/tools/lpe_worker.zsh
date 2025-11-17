#!/usr/bin/env bash
set -euo pipefail

PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH:-}"
BASE="${LUKA_SOT:-$HOME/02luka}"
INBOX="$BASE/bridge/inbox/LPE"
PROCESSED="$BASE/bridge/processed/LPE"
OUTBOX="$BASE/bridge/outbox/LPE"
LOG_FILE="$BASE/logs/lpe_worker.out.log"
REPORT_DIR="$BASE/g/reports/system/lpe"
MLS_LEDGER_DIR="$BASE/mls/ledger"
LESSONS_FILE="$BASE/g/knowledge/mls_lessons.jsonl"
LUKA_CLI="$BASE/tools/luka_cli.zsh"
LEDGER_HELPER="$BASE/g/tools/append_mls_ledger.py"
POLL_INTERVAL=${LPE_POLL_INTERVAL:-5}
ONESHOOT="${LPE_ONESHOT:-false}"

mkdir -p "$INBOX" "$PROCESSED" "$OUTBOX" "$REPORT_DIR" "$MLS_LEDGER_DIR" "$BASE/logs"

log() {
  local ts
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "[$ts] $*" | tee -a "$LOG_FILE" >/dev/null
}

write_result() {
  local wo_id="$1" wo_status="$2" files_json="$3" errors_json="$4" sip_result="$5" ledger_id="$6"
  local out_file="$OUTBOX/${wo_id}.result.json"
  jq -n \
    --arg id "$wo_id" \
    --arg status "$wo_status" \
    --arg sip_result "$sip_result" \
    --arg mls_event_id "$ledger_id" \
    --argjson files_touched "${files_json:-[]}" \
    --argjson errors "${errors_json:-[]}" \
    '{id:$id,status:$status,files_touched:$files_touched,sip_result:$sip_result,errors:$errors,mls_event_id:$mls_event_id}' \
    > "$out_file"
  log "📤 wrote result → $out_file (status=$wo_status, sip=$sip_result, ledger=$ledger_id)"
}

append_mls_lesson() {
  local wo_id="$1" wo_status="$2" summary="$3"
  local ts lesson_id
  ts="$(TZ=Asia/Bangkok date +%Y-%m-%dT%H:%M:%S%z)"
  lesson_id="MLS-LPE-${ts//[^0-9]/}"
  mkdir -p "$(dirname "$LESSONS_FILE")"
  jq -n \
    --arg id "$lesson_id" \
    --arg type "solution" \
    --arg title "LPE processed $wo_id" \
    --arg description "$summary" \
    --arg context "LPE worker" \
    --arg wo "$wo_id" \
    --arg ts "$ts" \
    '{id:$id,type:$type,title:$title,description:$description,context:$context,related_wo:$wo,related_session:null,timestamp:$ts,tags:["lpe","sip"],verified:false,usefulness_score:0}' \
    >> "$LESSONS_FILE"
}

append_mls_event() {
  local wo_id="$1" wo_status="$2" files="$3" errors="$4" patch_file="$5" ledger_id=""
  if ledger_id=$(python3 "$LEDGER_HELPER" --wo-id "$wo_id" --status "$wo_status" --files "$files" --errors "$errors" --patch-file "$patch_file" 2>>"$LOG_FILE"); then
    echo "$ledger_id"
  else
    echo ""
  fi
}

materialize_patch_file() {
  local patch_json="$1" tmp_patch
  tmp_patch="$(mktemp)"
  PATCH_JSON="$patch_json" python3 - "$tmp_patch" <<'PY'
import json, sys, yaml, pathlib, os
patch = json.loads(os.environ.get("PATCH_JSON", "{}"))
target = pathlib.Path(sys.argv[1])
target.write_text(yaml.safe_dump(patch, allow_unicode=True), encoding="utf-8")
PY
  echo "$tmp_patch"
}

normalize_work_order() {
  local wo_file="$1" tmp_json
  tmp_json="$(mktemp)"
  case "$wo_file" in
    *.yaml|*.yml)
      python3 - "$wo_file" "$tmp_json" <<'PY'
import sys, yaml, json, pathlib
source = pathlib.Path(sys.argv[1])
target = pathlib.Path(sys.argv[2])
with source.open("r", encoding="utf-8") as handle:
    data = yaml.safe_load(handle) or {}
target.write_text(json.dumps(data), encoding="utf-8")
PY
      ;;
    *)
      cp "$wo_file" "$tmp_json"
      ;;
  esac
  echo "$tmp_json"
}

process_work_order() {
  local wo_file="$1" tmp_json wo_id wo_status="success" sip_result="applied" ledger_id="" patch_file="" errors_json files_json
  local errors=() files_touched=() patch_json

  tmp_json="$(normalize_work_order "$wo_file")"

  if ! jq empty "$tmp_json" 2>/tmp/lpe_jq_err.$$; then
    local err_msg
    err_msg="invalid JSON: $(cat /tmp/lpe_jq_err.$$)"
    log "❌ $(basename "$wo_file") invalid JSON"
    write_result "$(basename "$wo_file" .json)" "invalid_wo" "[]" "[\"$err_msg\"]" "skipped" ""
    mv "$wo_file" "$PROCESSED/$(basename "$wo_file")"
    rm -f /tmp/lpe_jq_err.$$ "$tmp_json"
    return
  fi
  rm -f /tmp/lpe_jq_err.$$

  wo_id="$(jq -r '.id // .wo_id // ""' "$tmp_json")"
  [[ -n "$wo_id" ]] || wo_id="$(basename "$wo_file" | sed 's/\.[^.]*$//')"

  local task_type fallback
  task_type="$(jq -r '.task.type // ""' "$tmp_json")"
  fallback="$(jq -r '.task.fallback // ""' "$tmp_json")"

  patch_json="$(jq -c '.patch // {}' "$tmp_json")"

  if [[ "$task_type" != "write" || "$fallback" != "lpe" ]]; then
    errors+=("unsupported task route (type=$task_type fallback=$fallback)")
    wo_status="invalid_wo"
    sip_result="skipped"
  elif [[ "$patch_json" == "{}" || -z "$patch_json" ]]; then
    errors+=("missing patch payload")
    wo_status="invalid_wo"
    sip_result="skipped"
  elif ! jq -e '.ops | length > 0' <<<"$patch_json" >/dev/null 2>&1; then
    errors+=("patch.ops must include at least one entry")
    wo_status="invalid_wo"
    sip_result="skipped"
  fi

  while IFS= read -r path; do
    [[ -n "$path" ]] && files_touched+=("$path")
  done < <(jq -r '.patch.ops[]?.path // empty' "$tmp_json")

  files_json=$(printf '%s\n' "${files_touched[@]:-}" | jq -R . | jq -s .)

  if [[ "$wo_status" != "success" ]]; then
    errors_json=$(printf '%s\n' "${errors[@]:-}" | jq -R . | jq -s .)
    write_result "$wo_id" "$wo_status" "$files_json" "$errors_json" "$sip_result" ""
    mv "$wo_file" "$PROCESSED/$(basename "$wo_file")"
    rm -f "$tmp_json"
    return
  fi

  patch_file="$(materialize_patch_file "$patch_json")"
  cp "$patch_file" "$REPORT_DIR/last_patch.yaml"

  if "$LUKA_CLI" lpe-apply --file "$patch_file" >>"$LOG_FILE" 2>&1; then
    wo_status="success"
    sip_result="applied"
    log "✅ $wo_id applied patch via Luka CLI"
  else
    wo_status="error"
    sip_result="failed"
    errors+=("Luka CLI patch apply failed")
    log "⚠️ $wo_id Luka CLI failed (see log)"
  fi

  errors_json=$(printf '%s\n' "${errors[@]:-}" | jq -R . | jq -s .)
  ledger_id="$(append_mls_event "$wo_id" "$wo_status" "$files_json" "$errors_json" "$patch_file")"
  append_mls_lesson "$wo_id" "$wo_status" "status=$wo_status sip=$sip_result files=$files_json"

  local report
  report="$REPORT_DIR/LPE_RUN_$(date +%Y%m%d_%H%M%S).md"
  {
    echo "# LPE Run Report"
    echo "- WO: $wo_id"
    echo "- Status: $wo_status"
    echo "- SIP result: $sip_result"
    echo "- Files: $files_json"
    echo "- Errors: $errors_json"
    echo "- Ledger: ${ledger_id:-none}"
    echo "- Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  } > "$report"

  write_result "$wo_id" "$wo_status" "$files_json" "$errors_json" "$sip_result" "$ledger_id"
  mv "$wo_file" "$PROCESSED/$(basename "$wo_file")"
  rm -f "$tmp_json" "$patch_file"
}

log "🚀 LPE worker starting (poll every ${POLL_INTERVAL}s, oneshot=$ONESHOOT)"

while true; do
  next_file="$(find "$INBOX" -type f \( -name '*.json' -o -name '*.yaml' -o -name '*.yml' \) | sort | head -n 1)"
  if [[ -z "$next_file" ]]; then
    sleep "$POLL_INTERVAL"
    continue
  fi

  log "📥 processing $(basename "$next_file")"
  process_work_order "$next_file" || log "⚠️ processing error for $next_file"

  if [[ "$ONESHOOT" == "true" ]]; then
    log "🛑 oneshot complete"
    exit 0
  fi

  sleep 1
  log "⏳ waiting $POLL_INTERVAL s"
  sleep "$POLL_INTERVAL"
done
