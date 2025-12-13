#!/usr/bin/env zsh
# PR-11 Daily Snapshot - Atomic Workflow
# Generates snapshot, commits, and pushes with guard checks
# Usage: zsh tools/pr11_snapshot_daily.zsh

set -euo pipefail

# Ensure a sane PATH
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

REPO="${HOME}/02luka"
cd "$REPO"

# Step 1: Guard check (must pass)
echo "== Step 1: Guard Check =="
if ! zsh tools/guard_workspace_inside_repo.zsh >/dev/null 2>&1; then
  echo "❌ Guard check failed. Fix workspace issues before creating snapshot." >&2
  exit 1
fi
echo "✅ Guard check passed"

# Step 2: Generate snapshot
echo "== Step 2: Generate Snapshot =="
SNAPSHOT_DIR="g/reports/pr11_healthcheck"
mkdir -p "$SNAPSHOT_DIR"

SNAPSHOT_FILE="${SNAPSHOT_DIR}/$(date +%F)T$(date +%H%M%S).json"

if ! zsh tools/monitor_v5_production.zsh json > "$SNAPSHOT_FILE" 2>&1; then
  echo "❌ Failed to generate snapshot" >&2
  exit 1
fi

echo "✅ Snapshot created: $SNAPSHOT_FILE"

# Step 3: Verify snapshot is valid JSON
if ! python3 -m json.tool "$SNAPSHOT_FILE" >/dev/null 2>&1; then
  echo "❌ Snapshot is not valid JSON" >&2
  exit 1
fi

# Step 4: Check process health
echo "== Step 3: Process Health Check =="
GATEWAY_COUNT=$(pgrep -fl "gateway_v3_router.py" | wc -l | tr -d ' ')
MARY_COUNT=$(pgrep -fl "/agents/mary/mary.py" | wc -l | tr -d ' ')

echo "  gateway_v3_router.py: $GATEWAY_COUNT process(es)"
echo "  mary.py: $MARY_COUNT process(es)"

if [[ "$GATEWAY_COUNT" -ne 1 ]] || [[ "$MARY_COUNT" -ne 1 ]]; then
  echo "⚠️  WARN: Unexpected process counts (expected 1 each)"
fi

# Step 5: Add and commit
echo "== Step 4: Commit Evidence =="
git add "$SNAPSHOT_FILE"

# Get day number (count existing snapshots or use date)
DAY_NUM=$(git log --oneline --grep="pr11(day" | head -1 | sed -n 's/.*pr11(day\([0-9]*\)).*/\1/p' || echo "1")
if [[ -z "$DAY_NUM" ]]; then
  DAY_NUM=1
else
  DAY_NUM=$((DAY_NUM + 1))
fi

git commit -m "pr11(day${DAY_NUM}): monitoring snapshot evidence" || {
  echo "⚠️  No new snapshot to commit (may already be committed)"
}

# Step 6: Pull and push (with guard check)
echo "== Step 5: Sync with Remote =="
git pull --rebase

# Guard check again before push
if ! zsh tools/guard_workspace_inside_repo.zsh >/dev/null 2>&1; then
  echo "❌ Guard check failed after pull. Fix issues before pushing." >&2
  exit 1
fi

git push

echo ""
echo "✅ PR-11 Daily Snapshot Complete"
echo "   Snapshot: $SNAPSHOT_FILE"
echo "   Day: $DAY_NUM"
echo "   Committed and pushed"
