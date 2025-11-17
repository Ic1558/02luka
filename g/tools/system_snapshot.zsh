#!/usr/bin/env zsh
set -euo pipefail

LABEL="default"
WO_API_URL_DEFAULT="http://localhost:3030/api/wos"

print_usage() {
  cat <<'USAGE'
Usage: tools/system_snapshot.zsh [--label <label>]

Generates a unified markdown snapshot under g/reports/system/ with
current git, agent, health, telemetry, and work-order reachability information.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --label)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --label" >&2
        exit 1
      fi
      LABEL="$2"
      shift 2
      ;;
    -h|--help)
      print_usage
      exit 0
      ;;
    *)
      echo "Unknown arg: $1" >&2
      print_usage >&2
      exit 1
      ;;
  esac
done

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

WO_API_URL="${WO_API_URL:-$WO_API_URL_DEFAULT}"

TS=$(date +"%Y%m%d_%H%M%S")
DATE_STR=$(date -R)
HOSTNAME_STR=$(hostname)
GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'unknown')
GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')
SAFE_LABEL="${LABEL//[^A-Za-z0-9._-]/_}"
[[ -z "$SAFE_LABEL" ]] && SAFE_LABEL="default"
SNAP_REL_PATH="reports/system/system_snapshot_${TS}_${SAFE_LABEL}.md"
SNAP_FILE="$ROOT_DIR/$SNAP_REL_PATH"
mkdir -p "$(dirname "$SNAP_REL_PATH")"

run_or_warn() {
  local section="$1"
  shift
  local output
  if ! output="$("$@" 2>&1)"; then
    printf '⚠️ Failed to collect %s: %s\n' "$section" "$output"
  else
    printf '%s\n' "$output"
  fi
}

collect_git_section() {
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo '```'
    run_or_warn "git status" git status --short
    echo '```'
    echo ""
    echo "Recent commits:"
    echo '```'
    run_or_warn "git log" git log --oneline -n 5
    echo '```'
  else
    echo "_Not a git repo_"
  fi
}

collect_mcp_health() {
  local path="reports/mcp_health/latest.md"
  if [[ -f "$path" ]]; then
    echo "_Tail of ${path}_"
    echo '```'
    run_or_warn "tail mcp health" tail -n 40 "$path"
    echo '```'
  else
    echo "_No ${path} found_"
  fi
}

collect_telemetry() {
  local path="telemetry_unified/unified.jsonl"
  if [[ -f "$path" ]]; then
    local total
    total=$(wc -l < "$path" 2>/dev/null || echo 0)
    echo "- unified.jsonl lines: ${total}"
    echo "- Last 5 entries:"
    echo '```'
    run_or_warn "tail telemetry" tail -n 5 "$path"
    echo '```'
  else
    echo "_No ${path} found_"
  fi
}

collect_wo_snapshot() {
  local url="$WO_API_URL"
  if [[ -z "$url" ]]; then
    echo "WO dashboard check skipped (WO_API_URL not set)"
    return
  fi
  if ! command -v curl >/dev/null 2>&1; then
    echo "curl not available; cannot reach ${url}"
    return
  fi
  if curl -fsS --max-time 5 "$url" -o /dev/null; then
    echo "WO dashboard reachable: yes (${url})"
  else
    local status=$?
    echo "⚠️ Failed to collect WO dashboard status (curl exit ${status}) for ${url}"
  fi
}

AGENT_SUMMARY="Agents up: unavailable"
AGENT_DETAILS=""
AGENT_HEADER=""
if command -v launchctl >/dev/null 2>&1; then
  LAUNCH_RAW=$(launchctl list 2>/dev/null | grep -i "02luka" || true)
  if [[ -z "$LAUNCH_RAW" ]]; then
    AGENT_DETAILS="No 02luka labels found or launchctl blocked"
    AGENT_SUMMARY="Agents up: 0 running, 0 stopped, 0 failed"
  else
    running=0
    stopped=0
    failed=0
    while read -r pid status label rest; do
      [[ -z "$pid" ]] && continue
      [[ "$pid" == "PID" ]] && continue
      if [[ "$pid" == "-" ]]; then
        (( stopped++ ))
      else
        (( running++ ))
      fi
      if [[ "$status" != "0" ]]; then
        (( failed++ ))
      fi
    done <<< "$LAUNCH_RAW"
    AGENT_SUMMARY="Agents up: ${running} running, ${stopped} stopped, ${failed} failed"
    AGENT_HEADER="PID STATUS LABEL"
    AGENT_DETAILS="$LAUNCH_RAW"
  fi
else
  AGENT_DETAILS="launchctl not available"
  AGENT_SUMMARY="Agents up: unavailable (launchctl not present)"
fi

{
  echo "# System Snapshot — ${TS}"
  echo ""
  echo "- Timestamp: ${DATE_STR}"
  echo "- Host: ${HOSTNAME_STR}"
  echo "- Branch: ${GIT_BRANCH}"
  echo "- Commit: ${GIT_COMMIT}"
  echo "- Snapshot label: ${LABEL}"
  echo "- ${AGENT_SUMMARY}"
  echo ""
  echo "## Git Status"
  collect_git_section
  echo ""
  echo "## LaunchAgent / Services (02luka)"
  echo '```'
  if [[ -n "$AGENT_DETAILS" ]]; then
    if [[ -n "$AGENT_HEADER" ]]; then
      printf '%s\n' "$AGENT_HEADER"
    fi
    printf '%s\n' "$AGENT_DETAILS"
  else
    echo "No data collected"
  fi
  echo '```'
  echo ""
  echo "## MCP / Health Snapshot"
  collect_mcp_health
  echo ""
  echo "## Telemetry (unified) — basic stats"
  collect_telemetry
  echo ""
  echo "## Work Order Snapshot"
  collect_wo_snapshot
  echo ""
  echo "## Notes"
  echo "- Report stored at ${SNAP_REL_PATH}"
} > "$SNAP_FILE"

printf 'Snapshot written to %s\n' "$SNAP_REL_PATH"
