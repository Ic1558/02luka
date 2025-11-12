#!/usr/bin/env zsh
set -euo pipefail

REPO="$HOME/02luka"
FOUND_ISSUES=0

check_credentials() {
  local file=$1
  local patterns=(
    "password.*=.*['\"][^'\"]{8,}['\"]"
    "api[_-]?key.*=.*['\"][^'\"]{10,}['\"]"
    "secret.*=.*['\"][^'\"]{8,}['\"]"
    "token.*=.*['\"][^'\"]{10,}['\"]"
    "-----BEGIN.*PRIVATE KEY-----"
    "-----BEGIN RSA PRIVATE KEY-----"
    "AKIA[0-9A-Z]{16}"
    "sk-[a-zA-Z0-9]{32,}"
  )
  
  for pattern in "${patterns[@]}"; do
    if grep -qiE "$pattern" "$file" 2>/dev/null; then
      echo "⚠️  Potential credential found in $file (pattern: $pattern)"
      FOUND_ISSUES=$((FOUND_ISSUES+1))
    fi
  done
}

echo "=== Security Check (Credential Scanning) ==="
echo ""

# Check staged files
if command -v git >/dev/null 2>&1; then
  staged_files=$(git diff --cached --name-only 2>/dev/null || echo "")
  if [[ -n "$staged_files" ]]; then
    echo "Checking staged files..."
    for file in $staged_files; do
      if [[ -f "$file" ]]; then
        check_credentials "$file"
      fi
    done
  fi
fi

# Check modified files in tools/
if [[ -d "$REPO/tools" ]]; then
  echo "Checking tools/ directory..."
  find "$REPO/tools" -type f \( -name "*.zsh" -o -name "*.sh" -o -name "*.py" \) | while read -r file; do
    check_credentials "$file"
  done
fi

echo ""
if [[ $FOUND_ISSUES -eq 0 ]]; then
  echo "✅ No credential issues found"
  exit 0
else
  echo "⚠️  Found $FOUND_ISSUES potential credential issues"
  echo "Review files above and ensure credentials are not hard-coded"
  exit 1
fi
