#!/usr/bin/env zsh
# Ensure WO pipeline prerequisites are healthy

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$SCRIPT_DIR/lib_wo_common.zsh"

STATE_DIR="$REPO_ROOT/followup/state"
INBOX_DIR="$REPO_ROOT/bridge/inbox/CLC"

main() {
  local -a errors
  local -a required_files=(
    "$REPO_ROOT/tools/wo_pipeline/lib_wo_common.zsh"
    "$REPO_ROOT/tools/wo_pipeline/apply_patch_processor.zsh"
    "$REPO_ROOT/tools/wo_pipeline/json_wo_processor.zsh"
    "$REPO_ROOT/tools/wo_pipeline/wo_executor.zsh"
    "$REPO_ROOT/tools/wo_pipeline/followup_tracker.zsh"
    "$REPO_ROOT/tools/wo_pipeline/wo_pipeline_guardrail.zsh"
    "$REPO_ROOT/tools/wo_pipeline/test_wo_pipeline_e2e.zsh"
  )

  for required in "${required_files[@]}"; do
    [[ -f "$required" ]] || errors+=("Missing file: $required")
    [[ -x "$required" ]] || errors+=("Not executable: $required")
  done

  if [[ -n "${WO_PIPELINE_GUARD_TRACE:-}" ]]; then
    log_info "wo_pipeline_guardrail PATH=$PATH"
    log_info "python_bin=${WO_PIPELINE_PYTHON_BIN:-unset}"
    log_info "jq_loc=$(command -v jq 2>&1 || echo 'missing')"
    local trace_env_file="${TMPDIR:-/tmp}/wo_pipeline_guardrail.env"
    /usr/bin/env > "$trace_env_file"
    log_info "env dumped to $trace_env_file"
  fi

  local python_bin="${WO_PIPELINE_PYTHON_BIN:-}"
  [[ -n "$python_bin" && -x "$python_bin" ]] || errors+=("python3 not found")

  if ! jq --version >/dev/null 2>&1; then
    errors+=("jq not found")
  fi

  if [[ -n "$python_bin" ]] && ! "$python_bin" -c 'import yaml' >/dev/null 2>&1; then
    errors+=("PyYAML not available (pip install PyYAML)")
  fi

  [[ -d "$STATE_DIR" ]] || errors+=("Missing state dir: $STATE_DIR")
  [[ -d "$INBOX_DIR" ]] || errors+=("Missing inbox dir: $INBOX_DIR")

  if [[ -d "$STATE_DIR" && ! -w "$STATE_DIR" ]]; then
    errors+=("State dir not writable: $STATE_DIR")
  fi

  if [[ -d "$INBOX_DIR" && ! -w "$INBOX_DIR" ]]; then
    errors+=("Inbox dir not writable: $INBOX_DIR")
  fi

  local health_status="ok"
  (( ${#errors[@]} )) && health_status="error"

  local error_payload=""
  if (( ${#errors[@]} )); then
    error_payload="$(printf '%s\n' "${errors[@]}")"
  fi

  HEALTH_ERRORS="$error_payload" "$WO_PIPELINE_PYTHON_BIN" - "$health_status" "$STATE_DIR" "$INBOX_DIR" <<'PY'
import json, sys, pathlib, datetime, os
status = sys.argv[1]
state_dir = sys.argv[2]
inbox_dir = sys.argv[3]
errors = [line for line in os.environ.get('HEALTH_ERRORS', '').splitlines() if line.strip()]
payload = {
    'checked_at': datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
    'status': status,
    'state_dir': state_dir,
    'inbox_dir': inbox_dir,
    'errors': errors,
    'recommendation': 'run apply_patch -> json_wo -> wo_executor -> followup_tracker' if status == 'error' else 'pipeline healthy'
}
print(json.dumps(payload, indent=2))
PY

  if (( ${#errors[@]} )); then
    exit 1
  fi
}

main "$@"
