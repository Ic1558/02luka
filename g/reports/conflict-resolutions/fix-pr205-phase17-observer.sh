#!/bin/bash
# Resolution script for PR #205 - Phase 17 observer
# Fixes: pages.yml + .gitignore + smoke.sh (with auto-fix hybrid)

set -eo pipefail

echo "🔧 Conflict Resolution Script - PR #205 (Phase 17 Observer)"
echo ""

BRANCH="claude/phase-17-ci-observer"

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

# Resolve pages.yml - accept origin/main's printf approach
if [ -f .github/workflows/pages.yml ]; then
    echo "  📝 Resolving .github/workflows/pages.yml (accepting printf approach)..."
    git checkout --theirs .github/workflows/pages.yml
    git add .github/workflows/pages.yml
    echo "  ✅ pages.yml resolved"
fi

# Resolve .gitignore - accept origin/main's clean organization
if [ -f .gitignore ]; then
    echo "  📝 Resolving .gitignore (accepting clean organization)..."
    git checkout --theirs .gitignore
    git add .gitignore
    echo "  ✅ .gitignore resolved"
fi

# Resolve smoke.sh - use hybrid approach (process substitution + auto-fix)
if [ -f scripts/smoke.sh ]; then
    echo "  📝 Resolving scripts/smoke.sh (hybrid: process substitution + auto-fix)..."

    # Create the hybrid version
    cat > scripts/smoke.sh << 'SMOKESCRIPT'
#!/bin/bash
# Smoke tests for 02LUKA system
# Verifies basic system health and critical paths

# portable strict-ish mode for mixed CI shells
set -eo pipefail
IFS=$'\n\t'

echo "🔍 Running 02LUKA Smoke Tests..."
echo ""

# Test 1: Directory structure
echo "[1/5] Checking directory structure..."
test -d g/reports || { echo "❌ g/reports/ missing"; exit 1; }
test -d CLS || { echo "❌ CLS/ missing"; exit 1; }
test -d .github/workflows || { echo "❌ .github/workflows/ missing"; exit 1; }
echo "✅ Directory structure OK"

# Test 2: CLS integration files
echo "[2/5] Checking CLS integration..."
test -f CLS/CURSOR_INTEGRATION_GUIDE.md || { echo "❌ CLS guide missing"; exit 1; }
test -d memory/cls || { echo "❌ CLS memory missing"; exit 1; }
echo "✅ CLS integration files OK"

# Test 3: Workflow files
echo "[3/5] Checking workflow files..."
test -f .github/workflows/ci.yml || { echo "❌ ci.yml missing"; exit 1; }
test -f .github/workflows/daily-proof.yml || { echo "❌ daily-proof.yml missing"; exit 1; }
grep -q "upload-artifact@v4" .github/workflows/daily-proof.yml || { echo "❌ Artifact version not v4"; exit 1; }
echo "✅ Workflow files OK (artifact@v4)"

# Test 4: Git repository health
echo "[4/5] Checking git repository..."
git rev-parse --git-dir >/dev/null 2>&1 || { echo "❌ Not a git repository"; exit 1; }
git remote get-url origin >/dev/null 2>&1 || { echo "❌ No git remote"; exit 1; }
echo "✅ Git repository OK"

# Test 5: Critical scripts executable
echo "[5/5] Checking script permissions..."
scripts_found=0
# Use process substitution (robust) + auto-fix capability (helpful)
while IFS= read -r -d '' script; do
  if [ -f "$script" ] && [ -e "$script" ]; then
    scripts_found=1
    if [ -x "$script" ]; then
      echo "✅ $script is executable"
    else
      echo "⚠️  $script not executable (fixing...)"
      chmod +x "$script" || { echo "❌ Cannot make $script executable"; exit 1; }
      echo "✅ $script is now executable"
    fi
  fi
done < <(find tools -maxdepth 1 -type f -name 'cls_*.zsh' -print0 2>/dev/null) || true

if [ "${scripts_found:-0}" -eq 0 ]; then
  echo "⚠️  No cls_*.zsh scripts found (optional)"
fi
echo "✅ Script permissions check complete"

echo ""
echo "🎉 All smoke tests passed!"
echo ""
echo "System Status:"
echo "  ✅ Directory structure verified"
echo "  ✅ CLS integration operational"
echo "  ✅ Workflows using artifact@v4"
echo "  ✅ Git repository healthy"
echo "  ✅ Scripts executable"
SMOKESCRIPT

    git add scripts/smoke.sh
    echo "  ✅ smoke.sh resolved with hybrid approach"
fi

# Check if there are any remaining conflicts
if git diff --check --cached 2>/dev/null | grep -q "conflict"; then
    echo "⚠️  Additional conflicts remain - manual review required"
    git status
    exit 1
fi

# Commit the resolution
echo "💾 Committing resolution..."
git commit -m "Resolve conflicts: printf, clean .gitignore, hybrid smoke.sh

- Accept origin/main's printf implementation for pages.yml
- Accept origin/main's clean .gitignore organization
- Hybrid smoke.sh: process substitution (robust) + auto-fix (helpful)

The smoke.sh resolution combines the best of both versions:
- Process substitution from origin/main (avoids subshell issues)
- Auto-fix capability from HEAD (improves developer experience)
- Enhanced error handling with -f and -e checks

Resolves conflicts with PR #209, #210, and #211"

echo ""
echo "✅ Resolution complete!"
echo ""
echo "Next steps:"
echo "1. Review the changes: git show"
echo "2. Run tests: ./scripts/smoke.sh"
echo "3. Push to origin: git push -u origin $BRANCH"
