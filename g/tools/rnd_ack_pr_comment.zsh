#!/usr/bin/env zsh
set -euo pipefail

if ! command -v gh >/dev/null 2>&1; then
  echo "ERROR: gh CLI not found" >&2
  exit 1
fi

pr="$1"
outcome="$2"
note="${3:-''}"

msg="R&D Gate: **${outcome}**. ${note}"
gh pr comment "$pr" --body "$msg" >/dev/null 2>&1 || true
echo "$msg"
