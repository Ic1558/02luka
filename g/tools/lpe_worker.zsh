#!/usr/bin/env zsh
# Local Patch Engine worker: consumes WO YAML from bridge/inbox/LPE and applies patches via Luka CLI
set -euo pipefail

setopt extended_glob

BASE="${LUKA_SOT:-$HOME/02luka}"
INBOX="$BASE/bridge/inbox/LPE"
PROCESSED="$BASE/bridge/processed/LPE"
OUTBOX="$BASE/bridge/outbox/LPE"
LOG_FILE="$BASE/logs/lpe_worker.out.log"
LUKA_CLI="$BASE/tools/luka_cli.zsh"
LEDGER_HELPER="$BASE/g/tools/append_mls_ledger.py"

POLL_INTERVAL=${LPE_POLL_INTERVAL:-5}
RUN_ONCE=false

if [[ "${1:-}" == "--once" ]]; then
  RUN_ONCE=true
fi

mkdir -p "$INBOX" "$PROCESSED" "$OUTBOX" "${LOG_FILE:h}" "$BASE/mls/ledger"

log() {
  local ts
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "[$ts] $*" | tee -a "$LOG_FILE" >/dev/null
}

parse_work_order() {
  local wo_path="$1"
  python3 - "$wo_path" "$BASE" <<'PY'
import json
import pathlib
import sys
import yaml

wo_file = pathlib.Path(sys.argv[1]).resolve()
base = pathlib.Path(sys.argv[2]).resolve()

def normalize_patch_path(path_str: str) -> str:
    raw = pathlib.Path(path_str)
    resolved = (base / raw).resolve() if not raw.is_absolute() else raw.resolve()
    try:
        resolved.relative_to(base)
    except ValueError:
        raise ValueError(f"patch path escapes repo: {resolved}")
    return str(resolved)

with wo_file.open("r", encoding="utf-8") as handle:
    data = yaml.safe_load(handle) or {}

def coerce_bool(value):
    if isinstance(value, bool):
        return value
    if isinstance(value, (int, float)):
        return value != 0
    if isinstance(value, str):
        return value.strip().lower() in {"1", "true", "yes", "on"}
    return False

def coerce_path_acl(value):
    if isinstance(value, str):
        return [value]
    if isinstance(value, list):
        items = []
        for entry in value:
            if isinstance(entry, str):
                items.append(entry)
        return items
    return []

wo_id = data.get("id") or wo_file.stem
if not isinstance(wo_id, str) or not wo_id.strip():
    raise SystemExit("missing work order id")

patch_path = None
cleanup = False
source = ""
patch_spec = data.get("lpe_patch") or {}

candidates = [
    data.get("lpe_patch_file"),
    patch_spec.get("file"),
    data.get("patch_file"),
]
inline = data.get("lpe_patch_inline") or patch_spec.get("inline")
ops = data.get("lpe_patch_ops") or patch_spec.get("ops") or data.get("patch", {}).get("ops")

if candidates:
    for candidate in candidates:
        if candidate:
            patch_path = normalize_patch_path(candidate)
            source = "file"
            break

if patch_path is None and inline:
    tmp = pathlib.Path("/tmp") / f"lpe_patch_inline_{wo_id}.yaml"
    tmp.write_text(str(inline), encoding="utf-8")
    patch_path = str(tmp)
    cleanup = True
    source = "inline"

if patch_path is None and ops:
    tmp = pathlib.Path("/tmp") / f"lpe_patch_ops_{wo_id}.yaml"
    tmp.write_text(yaml.safe_dump({"ops": ops}), encoding="utf-8")
    patch_path = str(tmp)
    cleanup = True
    source = "ops"

if patch_path is None:
    raise SystemExit("no LPE patch provided (use lpe_patch_file or lpe_patch_inline or lpe_patch_ops)")

task_type = None
task = data.get("task") or {}
if isinstance(task, dict):
    task_type = task.get("type")

fallback = []
route_hints = data.get("route_hints") or {}
if isinstance(route_hints, dict):
    fallback_raw = route_hints.get("fallback_order") or []
    if isinstance(fallback_raw, list):
        fallback = [str(item).lower() for item in fallback_raw]

acl_spec = {}
for key in ("lpe_acl", "acl", "path_guard"):
    candidate = data.get(key)
    if isinstance(candidate, dict):
        acl_spec = candidate
        break

path_acl = (
    data.get("path_acl")
    or patch_spec.get("path_acl")
    or acl_spec.get("paths")
    or []
)
path_acl = coerce_path_acl(path_acl)

allow_create = coerce_bool(
    (acl_spec.get("allow_create") if isinstance(acl_spec, dict) else None)
    or data.get("allow_create")
    or patch_spec.get("allow_create")
)

allow_delete = coerce_bool(
    (acl_spec.get("allow_delete") if isinstance(acl_spec, dict) else None)
    or data.get("allow_delete")
    or patch_spec.get("allow_delete")
)

print(json.dumps({
    "wo_id": wo_id,
    "patch_path": patch_path,
    "cleanup": cleanup,
    "task_type": task_type,
    "fallback": fallback,
    "source": source,
    "path_acl": path_acl,
    "allow_create": allow_create,
    "allow_delete": allow_delete,
}, ensure_ascii=False))
PY
}

