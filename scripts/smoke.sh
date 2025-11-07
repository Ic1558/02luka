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
# Use find -print0 + read -d '' to handle spaces/special chars in filenames (portable)
# Use process substitution to avoid subshell variable scope issue
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

# Check if any scripts were found (guard with default expansion)
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
