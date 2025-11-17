#!/bin/bash
# ======================================================================
# Pre-Commit Hook: PATH Protocol Enforcement
# Purpose: Block commits with hardcoded paths or LaunchAgent violations
# Version: 1.0.0
# Authority: PATH_AND_TOOL_PROTOCOL.md Section 4.1
# ======================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

VIOLATIONS=0

echo "🔍 PATH Protocol Validation (pre-commit)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ======================================================================
# CHECK 1: Hardcoded Path Detection
# ======================================================================
echo -n "Checking for hardcoded paths... "

# Get staged files (exclude binary and generated files)
STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM | \
  grep -E '\.(sh|zsh|bash|py|js|cjs|ts|yaml|yml|md)$' | \
  grep -v 'node_modules/' | \
  grep -v '.git/' || true)

if [ -n "$STAGED_FILES" ]; then
  # Check for hardcoded ~/02luka or /Users/*/02luka patterns
  # Allow hardcoded path: This hook file contains examples only
  HARDCODED=$(git diff --cached | \
    grep -E '^\+.*(\~/02luka|/Users/[^/]+/02luka)' | \
    grep -v '# Allow hardcoded path:' || true)

  if [ -n "$HARDCODED" ]; then
    echo -e "${RED}✗ FAILED${NC}"
    echo ""
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}❌ PROTOCOL VIOLATION: Hardcoded paths detected${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "Found hardcoded path references:"
    echo "$HARDCODED" | head -10
    echo ""
    echo "📋 PATH Protocol Rules (MUST):"
    echo "  ✅ Use: \$SOT variable for all 02luka paths"
    echo "  ❌ Never: ~""/"02luka or /Users/USER/02luka"  # Allow hardcoded path: example text only
    echo ""
    echo "🔧 Quick Fixes:"
    echo "  Replace:  ~""/"02luka/...              → \$SOT/..."  # Allow hardcoded path: example text
    echo "  Replace:  /Users/icmini/02luka/...  → \$SOT/..."   # Allow hardcoded path: example text
    echo ""
    echo "📖 See: g/docs/PATH_AND_TOOL_PROTOCOL.md Section 2.1"
    echo ""
    echo "💡 To bypass (emergency only):"
    echo "   Add comment: # Allow hardcoded path: <reason>"
    echo ""
    VIOLATIONS=$((VIOLATIONS + 1))
  else
    echo -e "${GREEN}✓ OK${NC}"
  fi
else
  echo -e "${YELLOW}⊘ SKIPPED (no matching files)${NC}"
fi

# ======================================================================
# CHECK 2: LaunchAgent Script Validation
# ======================================================================
echo -n "Checking LaunchAgent scripts... "

# Check if any .plist files are being committed
PLIST_FILES=$(git diff --cached --name-only --diff-filter=ACM | \
  grep -E '\.plist$' || true)

if [ -n "$PLIST_FILES" ]; then
  MISSING_SCRIPTS=""

  while IFS= read -r plist; do
    if [ -f "$plist" ]; then
      # Extract ProgramArguments from plist
      SCRIPTS=$(plutil -p "$plist" 2>/dev/null | \
        grep -A 20 "ProgramArguments" | \
        grep '"' | \
        grep -E '\.(sh|zsh|bash|py|js|cjs)' | \
        sed 's/.*=> "\(.*\)"/\1/' || true)

      # Check if scripts exist
      for script in $SCRIPTS; do
        # Expand ~ to HOME
        expanded_script="${script/#\~/$HOME}"

        if [ ! -f "$expanded_script" ] && [ ! -x "$expanded_script" ]; then
          MISSING_SCRIPTS="${MISSING_SCRIPTS}\n  ❌ $plist → $script (NOT FOUND)"
        fi
      done
    fi
  done <<< "$PLIST_FILES"

  if [ -n "$MISSING_SCRIPTS" ]; then
    echo -e "${RED}✗ FAILED${NC}"
    echo ""
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}❌ LAUNCHAGENT VIOLATION: Missing scripts${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "LaunchAgent plist files reference missing scripts:${MISSING_SCRIPTS}"
    echo ""
    echo "🔧 Fix Options:"
    echo "  1. Create missing script"
    echo "  2. Update plist to correct path"
    echo "  3. Remove plist if script was deleted"
    echo ""
    echo "📖 See: g/docs/LAUNCHAGENT_REGISTRY.md"
    echo ""
    VIOLATIONS=$((VIOLATIONS + 1))
  else
    echo -e "${GREEN}✓ OK${NC}"
  fi
else
  echo -e "${YELLOW}⊘ SKIPPED (no plist files)${NC}"
fi

# ======================================================================
# CHECK 3: Symlink Detection
# ======================================================================
echo -n "Checking for symlinks... "

SYMLINKS=$(git diff --cached --name-only --diff-filter=A | \
  while read file; do
    if [ -L "$file" ]; then
      echo "$file"
    fi
  done || true)

if [ -n "$SYMLINKS" ]; then
  echo -e "${RED}✗ FAILED${NC}"
  echo ""
  echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${RED}❌ PROTOCOL VIOLATION: Symlinks detected${NC}"
  echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  echo "Symlinks found:"
  echo "$SYMLINKS" | sed 's/^/  ❌ /'
  echo ""
  echo "📋 PATH Protocol Rules:"
  echo "  ❌ Symlinks prohibited in SOT (breaks Google Drive sync)"
  echo "  ✅ Use wrapper scripts instead"
  echo ""
  echo "🔧 Fix: Create wrapper script instead of symlink"
  echo "  cat > target.zsh <<'EOF'"
  echo "  #!/usr/bin/env zsh"
  echo "  exec \"\$SOT/g/tools/original.zsh\" \"\$@\""
  echo "  EOF"
  echo ""
  echo "📖 See: g/docs/PATH_AND_TOOL_PROTOCOL.md Section 2.3.2"
  echo ""
  VIOLATIONS=$((VIOLATIONS + 1))
else
  echo -e "${GREEN}✓ OK${NC}"
fi

# ======================================================================
# Summary
# ======================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ $VIOLATIONS -gt 0 ]; then
  echo -e "${RED}❌ COMMIT REJECTED: $VIOLATIONS violation(s) found${NC}"
  echo ""
  echo "Fix violations and try again, or see:"
  echo "  📖 PATH Protocol: g/docs/PATH_AND_TOOL_PROTOCOL.md"
  echo "  📖 Agent Registry: g/docs/LAUNCHAGENT_REGISTRY.md"
  echo ""
  exit 1
else
  echo -e "${GREEN}✅ All checks passed - commit allowed${NC}"
  exit 0
fi