append_result() {
  local wo_id="$1" result_status="$2" patch_path="$3" ledger_id="$4" message="$5"
  local out_file="$OUTBOX/${wo_id}.result.json"
  jq -n \
    --arg id "$wo_id" \
    --arg status "$result_status" \
    --arg patch "$patch_path" \
    --arg ledger_id "$ledger_id" \
    --arg message "$message" \
    '{id:$id,status:$status,patch:$patch,ledger_id:$ledger_id,message:$message}' \
    > "$out_file"
  log "📤 wrote result → $out_file (status=$result_status ledger=$ledger_id)"
}

process_work_order() {
  local wo_file="$1" parsed wo_id patch_path cleanup result_status ledger_id message

  if ! parsed=$(parse_work_order "$wo_file" 2>/tmp/lpe_parse_err.$$); then
    local err_msg
    err_msg="$(cat /tmp/lpe_parse_err.$$)"
    rm -f /tmp/lpe_parse_err.$$
    log "❌ $(basename "$wo_file") invalid: $err_msg"
    append_result "$(basename "$wo_file" .yaml)" "invalid" "" "" "$err_msg"
    mv "$wo_file" "$PROCESSED/$(basename "$wo_file")"
    return
  fi
  rm -f /tmp/lpe_parse_err.$$

  wo_id="$(echo "$parsed" | jq -r '.wo_id')"
  patch_path="$(echo "$parsed" | jq -r '.patch_path')"
  cleanup="$(echo "$parsed" | jq -r '.cleanup')"
  path_acl="$(echo "$parsed" | jq -c '.path_acl // []')"
  allow_create="$(echo "$parsed" | jq -r 'if (.allow_create // false) then "1" else "0" end')"
  allow_delete="$(echo "$parsed" | jq -r 'if (.allow_delete // false) then "1" else "0" end')"

  log "📥 $wo_id using patch $patch_path"

  if ! [[ -x "$LUKA_CLI" ]]; then
    message="luka_cli.zsh not executable at $LUKA_CLI"
    result_status="error"
  else
    if LPE_PATH_ACL="$path_acl" LPE_ALLOW_CREATE="$allow_create" LPE_ALLOW_DELETE="$allow_delete" \
      "$LUKA_CLI" lpe-apply --file "$patch_path" >>"$LOG_FILE" 2>&1; then
      result_status="success"
      message="patch applied"
    else
      result_status="error"
      message="luka_cli failed"
    fi
  fi

  ledger_id="$(python3 "$LEDGER_HELPER" --wo-id "$wo_id" --status "$result_status" --patch-file "$patch_path" --message "$message" --source "lpe_worker")"
  append_result "$wo_id" "$result_status" "$patch_path" "$ledger_id" "$message"

  mv "$wo_file" "$PROCESSED/$(basename "$wo_file")"
  if [[ "$cleanup" == "true" || "$patch_path" == "$INBOX"* ]]; then
    rm -f "$patch_path"
  fi
}

log "🚀 LPE worker starting (poll every ${POLL_INTERVAL}s; run_once=${RUN_ONCE})"

while true; do
  next_file=""
  next_file="$(find "$INBOX" -type f -name '*.yaml' ! -name '*.patch.yaml' | sort | head -n 1)"
  if [[ -z "$next_file" ]]; then
    if $RUN_ONCE; then
      log "✅ run_once completed with no pending work"
      break
    fi
    sleep "$POLL_INTERVAL"
    continue
  fi

  process_work_order "$next_file" || log "⚠️ processing error for $next_file"

  if $RUN_ONCE; then
    log "✅ run_once completed"
    break
  fi
  sleep "$POLL_INTERVAL"

done
