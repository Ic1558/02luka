#!/usr/bin/env zsh
# ═══════════════════════════════════════════════════════════════════════
# Create Clean PR Branch - Copy-Paste Ready Commands
# ═══════════════════════════════════════════════════════════════════════
# This script creates a truly clean PR branch from origin/main
# and pulls only the necessary core files using git show
# ═══════════════════════════════════════════════════════════════════════

set -euo pipefail

cd ~/02luka

# Step 1: Fetch and ensure we're starting from clean main
echo "🔧 Step 1: Fetching and resetting to origin/main"
git fetch origin
git checkout v5-core-pr-clean2 2>/dev/null || git checkout -b v5-core-pr-clean2 origin/main
git reset --hard origin/main
git clean -fd

# Step 2: Pull core files using git show (deterministic snapshot)
echo ""
echo "📦 Step 2: Pulling core files from v5-core-clean"
mkdir -p agents/mary_router agents/mary bridge/core tools g/reports/system

git show v5-core-clean:agents/mary_router/gateway_v3_router.py > agents/mary_router/gateway_v3_router.py
git show v5-core-clean:agents/mary/mary.py > agents/mary/mary.py
git show v5-core-clean:bridge/core/router_v5.py > bridge/core/router_v5.py
git show v5-core-clean:bridge/core/sandbox_guard_v5.py > bridge/core/sandbox_guard_v5.py
git show v5-core-clean:bridge/core/wo_processor_v5.py > bridge/core/wo_processor_v5.py
git show v5-core-clean:tools/monitor_v5_production.zsh > tools/monitor_v5_production.zsh
git show v5-core-clean:g/reports/system/launchagent_repair_PHASE2C_MINI_RECIPE_MARY_COO.md > g/reports/system/launchagent_repair_PHASE2C_MINI_RECIPE_MARY_COO.md 2>/dev/null || echo "  ⚠️  Doc not in branch, skipping"
git show v5-core-clean:MERGE_NOTE_v5_battle_tested.md > MERGE_NOTE_v5_battle_tested.md 2>/dev/null || echo "  ⚠️  Merge note not in branch, skipping"
git show v5-core-clean:RELEASE_NOTE_v5_battle_tested.md > RELEASE_NOTE_v5_battle_tested.md 2>/dev/null || echo "  ⚠️  Release note not in branch, skipping"

# Copy PR documentation files from current working directory (if they exist)
if [[ -f ~/02luka/PR_DESCRIPTION_v5_core.md ]]; then
    cp ~/02luka/PR_DESCRIPTION_v5_core.md PR_DESCRIPTION_v5_core.md
    echo "  ✅ Copied PR_DESCRIPTION_v5_core.md"
fi
if [[ -f ~/02luka/PR11_PR12_CHECKLIST.md ]]; then
    cp ~/02luka/PR11_PR12_CHECKLIST.md PR11_PR12_CHECKLIST.md
    echo "  ✅ Copied PR11_PR12_CHECKLIST.md"
fi

# Step 3: Verify clean (should show only core files)
echo ""
echo "🔍 Step 3: Verifying clean state"
echo "--- git status --porcelain ---"
git status --porcelain

echo ""
echo "--- git diff --name-only origin/main...HEAD ---"
git diff --name-only origin/main...HEAD

echo ""
echo "--- Checking for risky files ---"
if git diff --name-only origin/main...HEAD | grep -E '(^\.env|^\.DS_Store|^\.claude/|^\.cursor/|^\.vscode/|\.code-workspace$)' >/dev/null; then
    echo "  🚨 STILL DIRTY - Risky files detected!"
    exit 1
else
    echo "  ✅ CLEAN - No risky files"
fi

# Step 4: Commit
echo ""
echo "📝 Step 4: Committing core files"
git add agents/mary_router/gateway_v3_router.py \
        agents/mary/mary.py \
        bridge/core/router_v5.py \
        bridge/core/sandbox_guard_v5.py \
        bridge/core/wo_processor_v5.py \
        tools/monitor_v5_production.zsh \
        g/reports/system/launchagent_repair_PHASE2C_MINI_RECIPE_MARY_COO.md \
        MERGE_NOTE_v5_battle_tested.md \
        RELEASE_NOTE_v5_battle_tested.md \
        PR_DESCRIPTION_v5_core.md \
        PR11_PR12_CHECKLIST.md 2>/dev/null || true

git commit -m "fix(v5): core runtime stability + gateway single-process (battle-tested hardening)

- Gateway v3: handle v5 statuses (COMPLETED/EXECUTING/REJECTED/FAILED) + no legacy fallback
- Router v5: CLS auto-approve supports OPEN+whitelist (PR-10 intent) + trigger hardening
- SandboxGuard v5: security gaps fixed (null byte/newline/traversal variants)
- Monitor: 24h window filters by timestamp + git command safe (-- separator)
- Mary-COO: separate dispatcher (agents/mary/mary.py) - no gateway conflicts"

# Step 5: Final verification
echo ""
echo "✅ Step 5: Final verification"
echo "--- git diff --stat origin/main...HEAD ---"
git diff --stat origin/main...HEAD

echo ""
echo "✅ Clean PR branch ready!"
echo ""
echo "📋 Next: Open PR with:"
echo "  gh pr create --base main --head v5-core-pr-clean2 \\"
echo "    --title 'Governance v5 Battle-Tested Hardening + Gateway Single-Process Stability' \\"
echo "    --body-file PR_DESCRIPTION_v5_core.md \\"
echo "    --label 'core,governance-v5,breaking-ops,battle-tested'"
echo ""
echo "Or review diff first:"
echo "  git diff --stat origin/main...HEAD"
echo "  git diff origin/main...HEAD -- agents/ bridge/core/ tools/monitor_v5_production.zsh"

