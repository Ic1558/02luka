#!/usr/bin/env zsh
# PR-11 Daily Snapshot - Atomic Workflow
# Generates snapshot, commits, and pushes with guard checks
# Usage: zsh tools/pr11_snapshot_daily.zsh [--force]

set -euo pipefail

# Ensure a sane PATH
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

REPO="${HOME}/02luka"
cd "$REPO"

# Parse arguments (--force can be anywhere)
FORCE=0
for a in "$@"; do
  [[ "$a" == "--force" ]] && FORCE=1
done

# Step 1: Guard check (must pass)
echo "== Step 1: Guard Check =="
if ! zsh tools/guard_workspace_inside_repo.zsh >/dev/null 2>&1; then
  echo "❌ Guard check failed. Fix workspace issues before creating snapshot." >&2
  exit 1
fi
echo "✅ Guard check passed"

# Step 1.5: Check for existing snapshot today (unless --force)
TODAY="$(/bin/date +%F)"

# Check for commits with pr11(dayN): pattern from today
# Use full log + awk filter (more reliable than --grep with complex regex)
# Format: HASH DATE MESSAGE (awk: $1=hash, $2=date, $3=message)
EXISTING_TODAY="$(
  /usr/bin/git log --all --pretty='%H %cs %s' |
  /usr/bin/awk -v today="$TODAY" '$2==today && $3 ~ /^pr11\(day[0-9]+\):/ {print $1; exit}'
)"

if [[ -n "$EXISTING_TODAY" ]] && [[ "$FORCE" -eq 0 ]]; then
  echo "❌ Snapshot already exists for today (${TODAY})" >&2
  echo "   Commit: $EXISTING_TODAY" >&2
  echo "   Use: zsh tools/pr11_snapshot_daily.zsh --force (for reruns/incidents)" >&2
  exit 1
fi

# Set force suffix for commit message (if rerun)
if [[ "$FORCE" -eq 1 ]] && [[ -n "$EXISTING_TODAY" ]]; then
  FORCE_SUFFIX=" [rerun]"
else
  FORCE_SUFFIX=""
fi

# Step 2: Generate snapshot
echo "== Step 2: Generate Snapshot =="
SNAPSHOT_DIR="g/reports/pr11_healthcheck"
mkdir -p "$SNAPSHOT_DIR"

SNAPSHOT_FILE="${SNAPSHOT_DIR}/$(date +%F)T$(date +%H%M%S).json"
SNAPSHOT_ERR="${SNAPSHOT_FILE%.json}.err"

# Redirect stderr to separate file to avoid corrupting JSON
if ! zsh tools/monitor_v5_production.zsh json > "$SNAPSHOT_FILE" 2>"$SNAPSHOT_ERR"; then
  echo "❌ Failed to generate snapshot" >&2
  [[ -s "$SNAPSHOT_ERR" ]] && cat "$SNAPSHOT_ERR" >&2
  exit 1
fi

# Clean up error file if empty
[[ ! -s "$SNAPSHOT_ERR" ]] && rm -f "$SNAPSHOT_ERR"

echo "✅ Snapshot created: $SNAPSHOT_FILE"

# Step 3: Verify snapshot is valid JSON
# Deterministic Interpreter Selection
if [[ -x ".venv/bin/python3" ]]; then
  PYTHON_EXE=".venv/bin/python3"
elif [[ -x "venv/bin/python3" ]]; then
  PYTHON_EXE="venv/bin/python3"
else
  PYTHON_EXE="python3"
fi

if ! "$PYTHON_EXE" -m json.tool "$SNAPSHOT_FILE" >/dev/null 2>&1; then
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

# Get day number (count commits with pr11(day pattern)
# According to PR-11 standard: Day 0 = baseline, Day 1+ = daily monitoring
# Check if day0 exists (baseline snapshot)
HAS_DAY0=$(git log --oneline --all --grep="pr11(day0" | wc -l | tr -d ' ')
EXISTING_DAYS=$(git log --oneline --all --grep="pr11(day" | sed -n 's/.*pr11(day\([0-9]*\)).*/\1/p' | sort -n | tail -1)

if [[ "$HAS_DAY0" -eq 0 ]]; then
  # No day0 commit exists = this should be day0 (baseline)
  DAY_NUM=0
elif [[ -z "$EXISTING_DAYS" ]] || [[ "$EXISTING_DAYS" == "" ]]; then
  # Has day0 but no other days = this is day1 (first monitoring day)
  DAY_NUM=1
else
  # Increment from highest existing day number
  DAY_NUM=$((EXISTING_DAYS + 1))
fi

git commit -m "pr11(day${DAY_NUM}): monitoring snapshot evidence${FORCE_SUFFIX}" || {
  echo "⚠️  No new snapshot to commit (may already be committed)"
  exit 0  # Not an error if already committed
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
