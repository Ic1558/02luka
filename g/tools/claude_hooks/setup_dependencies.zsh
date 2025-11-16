#!/usr/bin/env zsh
set -euo pipefail

REPO="$HOME/02luka"
INSTALLED=0
MISSING=0

check_and_install() {
  local tool=$1
  local install_cmd=$2
  
  if command -v "$tool" >/dev/null 2>&1; then
    echo "✅ $tool already installed"
    INSTALLED=$((INSTALLED+1))
    return 0
  fi
  
  echo "❌ $tool missing, installing..."
  if eval "$install_cmd"; then
    echo "✅ $tool installed successfully"
    INSTALLED=$((INSTALLED+1))
  else
    echo "❌ Failed to install $tool"
    MISSING=$((MISSING+1))
    return 1
  fi
}

echo "=== Claude Code Dependency Setup ==="
echo ""

# Check shellcheck
check_and_install "shellcheck" "brew install shellcheck" || true

# Check pylint
check_and_install "pylint" "pip3 install --break-system-packages pylint" || true

# Check jq
check_and_install "jq" "brew install jq" || true

# Check gh (GitHub CLI)
check_and_install "gh" "brew install gh" || true

# Check git (should always be available)
if command -v git >/dev/null 2>&1; then
  echo "✅ git already installed"
  INSTALLED=$((INSTALLED+1))
else
  echo "❌ git missing (critical!)"
  MISSING=$((MISSING+1))
fi

echo ""
echo "=== Summary ==="
echo "Installed/Available: $INSTALLED"
echo "Missing: $MISSING"

if [[ $MISSING -eq 0 ]]; then
  echo "✅ All dependencies available"
  exit 0
else
  echo "⚠️  Some dependencies missing"
  exit 1
fi
