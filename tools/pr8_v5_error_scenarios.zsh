#!/usr/bin/env zsh
set -euo pipefail

BASE="${LUKA_SOT:-$HOME/02luka}"
INBOX="$BASE/bridge/inbox/MAIN"
REPORT_DIR="$BASE/g/reports/feature-dev/governance_v5_unified_law/pr_battle_tests"

mkdir -p "$INBOX" "$REPORT_DIR"

ts_utc="$(date -u +"%Y%m%dT%H%M%SZ")"

echo "📥 Dropping PR-8 test WOs into $INBOX"
echo "  timestamp: $ts_utc"

############################
# 1) INVALID YAML (parse error)
############################
cat > "$INBOX/WO-PR8-INVALID-YAML.yaml" <<'YAML'
wo_id: WO-PR8-INVALID-YAML
version: v1
source: pr8_invalid_yaml
trigger: cursor
actor: GG
operations:
  - type: write_file
    path: g/reports/feature-dev/governance_v5_unified_law/pr_battle_tests/pr8_invalid_yaml.txt
    mode: replace
    content: |
      This line is ok
    broken_field: [unclosed
YAML

############################
# 2) FORBIDDEN PATH (DANGER zone)
############################
cat > "$INBOX/WO-PR8-FORBIDDEN-PATH.yaml" <<'YAML'
wo_id: WO-PR8-FORBIDDEN-PATH
version: v1
source: pr8_forbidden_path
trigger: cursor
actor: GG
target_paths:
  - "/usr/local/pr8_forbidden_path.txt"
operations:
  - type: write_file
    path: "/usr/local/pr8_forbidden_path.txt"
    mode: replace
    content: |
      PR-8 forbidden path test
      This MUST be blocked by SandboxGuard v5 as DANGER zone.
routing:
  requested_lane: FAST
  allow_strict_escalation: false
YAML

############################
# 3) SANDBOX VIOLATION (forbidden content)
############################
cat > "$INBOX/WO-PR8-SANDBOX-VIOLATION.yaml" <<'YAML'
wo_id: WO-PR8-SANDBOX-VIOLATION
version: v1
source: pr8_sandbox_violation
trigger: cursor
actor: GG
target_paths:
  - "g/reports/feature-dev/governance_v5_unified_law/pr_battle_tests/pr8_sandbox_violation.sh"
operations:
  - type: write_file
    path: "g/reports/feature-dev/governance_v5_unified_law/pr_battle_tests/pr8_sandbox_violation.sh"
    mode: replace
    content: |
      #!/usr/bin/env bash
      # THIS MUST NEVER RUN
      rm -rf /
      echo "If this ever executes, SandboxGuard v5 is broken."
YAML

echo "✅ PR-8 WOs created:"
ls -1 "$INBOX"/WO-PR8-*.yaml || true

