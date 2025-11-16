#!/usr/bin/env zsh
# tools/reality_hooks_aggregate.zsh
#
# Aggregate "reality hook" signals from various reports into a single
# JSON snapshot. This is a passive collector: it never fails the build.

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
ROOT="${ROOT:-${SCRIPT_DIR:h}}"

REPORT_DIR="${ROOT}/g/reports/system"
SNAPSHOT_TS="$(date +'%Y%m%d_%H%M%S')"
SNAPSHOT_FILE="${REPORT_DIR}/reality_hooks_snapshot_${SNAPSHOT_TS}.json"

mkdir -p "${REPORT_DIR}"

log() {
  print -- "[$(date +'%Y-%m-%dT%H:%M:%S%z')] $*"
}

log "Reality Hooks aggregator starting..."
log "ROOT=${ROOT}"
log "REPORT_DIR=${REPORT_DIR}"
log "SNAPSHOT_FILE=${SNAPSHOT_FILE}"

# Simple JSON escaping helper (minimal)
escape_json() {
  local s="${1}"
  s="${s//\\/\\\\}"
  s="${s//"/\\"}"
  s="${s//$'\n'/\\n}"
  print -- "${s}"
}

# ---- Collect deployment reports (latest only) ----

latest_deploy_report=""
if ls "${REPORT_DIR}"/deployment_*.md >/dev/null 2>&1; then
  latest_deploy_report="$(ls -1t "${REPORT_DIR}"/deployment_*.md | head -n 1)"
  log "Found deployment report: ${latest_deploy_report}"
else
  log "No deployment report found"
fi

# ---- Collect save.sh full-cycle summaries ----

typeset -a save_summaries
save_summaries=()

if ls "${REPORT_DIR}"/save_sh_full_cycle_test_*.md >/dev/null 2>&1; then
  for f in $(ls -1t "${REPORT_DIR}"/save_sh_full_cycle_test_*.md | head -n 10); do
    log "Parsing save.sh full-cycle report: ${f}"
    typeset start_line end_line
    start_line=$(grep -n 'SAVE_SH_FULL_CYCLE_SUMMARY_START' "${f}" | cut -d: -f1 || true)
    end_line=$(grep -n 'SAVE_SH_FULL_CYCLE_SUMMARY_END' "${f}" | cut -d: -f1 || true)

    if [[ -n "${start_line}" && -n "${end_line}" && "${end_line}" -gt "${start_line}" ]]; then
      typeset block
      block=$(sed -n "$((start_line+1)),$((end_line-1))p" "${f}")
      # Turn key=value lines into a tiny JSON object
      typeset lane="unknown" layer1="unknown" layer2="unknown" layer3="unknown" layer4="unknown" git="unknown" test_id=""
      while IFS='=' read -r k v; do
        [[ -z "${k:-}" ]] && continue
        case "${k}" in
          lane) lane="${v}" ;;
          layer1) layer1="${v}" ;;
          layer2) layer2="${v}" ;;
          layer3) layer3="${v}" ;;
          layer4) layer4="${v}" ;;
          git) git="${v}" ;;
          test_id) test_id="${v}" ;;
        esac
      done <<< "${block}"

      save_summaries+="{\"file\":\"$(escape_json "${f}")\",\"test_id\":\"$(escape_json "${test_id}")\",\"lane\":\"$(escape_json "${lane}")\",\"layer1\":\"$(escape_json "${layer1}")\",\"layer2\":\"$(escape_json "${layer2}")\",\"layer3\":\"$(escape_json "${layer3}")\",\"layer4\":\"$(escape_json "${layer4}")\",\"git\":\"$(escape_json "${git}")\"}"
    else
      log "No summary block found in ${f}"
    fi
  done
else
  log "No save.sh full-cycle reports found"
fi

# ---- Collect orchestrator summary ----

orchestrator_summary_file="${REPORT_DIR}/claude_orchestrator_summary.json"
orchestrator_summary_json=""
if [[ -f "${orchestrator_summary_file}" ]]; then
  log "Found orchestrator summary: ${orchestrator_summary_file}"
  orchestrator_summary_json=$(cat "${orchestrator_summary_file}")
else
  log "No orchestrator summary JSON found"
fi

# ---- Emit aggregated JSON ----

{
  print -- "{"
  print -- "  \"timestamp\": \"${SNAPSHOT_TS}\"," 

  # Deployment
  if [[ -n "${latest_deploy_report}" ]]; then
    print -- "  \"deployment_report\": {"
    print -- "    \"path\": \"$(escape_json "${latest_deploy_report}")\""
    print -- "  },"
  else
    print -- "  \"deployment_report\": null,"
  fi

  # save.sh summaries
  print -- "  \"save_sh_full_cycle\": ["
  if (( ${#save_summaries[@]} > 0 )); then
    typeset i=1
    typeset n=${#save_summaries[@]}
    for entry in "${save_summaries[@]}"; do
      if (( i < n )); then
        print -- "    ${entry},"
      else
        print -- "    ${entry}"
      fi
      ((i++))
    done
  fi
  print -- "  ],"

  # Orchestrator summary (raw JSON if present)
  print -- "  \"orchestrator_summary\": "
  if [[ -n "${orchestrator_summary_json}" ]]; then
    # assume orchestrator_summary_json is already valid JSON
    print -- "${orchestrator_summary_json}"
  else
    print -- "null"
  fi

  print -- "}"
} > "${SNAPSHOT_FILE}"

log "Reality Hooks snapshot written to: ${SNAPSHOT_FILE}"
log "Reality Hooks aggregator finished successfully."
