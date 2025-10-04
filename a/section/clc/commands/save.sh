#!/usr/bin/env bash
# CLC 3-Layer Save System
# Protocol: CLAUDE.md #save command
# Triggers: Auto memory preservation with zero context loss

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$REPO_ROOT" || exit 1

TIMESTAMP=$(date +%y%m%d_%H%M%S)
SESSION_ID="session_${TIMESTAMP}"

echo "=== CLC Save System (3-layer) ==="
echo "Session: $SESSION_ID"
echo ""

# Layer 1: Session Files - Detailed context
echo "[Layer 1] Capturing session context..."
mkdir -p g/reports/sessions

cat > "g/reports/sessions/${SESSION_ID}.md" <<EOF
# CLC Session ${TIMESTAMP}

## Summary
$(git log --oneline -5 | head -3)

## Current Work
$(git status --short)

## Recent Changes
$(git diff --stat HEAD~3..HEAD 2>/dev/null || echo "No recent changes")

## CLAUDE.md Update
- Session captured: ${SESSION_ID}
- Timestamp: $(date -Iseconds)

EOF

echo "✅ Session file: g/reports/sessions/${SESSION_ID}.md"

# Layer 2: AI Read Context - Dashboard updates  
echo "[Layer 2] Updating AI read context..."

# Update 02luka.md last session marker
if [ -f "02luka.md" ]; then
  if grep -q "Last Session:" 02luka.md; then
    sed -i.bak "s/Last Session:.*/Last Session: ${TIMESTAMP}/" 02luka.md
  else
    echo "" >> 02luka.md
    echo "Last Session: ${TIMESTAMP}" >> 02luka.md
  fi
  echo "✅ Updated 02luka.md"
fi

# Layer 3: MLS Integration - Compressed lessons
echo "[Layer 3] MLS integration..."
if [ -f "a/memory_center/core/CLAUDE_MEMORY_SYSTEM.md" ]; then
  echo "- Session ${TIMESTAMP}: $(git log -1 --format='%s')" >> a/memory_center/core/CLAUDE_MEMORY_SYSTEM.md
  echo "✅ Updated CLAUDE_MEMORY_SYSTEM.md"
else
  echo "⚠️  CLAUDE_MEMORY_SYSTEM.md not found - skipping Layer 3"
fi

echo ""
echo "=== Save Complete ==="
echo "Session: $SESSION_ID"
echo "Files: g/reports/sessions/${SESSION_ID}.md"
