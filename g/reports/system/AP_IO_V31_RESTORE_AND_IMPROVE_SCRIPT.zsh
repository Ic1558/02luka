#!/usr/bin/env zsh
# AP/IO v3.1 Restore and Improve Script
# Purpose: Restore files from git and implement improvements

set -euo pipefail

REPO_ROOT="/Users/icmini/02luka"
cd "$REPO_ROOT"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║     AP/IO v3.1 Restore and Improve                          ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Step 1: Find the commit with AP/IO v3.1 files
echo "Step 1: Finding AP/IO v3.1 files in git history..."
COMMIT=$(git log --all --oneline -- "tools/ap_io_v31/writer.zsh" 2>/dev/null | head -1 | cut -d' ' -f1)

if [ -z "$COMMIT" ]; then
  echo "❌ Could not find AP/IO v3.1 files in git history"
  echo "   Trying alternative commit: fb6d88f86114dfa23b74d6b4156faa41ad10677f"
  COMMIT="fb6d88f86114dfa23b74d6b4156faa41ad10677f"
fi

echo "✅ Using commit: $COMMIT"
echo ""

# Step 2: Restore files
echo "Step 2: Restoring files from commit $COMMIT..."
git checkout "$COMMIT" -- \
  tools/ap_io_v31/ \
  schemas/ap_io_v31*.json \
  docs/AP_IO_V31*.md \
  agents/cls/ap_io_v31_integration.zsh \
  agents/andy/ap_io_v31_integration.zsh \
  agents/hybrid/ap_io_v31_integration.zsh \
  agents/liam/ap_io_v31_integration.zsh \
  agents/gg/ap_io_v31_integration.zsh \
  tests/ap_io_v31/ \
  tools/run_ap_io_v31_tests.zsh 2>&1 || {
  echo "⚠️  Some files may not exist in that commit, trying individual restore..."
  
  # Try restoring individually
  for path in \
    tools/ap_io_v31/writer.zsh \
    tools/ap_io_v31/reader.zsh \
    tools/ap_io_v31/validator.zsh \
    tools/ap_io_v31/correlation_id.zsh \
    tools/ap_io_v31/router.zsh \
    tools/ap_io_v31/pretty_print.zsh \
    schemas/ap_io_v31.schema.json \
    schemas/ap_io_v31_ledger.schema.json \
    docs/AP_IO_V31_PROTOCOL.md \
    docs/AP_IO_V31_INTEGRATION_GUIDE.md \
    docs/AP_IO_V31_ROUTING_GUIDE.md \
    docs/AP_IO_V31_MIGRATION.md; do
    git checkout "$COMMIT" -- "$path" 2>/dev/null && echo "✅ Restored: $path" || echo "⚠️  Not found: $path"
  done
}

echo ""

# Step 3: Make files executable
echo "Step 3: Making files executable..."
chmod +x tools/ap_io_v31/*.zsh 2>/dev/null || true
chmod +x tests/ap_io_v31/*.zsh 2>/dev/null || true
chmod +x tools/run_ap_io_v31_tests.zsh 2>/dev/null || true
echo "✅ Files made executable"
echo ""

# Step 4: Verify restoration
echo "Step 4: Verifying restoration..."
MISSING=0
for file in \
  tools/ap_io_v31/writer.zsh \
  tools/ap_io_v31/reader.zsh \
  tools/ap_io_v31/validator.zsh \
  schemas/ap_io_v31.schema.json \
  schemas/ap_io_v31_ledger.schema.json; do
  if [ -f "$file" ]; then
    echo "✅ $file"
  else
    echo "❌ $file (MISSING)"
    ((MISSING++))
  fi
done

if [ $MISSING -gt 0 ]; then
  echo ""
  echo "⚠️  $MISSING files are missing. Restoration incomplete."
  exit 1
fi

echo ""
echo "✅ All critical files restored"
echo ""

# Step 5: Syntax validation
echo "Step 5: Validating syntax..."
SYNTAX_ERRORS=0
for script in tools/ap_io_v31/*.zsh; do
  if [ -f "$script" ]; then
    if zsh -n "$script" 2>/dev/null; then
      echo "✅ $(basename $script)"
    else
      echo "❌ $(basename $script) - syntax error"
      ((SYNTAX_ERRORS++))
    fi
  fi
done

if [ $SYNTAX_ERRORS -gt 0 ]; then
  echo ""
  echo "⚠️  $SYNTAX_ERRORS scripts have syntax errors"
  exit 1
fi

echo ""
echo "✅ All scripts pass syntax validation"
echo ""

# Step 6: JSON validation
echo "Step 6: Validating JSON schemas..."
for schema in schemas/ap_io_v31*.json; do
  if [ -f "$schema" ]; then
    if python3 -m json.tool "$schema" >/dev/null 2>&1; then
      echo "✅ $(basename $schema)"
    else
      echo "❌ $(basename $schema) - invalid JSON"
      exit 1
    fi
  fi
done

echo ""
echo "✅ All JSON schemas valid"
echo ""

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║     Restoration Complete                                     ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "Next steps:"
echo "1. Run test suite: tools/run_ap_io_v31_tests.zsh"
echo "2. Verify test isolation"
echo "3. Implement Phase 2 improvements"
echo ""
