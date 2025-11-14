#!/usr/bin/env zsh
set -euo pipefail
ROOT="${LUKA_MEM_REPO_ROOT:-$HOME/LocalProjects/02luka-memory}"
CFG="${1:-config/memory_guard.yaml}"
command -v yq >/dev/null 2>&1 || { echo "need yq"; exit 127; }
WARN_MB=$(yq -r '.thresholds.warn_mb' "$CFG")
FAIL_MB=$(yq -r '.thresholds.fail_mb' "$CFG")
DENY=("${(@f)$(yq -r '.deny_globs[]' "$CFG")}")
ALLOW=("${(@f)$(yq -r '.allow_globs[]' "$CFG")}")

echo "Scanning: $ROOT"
status=0
# Size enforcement
find "$ROOT" -type f -print0 | while IFS= read -r -d '' f; do
  sz=$(du -m "$f" | awk '{print $1}')
  if [ "$sz" -ge "$FAIL_MB" ]; then
    echo "❌ FAIL size ${sz}MB: ${f}"
    status=1
  elif [ "$sz" -ge "$WARN_MB" ]; then
    echo "⚠️  WARN size ${sz}MB: ${f}"
  fi
done

# Pattern deny
for pat in "${DENY[@]}"; do
  matches=("${(@f)$(cd "$ROOT" && print -rl -- **/${pat#**/} 2>/dev/null || true)}")
  for m in "${matches[@]}"; do
    [ -n "$m" ] || continue
    echo "❌ DENY pattern: $ROOT/$m"
    status=1
  done
done

exit $status
