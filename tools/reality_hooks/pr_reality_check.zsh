#!/usr/bin/env zsh
# Lightweight reality hooks runner for PRs.
# Runs a small set of real-world checks and emits a machine-readable summary.

set -euo pipefail

ROOT="${ROOT:-${0:A:h:h}}"  # default: two levels up from this script (repo root)
REPORT_DIR="${ROOT}/g/reports/system"
mkdir -p "${REPORT_DIR}"

GIT_SHA="${GITHUB_SHA:-$(git -C "${ROOT}" rev-parse --short HEAD 2>/dev/null || echo 'local')}"
REPORT_FILE="${REPORT_DIR}/reality_hooks_pr_${GIT_SHA}.md"

dashboard_status="skipped"
orchestrator_status="skipped"
telemetry_status="skipped"

log() {
  print -- "[$(date +'%Y-%m-%dT%H:%M:%S%z')] $*" >&2
}

# Helper: run a command, capture status, and log
run_check() {
  local name="$1"; shift
  local cmd=("$@")

  log "Running reality hook: ${name}: ${cmd[@]}"
  if "${cmd[@]}" >/tmp/reality_hook_${name}.log 2>&1; then
    log "✅ ${name} OK"
    echo "ok"
  else
    log "❌ ${name} FAILED"
    log "---- ${name} output ----"
    sed -n '1,80p' "/tmp/reality_hook_${name}.log" >&2 || true
    log "------------------------"
    echo "failed"
  fi
  return 0
}

# 1) Dashboard smoke test ( BEST-EFFORT )
dashboard_hook() {
  # You may already have a dedicated dashboard health command; if not, make this
  # a cheap static check that proves the module can be loaded / config is sane.
  if [ ! -f "${ROOT}/apps/dashboard/wo_dashboard_server.js" ]; then
    log "Dashboard hook: server file not found, marking as skipped."
    echo "skipped"
    return 0
  fi

  if ! command -v node >/dev/null 2>&1; then
    log "Dashboard hook: node command not available, marking as skipped."
    echo "skipped"
    return 0
  fi

  # Very light Node check: does the file parse?
  run_check "dashboard_smoke" node -c "${ROOT}/apps/dashboard/wo_dashboard_server.js"
}

# 2) Orchestrator reality hook
orchestrator_hook() {
  if [ ! -f "${ROOT}/tools/claude_subagents/orchestrator.zsh" ]; then
    log "Orchestrator hook: script not found, marking as skipped."
    echo "skipped"
    return 0
  fi

  local summary="${ROOT}/g/reports/system/claude_orchestrator_summary.json"
  rm -f "${summary}"

  # This should match the command you used in the post-deploy check.
  local orchestrator_cmd=(env LUKA_SOT="${ROOT}" "${ROOT}/tools/claude_subagents/orchestrator.zsh" review "true" 1)

  if [ "$(run_check "orchestrator_smoke" "${orchestrator_cmd[@]}")" = "ok" ]; then
    if [ -f "${summary}" ]; then
      # Quick JSON sanity check using node if available, else best-effort.
      if command -v node >/dev/null 2>&1; then
        if node -e "JSON.parse(require('fs').readFileSync('${summary}','utf8'))" 2>/dev/null; then
          echo "ok"
          return 0
        else
          log "Orchestrator summary JSON parse failed."
          echo "failed"
          return 0
        fi
      fi
      echo "ok"
      return 0
    else
      log "Orchestrator summary file not found after run."
      echo "failed"
      return 0
    fi
  else
    echo "failed"
    return 0
  fi
}

# 3) Telemetry schema vs sample (light check)
telemetry_hook() {
  local schema_candidates=(
    "${ROOT}/g/schemas/telemetry_v2.schema.json"
    "${ROOT}/schemas/telemetry_v2.schema.json"
  )
  local sample_candidates=(
    "${ROOT}/g/telemetry_unified/unified.jsonl"
    "${ROOT}/telemetry_unified/unified.jsonl"
    "${ROOT}/telemetry/unified.jsonl"
  )

  local schema=""
  local sample=""

  for candidate in "${schema_candidates[@]}"; do
    if [ -z "${schema}" ] && [ -f "${candidate}" ]; then
      schema="${candidate}"
    fi
  done

  for candidate in "${sample_candidates[@]}"; do
    if [ -z "${sample}" ] && [ -f "${candidate}" ]; then
      sample="${candidate}"
    fi
  done

  if [ -z "${schema}" ] || [ -z "${sample}" ]; then
    log "Telemetry hook: schema or sample missing, marking as skipped."
    echo "skipped"
    return 0
  fi

  if ! command -v python3 >/dev/null 2>&1; then
    log "Telemetry hook: python3 not available, marking as skipped."
    echo "skipped"
    return 0
  fi

  local script="${ROOT}/.tmp_telemetry_schema_check_${GIT_SHA}.py"
  cat > "${script}" <<'PY'
import json, sys, pathlib

schema_path = pathlib.Path(sys.argv[1])
sample_path = pathlib.Path(sys.argv[2])

schema = json.loads(schema_path.read_text())
required = schema.get("required", [])

# Read only first line to keep it cheap
first = None
with sample_path.open() as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            first = json.loads(line)
            break
        except json.JSONDecodeError:
            # Skip malformed lines and keep searching for the first valid JSON record
            continue

if first is None:
    print("No telemetry records found.")
    sys.exit(0)

missing = [k for k in required if k not in first]
if missing:
    print("Missing required keys in sample:", ", ".join(missing))
    sys.exit(1)

print("Telemetry sample matches required keys.")
PY

  local hook_status
  hook_status="$(run_check "telemetry_schema" python3 "${script}" "${schema}" "${sample}")"
  rm -f "${script}" || true
  echo "${hook_status}"
}

# Run hooks
log "=== Running PR reality hooks ==="

dashboard_status="$(dashboard_hook)"
orchestrator_status="$(orchestrator_hook)"
telemetry_status="$(telemetry_hook)"

# Determine overall exit code
exit_code=0
for s in "${dashboard_status}" "${orchestrator_status}" "${telemetry_status}"; do
  if [ "${s}" = "failed" ]; then
    exit_code=1
  fi
done

# Generate Markdown report
log "Writing reality hooks report to ${REPORT_FILE}"

cat > "${REPORT_FILE}" <<__REPORT__
# Reality Hooks Report

- Commit: ${GIT_SHA}

## Checks

- Dashboard smoke: \`${dashboard_status}\`
- Orchestrator summary: \`${orchestrator_status}\`
- Telemetry schema: \`${telemetry_status}\`

## Notes

This report was generated by \`tools/reality_hooks/pr_reality_check.zsh\`
during CI or local execution.

__REPORT__

# Emit machine-readable summary for pr_score / other agents
cat <<__SUMMARY__

REALITY_HOOKS_SUMMARY_START
dashboard_smoke=${dashboard_status}
orchestrator_smoke=${orchestrator_status}
telemetry_schema=${telemetry_status}
REALITY_HOOKS_SUMMARY_END
__SUMMARY__

log "Reality hooks completed with status=${exit_code}"
exit "${exit_code}"
