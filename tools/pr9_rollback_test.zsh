#!/usr/bin/env zsh
set -euo pipefail

BASE="${LUKA_SOT:-$HOME/02luka}"
INBOX="$BASE/bridge/inbox/main"
TEST_FILE="$BASE/g/reports/feature-dev/governance_v5_unified_law/pr_battle_tests/PR9_ROLLBACK_TEST.md"

mkdir -p "$(dirname "$TEST_FILE")" "$INBOX"

echo "🔄 PR-9 Rollback Test Setup"
echo ""

############################
# Step 1: Create GOOD state baseline
############################
echo "📝 Step 1: Creating GOOD state baseline..."

cat > "$TEST_FILE" <<'EOF'
PR-9 ROLLBACK TEST — GOOD STATE

This is the original content that must be restored after rollback.
EOF

# Create checksum before
shasum -a 256 "$TEST_FILE" > "${TEST_FILE}.sha256.before"
echo "✅ Baseline created: $TEST_FILE"
echo "   Checksum (before): $(cat "${TEST_FILE}.sha256.before" | cut -d' ' -f1)"

# Git commit baseline (if git is available)
if command -v git >/dev/null 2>&1; then
    cd "$BASE"
    if git status --porcelain "$TEST_FILE" 2>/dev/null | grep -q .; then
        git add "$TEST_FILE" 2>/dev/null || true
        git commit -m "PR-9 rollback baseline" 2>/dev/null || true
        echo "✅ Git baseline committed"
    fi
fi

############################
# Step 2: Create WO that modifies file (STRICT → CLC)
############################
echo ""
echo "📥 Step 2: Creating WO to modify file (STRICT lane)..."

cat > "$INBOX/WO-PR9-ROLLBACK-TEST.yaml" <<'YAML'
wo_id: WO-PR9-ROLLBACK-TEST
version: v1
source: pr9_rollback
trigger: background
actor: CLC
strict_target: CLC

target_paths:
  - "g/reports/feature-dev/governance_v5_unified_law/pr_battle_tests/PR9_ROLLBACK_TEST.md"

operations:
  - type: write_file
    path: "g/reports/feature-dev/governance_v5_unified_law/pr_battle_tests/PR9_ROLLBACK_TEST.md"
    mode: replace
    content: |
      PR-9 ROLLBACK TEST — BROKEN STATE

      If you see this content after rollback, v5 rollback failed.

rollback:
  enabled: true
  strategy: git_revert
  reason: "PR-9 rollback drill"
  safety_level: high
YAML

echo "✅ WO created: WO-PR9-ROLLBACK-TEST.yaml"
echo "   Waiting for CLC to process..."
echo "   (Check: ls -la $INBOX/WO-PR9-ROLLBACK-TEST.yaml)"
echo ""
echo "⏳ After CLC processes, run:"
echo "   zsh $BASE/tools/pr9_rollback_execute.zsh"

