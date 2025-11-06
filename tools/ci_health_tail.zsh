#!/usr/bin/env zsh
set -euo pipefail
BASE="${BASE:-$HOME/02luka}"
REPORT_DIR="$BASE/g/reports/ci"

mkdir -p "$REPORT_DIR"

# หาไฟล์รายงานล่าสุด
latest="$(ls -t "$REPORT_DIR"/health_*.md 2>/dev/null | head -n 1 || true)"

# ถ้าไม่มี ให้สร้าง default 20 แล้วหาใหม่
if [[ -z "${latest:-}" ]]; then
  echo "No health reports yet; generating one (default 20)…"
  "$BASE/tools/ci_health.zsh" 20 >/dev/null 2>&1 || true
  latest="$(ls -t "$REPORT_DIR"/health_*.md 2>/dev/null | head -n 1 || true)"
fi

if [[ -z "${latest:-}" ]]; then
  echo "❌ Could not find or generate a health report."
  exit 1
fi

echo "👀 tail -f $latest"
tail -f "$latest"

