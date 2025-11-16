#!/usr/bin/env zsh
# tools/reality_hooks_advisory_check.zsh
#
# Read the latest Reality Hooks snapshot and emit a human-readable
# advisory report. This script is intentionally non-blocking:
# it always exits 0 so it cannot break CI.

set -euo pipefail
setopt NULL_GLOB

SCRIPT_DIR="${0:A:h}"
ROOT="${ROOT:-${SCRIPT_DIR:h}}"
REPORT_DIR="${ROOT}/g/reports/system"

mkdir -p "${REPORT_DIR}"

TS="$(date +'%Y%m%d_%H%M%S')"
REPORT_FILE="${REPORT_DIR}/reality_hooks_advisory_${TS}.md"
LATEST_LINK="${REPORT_DIR}/reality_hooks_advisory_latest.md"

log() {
  print -- "[$(date +'%Y-%m-%dT%H:%M:%S%z')] $*"
}

log "Reality Hooks advisory check starting..."
log "ROOT=${ROOT}"
log "REPORT_DIR=${REPORT_DIR}"

# Find latest snapshot
snapshot_file=""
snapshot_candidates=("${REPORT_DIR}"/reality_hooks_snapshot_*.json)
if (( ${#snapshot_candidates} )); then
  snapshot_file="$(ls -1t "${snapshot_candidates[@]}" | head -n 1)"
  log "Using snapshot: ${snapshot_file}"
else
  log "No Reality Hooks snapshot found; generating 'no_data' advisory."
fi

# Default data
snapshot_ts="unknown"
deployment_path=""
save_runs_json="[]"
orchestrator_json="null"

if [[ -n "${snapshot_file}" ]]; then
  # shellcheck disable=SC2002
  raw_json="$(cat "${snapshot_file}")"

  # Extract fields using jq if available; otherwise fall back to simple grep
  if command -v jq >/dev/null 2>&1; then
    snapshot_ts="$(print -- "${raw_json}" | jq -r '.timestamp // "unknown"')"
    deployment_path="$(print -- "${raw_json}" | jq -r '.deployment_report.path // ""')"
    save_runs_json="$(print -- "${raw_json}" | jq -c '.save_sh_full_cycle // []')"
    orchestrator_json="$(print -- "${raw_json}" | jq -c '.orchestrator_summary // null')"
  else
    # Minimal fallback; advisory will just say "jq missing"
    snapshot_ts="unknown (jq not installed)"
  fi
else
  snapshot_ts="no_snapshot"
fi

# Derive advisory signals from save_runs_json when jq exists
save_summary="no_data"
save_issues="[]"
if command -v jq >/dev/null 2>&1 && [[ "${save_runs_json}" != "[]" ]]; then
  total_runs=$(print -- "${save_runs_json}" | jq 'length')
  ok_runs=$(print -- "${save_runs_json}" | jq '[.[] | select(.layer1=="ok" and .layer2=="ok" and .layer3=="ok" and .layer4=="ok")] | length')
  degraded_runs=$(( total_runs - ok_runs ))

  save_summary="total=${total_runs}, ok=${ok_runs}, degraded=${degraded_runs}"
  save_issues=$(print -- "${save_runs_json}" | jq -c '[.[] | select(.layer1!="ok" or .layer2!="ok" or .layer3!="ok" or .layer4!="ok")]')
fi

# Orchestrator advisory
orch_status="no_data"
if command -v jq >/dev/null 2>&1 && [[ "${orchestrator_json}" != "null" ]]; then
  agent_count=$(print -- "${orchestrator_json}" | jq -r '.agents_count // .agents // empty' 2>/dev/null || print -- "")
  orch_status="summary_present"
  if [[ -n "${agent_count}" ]]; then
    orch_status+=" (agents=${agent_count})"
  fi
fi

# --- Compose Markdown report ---

{
  print -- "# Reality Hooks Advisory Report (${TS})"
  print -- ""
  print -- "Snapshot timestamp: \`${snapshot_ts}\`"
  if [[ -n "${snapshot_file}" ]]; then
    print -- ""
    print -- "- Snapshot file: \`${snapshot_file}\`"
  else
    print -- ""
    print -- "- Snapshot file: *(none found)*"
  fi
  print -- ""

  print -- "## Deployment"
  if [[ -n "${deployment_path}" ]]; then
    print -- ""
    print -- "- Latest deployment report: \`${deployment_path}\`"
    print -- "- Advisory: **ok** (deployment report present; see file for details)"
  else
    print -- ""
    print -- "- Latest deployment report: *(none in snapshot)*"
    print -- "- Advisory: **no_data** – run a deployment or Reality Hooks snapshot to populate this."
  fi
  print -- ""

  print -- "## save.sh Full-Cycle Tests"
  print -- ""
  if [[ "${snapshot_ts}" == "no_snapshot" ]]; then
    print -- "- Advisory: **no_snapshot** – Reality Hooks snapshot has not been generated yet."
  elif [[ "${save_summary}" == "no_data" ]]; then
    print -- "- Advisory: **no_data** – no save.sh runs found in snapshot."
  else
    print -- "- Summary: \`${save_summary}\`"
    if command -v jq >/dev/null 2>&1; then
      degraded_count=$(print -- "${save_issues}" | jq 'length')
      if [[ "${degraded_count}" -gt 0 ]]; then
        print -- "- Advisory: **degraded** – some runs have non-ok layers."
        print -- ""
        print -- "### Degraded runs"
        print -- ""
        print -- "\`\`\`json"
        print -- "${save_issues}"
        print -- "\`\`\`"
      else
        print -- "- Advisory: **ok** – all recorded layers are ok."
      fi
    else
      print -- "- Advisory: **unknown** – jq not installed; cannot inspect per-layer status."
    fi
  fi
  print -- ""

  print -- "## Orchestrator Summary"
  print -- ""
  if [[ "${orch_status}" == "no_data" ]]; then
    print -- "- Advisory: **no_data** – no orchestrator summary found in snapshot."
  else
    print -- "- Advisory: **ok** – orchestrator summary present (${orch_status})."
  fi

} > "${REPORT_FILE}"

# Update latest symlink/file
ln -sf "$(basename "${REPORT_FILE}")" "${LATEST_LINK}" 2>/dev/null || {
  # Fallback: copy if symlinks not allowed
  cp "${REPORT_FILE}" "${LATEST_LINK}"
}

log "Reality Hooks advisory report written to: ${REPORT_FILE}"
log "Latest link updated: ${LATEST_LINK}"
log "Reality Hooks advisory check finished successfully."

exit 0
