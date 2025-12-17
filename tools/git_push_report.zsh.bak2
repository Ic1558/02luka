#!/usr/bin/env zsh
# @created_by: CLS
# @purpose: Generate push approval report for manual review
# @usage: ./tools/git_push_report.zsh

set -euo pipefail

# Configuration
REPO_DIR="${LUKA_HOME:-$HOME/02luka/g}"
REPORT_DIR="$HOME/02luka/g/reports"
REPORT_FILE="$REPORT_DIR/git_push_$(date +%Y%m%d_%H%M%S).md"
REMOTE="origin"
BRANCH="ai"

# Change to repo directory
cd "$REPO_DIR" || exit 1

# Check current branch
CURRENT_BRANCH=$(git branch --show-current)
if [[ ! "$CURRENT_BRANCH" =~ ^ai/ ]]; then
    echo "ERROR: Not on ai/ branch. Current: $CURRENT_BRANCH"
    exit 1
fi

# Ensure report directory exists
mkdir -p "$REPORT_DIR"

# Get commits ahead of remote
COMMITS_AHEAD=$(git rev-list --count "$REMOTE/$BRANCH"..HEAD 2>/dev/null || echo "0")

if [[ "$COMMITS_AHEAD" == "0" ]]; then
    echo "No commits to push. Branch is up to date with $REMOTE/$BRANCH"
    exit 0
fi

# Generate report
cat > "$REPORT_FILE" <<EOF
# Git Push Approval Report

**Generated:** $(date '+%Y-%m-%d %H:%M:%S %z')  
**Branch:** $CURRENT_BRANCH  
**Remote:** $REMOTE/$BRANCH  
**Commits Ahead:** $COMMITS_AHEAD

---

## Commits to Push

\`\`\`
$(git log --oneline "$REMOTE/$BRANCH"..HEAD)
\`\`\`

---

## File Changes Summary

\`\`\`
$(git diff --stat "$REMOTE/$BRANCH"..HEAD)
\`\`\`

---

## Detailed Changes

\`\`\`diff
$(git diff "$REMOTE/$BRANCH"..HEAD | head -200)
\`\`\`

---

## Risk Assessment

**Risk Level:** $(if git diff "$REMOTE/$BRANCH"..HEAD | grep -qE "(core/|CLC/|docs/|02luka\.md)"; then echo "⚠️ MEDIUM"; else echo "✅ LOW"; fi)

**SOT Files Changed:** $(git diff --name-only "$REMOTE/$BRANCH"..HEAD | grep -cE "(core/|CLC/|docs/|02luka\.md)" || echo "0")

**Recommendation:** $(if git diff "$REMOTE/$BRANCH"..HEAD | grep -qE "(core/|CLC/|docs/|02luka\.md)"; then echo "REVIEW - SOT files detected"; else echo "APPROVE - Safe changes only"; fi)

---

## Push Command

\`\`\`bash
cd ~/02luka/g && git push $REMOTE $BRANCH
\`\`\`

---

**Note:** Review this report before pushing. If approved, run the push command above.
EOF

echo "✅ Push report generated: $REPORT_FILE"
echo ""
echo "To review: cat $REPORT_FILE"
echo "To push (if approved): cd ~/02luka/g && git push $REMOTE $BRANCH"
