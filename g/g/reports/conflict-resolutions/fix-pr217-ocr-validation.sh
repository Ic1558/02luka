#!/bin/bash
# Resolution script for PR #217 - OCR validation hardening
# Fixes: smoke.sh (keep HEAD's enhanced version with auto-fix)

set -eo pipefail

echo "🔧 Conflict Resolution Script - PR #217 (OCR Validation Hardening)"
echo ""

BRANCH="claude/fix-ocr-validation-telemetry-011CUsYubsSeeV6r8Dhzeaay"

echo "🔄 Checking out branch: $BRANCH"
git checkout "$BRANCH" || { echo "❌ Failed to checkout $BRANCH"; exit 1; }

echo "🔄 Fetching latest from origin..."
git fetch origin main

echo "🔄 Merging origin/main..."
if git merge origin/main --no-edit; then
    echo "✅ Clean merge - no conflicts!"
    exit 0
fi

echo "⚠️  Conflicts detected, resolving..."

# Resolve smoke.sh - keep HEAD's enhanced version
if [ -f scripts/smoke.sh ]; then
    echo "  📝 Resolving scripts/smoke.sh (keeping enhanced HEAD version)..."
    git checkout --ours scripts/smoke.sh
    git add scripts/smoke.sh
    echo "  ✅ smoke.sh resolved"
    echo ""
    echo "  📋 Resolution details:"
    echo "     - Kept HEAD's version with IFS configuration"
    echo "     - Kept HEAD's auto-fix capability for script permissions"
    echo "     - Enhanced error handling with -f and -e checks"
fi

# Check if there are any remaining conflicts
if git diff --check --cached 2>/dev/null | grep -q "conflict"; then
    echo "⚠️  Additional conflicts remain - manual review required"
    git status
    exit 1
fi

# Commit the resolution
echo "💾 Committing resolution..."
git commit -m "Resolve conflicts: keep enhanced smoke test implementation

- Keep IFS configuration for better handling of special characters
- Keep auto-fix capability that automatically chmod +x scripts
- Keep enhanced error handling with both -f and -e checks
- Provides detailed feedback during permission fixes

The HEAD version provides a better developer experience by:
1. Automatically fixing permission issues instead of just failing
2. Handling edge cases with comprehensive file existence checks
3. Providing verbose output for debugging"

echo ""
echo "✅ Resolution complete!"
echo ""
echo "Next steps:"
echo "1. Review the changes: git show"
echo "2. Run tests: ./scripts/smoke.sh"
echo "3. Push to origin: git push -u origin $BRANCH"
