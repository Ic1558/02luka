#!/usr/bin/env zsh
# Loop Portability Audit Tool
# Scans for risky glob-for loops and bash-only shopt usage
# Adds hints for portable find+while patterns

set -eo pipefail

ROOT="${1:-$HOME/02luka}"
cd "$ROOT"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 Loop Portability Audit"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Find risky patterns
GREP='grep -RIn --exclude-dir=.git --exclude=package-lock.json --exclude-dir=node_modules --exclude-dir=.venv'

echo "== Scanning: risky loops & bash-only shopt =="
echo ""

# Find glob-for loops
echo "📋 Glob-for loops (risky):"
$GREP -E 'for +[a-zA-Z0-9_]+ +in +[^;]+(\*|\?|\[)' . 2>/dev/null | head -20 || echo "  (none found)"
echo ""

# Find shopt usage
echo "📋 shopt usage (bash-only):"
$GREP -E 'shopt +-s +nullglob|shopt +-u +nullglob' . 2>/dev/null | head -20 || echo "  (none found)"
echo ""

# Find while+pipe patterns (potential subshell issues)
echo "📋 While+pipe patterns (potential subshell):"
$GREP -E 'while +.*; do' . 2>/dev/null | grep -E '\|' | head -20 || echo "  (none found)"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Summary: Files with risky patterns"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

candidates=$($GREP -lE 'for +[a-zA-Z0-9_]+ +in +[^;]+(\*|\?|\[)|shopt +-s +nullglob|shopt +-u +nullglob' . 2>/dev/null | sort -u || true)

if [ -z "$candidates" ]; then
  echo "✅ No risky patterns found!"
else
  echo "$candidates" | while IFS= read -r f; do
    echo "  - $f"
  done
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Audit Complete"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Note: This is a dry-run scan. Review files manually and"
echo "      apply portable patterns (find -print0 | while read -d '')"
echo ""

