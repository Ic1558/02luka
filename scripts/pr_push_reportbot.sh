#!/usr/bin/env bash
# PR Push Helper for Reportbot Badge Tolerance Changes
#
# Automates: checkout → stage → commit → push → PR URL
# Fallback: Creates timestamped patch if push fails
#
# Usage:
#   bash scripts/pr_push_reportbot.sh [BRANCH_NAME]
#
# Default branch: feat/alerts-reportbot

set -euo pipefail

BRANCH="${1:-feat/alerts-reportbot}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

echo "=== Reportbot PR Push Helper ==="
echo "Branch: $BRANCH"
echo ""

# Step 1: Checkout or create branch
echo "[1/5] Checking out branch..."
if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
  git checkout "$BRANCH"
  echo "  ✅ Switched to existing branch: $BRANCH"
else
  git checkout -b "$BRANCH"
  echo "  ✅ Created new branch: $BRANCH"
fi

# Step 2: Stage key files
echo ""
echo "[2/5] Staging files..."
FILES_TO_STAGE=(
  ".github/workflows/ci.yml"
  "agents/reportbot/index.cjs"
  "boss-api/server.cjs"
  "g/manuals/alerts_setup.md"
  "scripts/pr_push_reportbot.sh"
)

STAGED_COUNT=0
for file in "${FILES_TO_STAGE[@]}"; do
  if [ -f "$file" ]; then
    git add "$file"
    echo "  ✅ Staged: $file"
    STAGED_COUNT=$((STAGED_COUNT + 1))
  else
    echo "  ⚠️  Skipped (not found): $file"
  fi
done

if [ $STAGED_COUNT -eq 0 ]; then
  echo ""
  echo "❌ No files to commit. Exiting."
  exit 1
fi

# Step 3: Commit
echo ""
echo "[3/5] Creating commit..."
COMMIT_MSG="feat: make reportbot badge inspection tolerant + native HTTP

- Badge tolerance: /api/reports/summary returns 200 with 'unknown' status on missing/unreadable/invalid JSON
- Native HTTP: Replace node-fetch with native https module (zero dependencies)
- OPS summary: Generate g/reports/OPS_SUMMARY.json with status, alerts, recent events
- Helper script: scripts/pr_push_reportbot.sh for quick PR creation
- Documentation: g/manuals/alerts_setup.md for setup and troubleshooting

Testing:
✅ node agents/reportbot/index.cjs /tmp/ops_summary.json"

if git diff --cached --quiet; then
  echo "  ⚠️  No changes to commit (already committed?)"
else
  git commit -m "$COMMIT_MSG"
  echo "  ✅ Commit created"
fi

# Step 4: Push to GitHub
echo ""
echo "[4/5] Pushing to GitHub..."

if git push origin "$BRANCH" 2>/dev/null; then
  echo "  ✅ Pushed to origin/$BRANCH"
  PUSH_SUCCESS=true
else
  echo "  ❌ Push failed (missing GitHub credentials or network issue)"
  PUSH_SUCCESS=false
fi

# Step 5: PR URL or Fallback
echo ""
if [ "$PUSH_SUCCESS" = true ]; then
  echo "[5/5] Pull Request URL:"
  echo ""
  echo "  🔗 https://github.com/Ic1558/02luka/compare/$BRANCH?expand=1"
  echo ""
  echo "✅ Done! Open the URL above to create the PR."
else
  echo "[5/5] Creating fallback patch..."

  PATCH_DIR="$REPO_ROOT/g/patches"
  mkdir -p "$PATCH_DIR"

  TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
  PATCH_FILE="$PATCH_DIR/reportbot_tolerance_$TIMESTAMP.patch"

  # Create patch from last commit
  git format-patch -1 HEAD --stdout > "$PATCH_FILE"

  echo ""
  echo "  ✅ Patch saved: $PATCH_FILE"
  echo ""
  echo "=== Next Steps ==="
  echo ""
  echo "From a machine with GitHub access:"
  echo "  1. Apply patch: git am < $PATCH_FILE"
  echo "  2. Push: git push origin $BRANCH"
  echo "  3. Create PR: https://github.com/Ic1558/02luka/compare/$BRANCH?expand=1"
  echo ""
fi

echo ""
echo "=== Summary ==="
echo "Branch: $BRANCH"
echo "Files staged: $STAGED_COUNT"
echo "Commit: $(git log -1 --oneline | head -c 50)..."
echo ""
