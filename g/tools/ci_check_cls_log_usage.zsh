#!/usr/bin/env zsh
# CI check: Ensure CLS audit logging uses cls_log helper, not direct writes
set -euo pipefail

REPO="${REPO:-$HOME/02luka}"
cd "$REPO"

VIOLATIONS=0

echo "Checking for direct cls_audit.jsonl writes..."

# Check for direct append patterns
if grep -r "cls_audit\.jsonl" . --include="*.zsh" --include="*.sh" --include="*.py" 2>/dev/null | grep -E ">>|\.write\(|\.append\(" | grep -v "cls_log" | grep -v ".git" | grep -v "ci_check_cls_log_usage"; then
  echo "❌ Found direct writes to cls_audit.jsonl"
  echo ""
  echo "Please use g/tools/cls_log.zsh instead:"
  echo "  g/tools/cls_log.zsh --action <action> --category <category> --status <status> --message \"<msg>\""
  echo ""
  VIOLATIONS=$((VIOLATIONS + 1))
else
  echo "✅ No direct cls_audit.jsonl writes found"
fi

if [ $VIOLATIONS -gt 0 ]; then
  exit 1
fi

exit 0
