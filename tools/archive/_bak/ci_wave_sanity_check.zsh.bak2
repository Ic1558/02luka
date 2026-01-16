#!/usr/bin/env zsh
set -euo pipefail

# Basic CI / safety wave sanity check
# - Lists key workflows and their presence
# - Summarizes last commit touching each
# - Verifies that required system reports exist

SCRIPT_DIR="${0:A:h}"
BASE_DIR="${SCRIPT_DIR:A:h:h}"        # .../g/tools -> .../g
REPO_ROOT="${BASE_DIR:A:h}"           # .../g      -> ~/02luka (expected)

WORKFLOWS_DIR="$REPO_ROOT/.github/workflows"
REPORTS_DIR="$BASE_DIR/reports/system"

header() {
  print ""
  print "== $1 =="
}

info() {
  print "  - $1"
}

fail() {
  print "  [!] $1" >&2
}

ok() {
  print "  [+] $1"
}

# 1) Sanity: directories
header "Directories"

if [[ -d "$WORKFLOWS_DIR" ]]; then
  ok ".github/workflows found at: $WORKFLOWS_DIR"
else
  fail ".github/workflows missing at: $WORKFLOWS_DIR"
fi

if [[ -d "$REPORTS_DIR" ]]; then
  ok "system reports dir found at: $REPORTS_DIR"
else
  fail "system reports dir missing at: $REPORTS_DIR"
fi

# 2) Key workflows presence (READ-ONLY)
header "Key workflows presence (read-only)"

typeset -a REQUIRED_WORKFLOWS
REQUIRED_WORKFLOWS=(
  "ci.yml"
  "codex_sandbox.yml"
  "memory_guard.yml"
  "path_guard.yml"
  "system-telemetry-v2.yml"
)

for wf in "${REQUIRED_WORKFLOWS[@]}"; do
  local_path="$WORKFLOWS_DIR/$wf"
  if [[ -f "$local_path" ]]; then
    ok "$wf"
  else
    fail "$wf (missing)"
  fi
done

# 3) Last commit touching each workflow
header "Recent changes per workflow"

for wf in "${REQUIRED_WORKFLOWS[@]}"; do
  local_path=".github/workflows/$wf"
  if git -C "$REPO_ROOT" ls-files --error-unmatch "$local_path" >/dev/null 2>&1; then
    last_commit="$(git -C "$REPO_ROOT" log -n 1 --pretty=format:'%h %cd %s' -- "$local_path" 2>/dev/null || true)"
    info "$wf -> ${last_commit:-no history found}"
  else
    info "$wf -> not tracked in git"
  fi
done

# 4) Required reports from the safety wave
header "Wave system reports (presence check)"

typeset -a REQUIRED_REPORTS
REQUIRED_REPORTS=(
  "deployment_20251115_052838.md"
  "governance_lock_in_20251115.md"
  "orchestrator_restore_20251115.md"
  "telemetry_schema_ci_fix_20251115.md"
  "codex_sandbox_workflow_fix_20251115.md"
  "memory_guard_zsh_fix_20251115.md"
  "orchestrator_summary_v2_feature_20251116.md"
  "wo_history_timeline_feature_20251116.md"
)

for rep in "${REQUIRED_REPORTS[@]}"; do
  path="$REPORTS_DIR/$rep"
  if [[ -f "$path" ]]; then
    ok "$rep"
  else
    fail "$rep (missing)"
  fi
done

header "Summary"

print "  This script is READ-ONLY: no workflow, security, or dashboard code was modified."
print "  Use it as a quick sanity check after merging CI/safety PRs."
