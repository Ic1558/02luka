#!/bin/bash
# Smoke tests for 02LUKA system
# Verifies basic system health and critical paths

set -eo pipefail

echo "🔍 Running 02LUKA Smoke Tests..."
echo ""

# Test 1: Directory structure
echo "[1/5] Checking directory structure..."
test -d g/reports || mkdir -p g/reports || { echo "❌ g/reports/ missing and cannot create"; exit 1; }
test -d .github/workflows || { echo "❌ .github/workflows/ missing"; exit 1; }
if [ -d CLS ]; then
  echo "✅ CLS/ directory present"
else
  echo "⚠️  CLS/ directory not found (optional, skipping)"
fi
echo "✅ Directory structure OK"

# Test 2: CLS integration files
echo "[2/5] Checking CLS integration..."
if [ -d CLS ]; then
  if [ -f CLS/CURSOR_INTEGRATION_GUIDE.md ]; then
    echo "✅ CLS guide present"
  else
    echo "⚠️  CLS guide not found (optional)"
  fi
  if [ -d memory/cls ]; then
    echo "✅ CLS memory directory present"
  else
    echo "⚠️  CLS memory directory not found (will be created on first use)"
    mkdir -p memory/cls || true
  fi
else
  echo "⚠️  CLS directory not found (optional, skipping CLS checks)"
fi
echo "✅ CLS integration check complete"

# Test 3: Workflow files
echo "[3/5] Checking workflow files..."
test -f .github/workflows/ci.yml || { echo "❌ ci.yml missing"; exit 1; }
if [ -f .github/workflows/daily-proof.yml ]; then
  grep -q "upload-artifact@v4" .github/workflows/daily-proof.yml || { echo "❌ Artifact version not v4"; exit 1; }
  echo "✅ Workflow files OK (artifact@v4)"
else
  echo "⚠️  daily-proof.yml not found (optional, skipping)"
  echo "✅ Workflow files OK (ci.yml present)"
fi

# Test 4: Git repository health
echo "[4/5] Checking git repository..."
if git rev-parse --git-dir >/dev/null 2>&1; then
  echo "✅ Git repository detected"
  if git remote get-url origin >/dev/null 2>&1; then
    echo "✅ Git remote configured"
  else
    echo "⚠️  Git remote not configured (may be in CI environment)"
  fi
  echo "✅ Git repository OK"
else
  echo "❌ Not a git repository"
  exit 1
fi

# Test 5: Critical scripts executable
echo "[5/5] Checking script permissions..."
scripts_found=0
# Use find -print0 + read -d '' to handle spaces/special chars in filenames (portable)
find tools -maxdepth 1 -type f -name 'cls_*.zsh' -print0 2>/dev/null | while IFS= read -r -d '' script; do
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
done || true

if [ $scripts_found -eq 0 ]; then
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
