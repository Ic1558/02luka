#!/usr/bin/env zsh
# Local Patch Engine worker: consumes WO YAML from bridge/inbox/LPE and applies patches via Luka CLI
set -euo pipefail

setopt extended_glob

BASE="${LUKA_SOT:-$HOME/02luka}"
LUKA_HOME="${LUKA_HOME:-$BASE}"
INBOX="$BASE/bridge/inbox/LPE"
PROCESSED="$BASE/bridge/processed/LPE"
OUTBOX="$BASE/bridge/outbox/LPE"
LOG_FILE="$BASE/logs/lpe_worker.out.log"
LUKA_CLI="$BASE/tools/luka_cli.zsh"
LEDGER_HELPER="$BASE/g/tools/append_mls_ledger.py"

POLL_INTERVAL=${LPE_POLL_INTERVAL:-5}
RUN_ONCE=false
DRY_RUN=false

# Absolute allowed roots for patch operations (normalized later)
typeset -a DEFAULT_ALLOWED_ROOTS=(
  "$LUKA_HOME/g"
  "$LUKA_HOME/bridge"
  "$LUKA_HOME/mls"
)

while [[ $# -gt 0 ]]; do
  case "$1" in
    --once)
      RUN_ONCE=true
      ;;
    --dry-run)
      DRY_RUN=true
      ;;
  esac
  shift
done

mkdir -p "$INBOX" "$PROCESSED" "$OUTBOX" "${LOG_FILE:h}" "$BASE/mls/ledger"

log() {
  local ts
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "[$ts] $*" | tee -a "$LOG_FILE" >/dev/null
}

log_warn() {
  echo "$*" >&2
  log "$*"
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

wo_id = data.get("id") or wo_file.stem
if not isinstance(wo_id, str) or not wo_id.strip():
    raise SystemExit("missing work order id")

patch_path = None
cleanup = False
source = ""
patch_spec = data.get("lpe_patch") or {}
path_acl = []
allowed_roots = []
allow_create = bool(data.get("allow_create") or (patch_spec.get("allow_create") if isinstance(patch_spec, dict) else False))
allow_delete = bool(data.get("allow_delete") or (patch_spec.get("allow_delete") if isinstance(patch_spec, dict) else False))

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

acl_candidates = []
if isinstance(data.get("path_acl"), list):
    acl_candidates.extend(data.get("path_acl"))
if isinstance(patch_spec, dict) and isinstance(patch_spec.get("path_acl"), list):
    acl_candidates.extend(patch_spec.get("path_acl") or [])

path_acl_cfg = data.get("path_acl") if isinstance(data.get("path_acl"), dict) else {}
if isinstance(patch_spec, dict) and isinstance(patch_spec.get("path_acl"), dict):
    path_acl_cfg = {**path_acl_cfg, **(patch_spec.get("path_acl") or {})}

if isinstance(path_acl_cfg, dict):
    roots = path_acl_cfg.get("allowed_roots") or []
    if isinstance(roots, list):
        allowed_roots.extend(str(item) for item in roots if str(item).strip())
    allow_create = bool(path_acl_cfg.get("allow_create", allow_create))
    allow_delete = bool(path_acl_cfg.get("allow_delete", allow_delete))

path_acl = [str(item) for item in acl_candidates if str(item).strip()]

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

print(json.dumps({
    "wo_id": wo_id,
    "patch_path": patch_path,
    "cleanup": cleanup,
    "task_type": task_type,
    "fallback": fallback,
    "source": source,
    "path_acl": path_acl,
    "allowed_roots": allowed_roots,
    "allow_create": allow_create,
    "allow_delete": allow_delete,
}, ensure_ascii=False))
PY
}

