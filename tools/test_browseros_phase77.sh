#!/usr/bin/env bash
set -euo pipefail

ROOT="${GITHUB_WORKSPACE:-$(pwd)}"
cd "${ROOT}"

REPORT_DIR="${REPORT_DIR:-g/reports}"
SUMMARY="${SUMMARY:-${REPORT_DIR}/phase7_7_summary.md}"
mkdir -p "${REPORT_DIR}"

TIMESTAMP="$(date -Iseconds)"
CLEAN_TS="${TIMESTAMP//[^0-9A-Za-z]/}"

{
  echo "# Phase 7.7 Verification — ${TIMESTAMP}"
  echo
  echo "## Repository Checks"
  echo "- Workspace root: ${ROOT}"
  echo "- Git revision: $(git rev-parse HEAD 2>/dev/null || echo 'unknown')"
  NODE_VERSION="$(node -v 2>/dev/null || echo 'not installed')"
  echo "- Node: ${NODE_VERSION}"
  PNPM_VERSION="$(pnpm -v 2>/dev/null || echo 'pnpm not installed')"
  echo "- pnpm: ${PNPM_VERSION}"
} > "${SUMMARY}"

JSON_REPORT="${REPORT_DIR}/web_actions_${CLEAN_TS}.json"
CSV_REPORT="${REPORT_DIR}/web_actions_${CLEAN_TS}.csv"

cat <<JSON > "${JSON_REPORT}"
{
  "phase": "7.7",
  "timestamp": "${TIMESTAMP}",
  "status": "generated",
  "workspace": "${ROOT}",
  "checks": {
    "node": "${NODE_VERSION}",
    "pnpm": "${PNPM_VERSION}"
  }
}
JSON

cat <<CSV > "${CSV_REPORT}"
metric,value
phase,7.7
timestamp,${TIMESTAMP}
workspace,${ROOT}
node,${NODE_VERSION}
pnpm,${PNPM_VERSION}
CSV

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    echo "# Phase 7.7 BrowserOS Verification"
    echo
    echo "- Generated summary: ${SUMMARY}"
    echo "- JSON report: ${JSON_REPORT}"
    echo "- CSV report: ${CSV_REPORT}"
  } >> "${GITHUB_STEP_SUMMARY}"
fi

printf 'Summary written to %s\n' "${SUMMARY}"
printf 'Web action JSON written to %s\n' "${JSON_REPORT}"
printf 'Web action CSV written to %s\n' "${CSV_REPORT}"
