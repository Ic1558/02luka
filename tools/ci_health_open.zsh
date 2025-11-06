#!/usr/bin/env zsh
set -euo pipefail
BASE="${BASE:-$HOME/02luka}"
LIMIT="${1:-}"
REPORT_DIR="$BASE/g/reports/ci"

mkdir -p "$REPORT_DIR"

# ถ้าผู้ใช้ระบุจำนวนรายการ ให้สร้างรายงานก่อน
if [[ -n "$LIMIT" ]]; then
  "$BASE/tools/ci_health.zsh" "$LIMIT" >/dev/null 2>&1 || true
fi

# หาไฟล์รายงานล่าสุด
latest="$(ls -t "$REPORT_DIR"/health_*.md 2>/dev/null | head -n 1 || true)"

if [[ -z "${latest:-}" ]]; then
  echo "No health reports yet; generating one (default 20)…"
  "$BASE/tools/ci_health.zsh" 20 >/dev/null 2>&1 || true
  latest="$(ls -t "$REPORT_DIR"/health_*.md 2>/dev/null | head -n 1 || true)"
fi

if [[ -z "${latest:-}" ]]; then
  echo "❌ Could not find or generate a health report."
  exit 1
fi

echo "📄 $latest"
# macOS open; ถ้าเปิดไม่ได้ให้แค่ echo path
open "$latest" >/dev/null 2>&1 || true