lpe_check_patch_acl() {
  local patch_file="$1" wo_id="$2" allow_create="$3" allow_delete="$4"
  shift 4
  local -a allowed_roots path_acl

  while [[ $# -gt 0 ]]; do
    if [[ "$1" == "--" ]]; then
      shift
      break
    fi
    allowed_roots+=("$1")
    shift
  done
  path_acl=("$@")

  local allowed_roots_str path_acl_str default_roots_str
  allowed_roots_str="$(printf "%s\n" "${allowed_roots[@]}")"
  path_acl_str="$(printf "%s\n" "${path_acl[@]}")"
  default_roots_str="$(printf "%s\n" "${DEFAULT_ALLOWED_ROOTS[@]}")"

  ALLOWED_ROOTS="$allowed_roots_str" PATH_ACL="$path_acl_str" DEFAULT_ROOTS="$default_roots_str" \
    ALLOW_CREATE="$allow_create" ALLOW_DELETE="$allow_delete" LUKA_HOME="$LUKA_HOME" \
    python3 - "$patch_file" "$BASE" <<'PY'
import os
import pathlib
import sys
import yaml

patch_path = pathlib.Path(sys.argv[1]).expanduser().resolve()
base = pathlib.Path(sys.argv[2]).resolve()
home_base = pathlib.Path(os.environ.get("LUKA_HOME", str(base))).expanduser().resolve()

def normalize_acl_root(raw: str) -> pathlib.Path:
    candidate = pathlib.Path(raw)
    return (home_base / candidate).resolve() if not candidate.is_absolute() else candidate.resolve()

allowed_roots = [normalize_acl_root(p) for p in os.environ.get("ALLOWED_ROOTS", "").splitlines() if p.strip()]
path_acl = [normalize_acl_root(p) for p in os.environ.get("PATH_ACL", "").splitlines() if p.strip()]
default_roots = [normalize_acl_root(p) for p in os.environ.get("DEFAULT_ROOTS", "").splitlines() if p.strip()]
allow_create = os.environ.get("ALLOW_CREATE", "false").lower() == "true"
allow_delete = os.environ.get("ALLOW_DELETE", "false").lower() == "true"

critical_prefixes = [
    base / ".git",
    base / ".github",
    home_base / ".ssh",
    pathlib.Path("/etc"),
    pathlib.Path("/bin"),
    pathlib.Path("/usr"),
    pathlib.Path("/lib"),
    pathlib.Path("/lib64"),
]

def deny(message: str):
    raise ValueError(message)

def normalize_target(path_str: str) -> pathlib.Path:
    candidate = pathlib.Path(path_str)
    resolved = (base / candidate).resolve() if not candidate.is_absolute() else candidate.resolve()
    try:
        resolved.relative_to(home_base)
    except ValueError:
        deny(f"[LPE] DENY patch: path outside ACL (path={resolved}, acl_roots={[str(p) for p in allowed_roots or default_roots]})")
    return resolved

def check_acl(resolved: pathlib.Path) -> None:
    configured_roots = allowed_roots or default_roots
    if not configured_roots:
        deny("[LPE] DENY patch: no allowed roots configured")
    if not any(resolved == root or root in resolved.parents for root in configured_roots):
        deny(f"[LPE] DENY patch: path outside ACL (path={resolved}, acl_roots={[str(p) for p in configured_roots]})")
    if path_acl:
        for acl in path_acl:
            try:
                resolved.relative_to(acl)
                break
            except ValueError:
                continue
        else:
            deny(f"[LPE] DENY patch: path {resolved} denied by work-order path_acl")

    for prefix in critical_prefixes:
        try:
            resolved.relative_to(prefix)
            deny(f"[LPE] DENY patch: critical path blocked (path={resolved}, blocked_prefix={prefix})")
        except ValueError:
            continue

    if resolved.parent == base and resolved.name.startswith("."):
        deny(f"[LPE] DENY patch: repo root dotfile blocked (path={resolved})")

def detect_deletion(op: dict) -> bool:
    mode = str(op.get("mode", "")).lower()
    return mode in {"delete", "remove", "rm"}

try:
    with patch_path.open("r", encoding="utf-8") as handle:
        patch_data = yaml.safe_load(handle) or {}

    if not isinstance(patch_data, dict) or not isinstance(patch_data.get("ops"), list):
        raise ValueError("patch missing ops list for ACL evaluation")

    for op in patch_data["ops"]:
        if not isinstance(op, dict) or "path" not in op:
            raise ValueError("invalid op entry in patch")
        resolved = normalize_target(str(op["path"]))
        check_acl(resolved)

        creating = not resolved.exists()
        deleting = detect_deletion(op)

        if creating and not allow_create:
            raise ValueError(f"creation blocked by ACL: {resolved}")
        if deleting and not allow_delete:
            raise ValueError(f"delete blocked by ACL: {resolved}")

    print("ok")
except ValueError as exc:
    print(str(exc))
    sys.exit(1)
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
  local wo_file="$1" parsed wo_id patch_path cleanup result_status ledger_id message allow_create allow_delete
  local -a path_acl allowed_roots

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
  allow_create="$(echo "$parsed" | jq -r '.allow_create // false')"
  allow_delete="$(echo "$parsed" | jq -r '.allow_delete // false')"
  allowed_roots=($(echo "$parsed" | jq -r '.allowed_roots[]?'))
  path_acl=($(echo "$parsed" | jq -r '.path_acl[]?'))

  log "📥 $wo_id using patch $patch_path"

  local acl_output=""
  if ! acl_output=$(lpe_check_patch_acl "$patch_path" "$wo_id" "$allow_create" "$allow_delete" "${allowed_roots[@]}" -- "${path_acl[@]}" 2>&1); then
    message="$acl_output"
    result_status="denied"
    ledger_id="$(python3 "$LEDGER_HELPER" --wo-id "$wo_id" --status "$result_status" --patch-file "$patch_path" --message "$message" --source "lpe_worker")"
    append_result "$wo_id" "$result_status" "$patch_path" "$ledger_id" "$message"
    mv "$wo_file" "$PROCESSED/$(basename "$wo_file")"
    if [[ "$cleanup" == "true" || "$patch_path" == "$INBOX"* ]]; then
      rm -f "$patch_path"
    fi
    return
  fi

  if $DRY_RUN; then
    result_status="dry_run"
    message="dry-run: ACL passed; patch not applied"
  elif ! [[ -x "$LUKA_CLI" ]]; then
    message="luka_cli.zsh not executable at $LUKA_CLI"
    result_status="error"
  else
    if "$LUKA_CLI" lpe-apply --file "$patch_path" >>"$LOG_FILE" 2>&1; then
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

log "🚀 LPE worker starting (poll every ${POLL_INTERVAL}s; run_once=${RUN_ONCE}; dry_run=${DRY_RUN})"

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

  process_work_order "$next_file" || log_warn "⚠️ processing error for $next_file"

  if $RUN_ONCE; then
    log "✅ run_once completed"
    break
  fi
  sleep "$POLL_INTERVAL"

done
