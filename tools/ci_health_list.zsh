#!/usr/bin/env zsh
set -euo pipefail
BASE="${BASE:-$HOME/02luka}"
REPORT_DIR="$BASE/g/reports/ci"
N="${1:-10}"

mkdir -p "$REPORT_DIR"

# ถ้ายังไม่มีรายงาน สร้าง default 20 ก่อน
if ! ls "$REPORT_DIR"/health_*.md >/dev/null 2>&1; then
  "$BASE/tools/ci_health.zsh" 20 >/dev/null 2>&1 || true
fi

# ถ้ายังไม่มีจริงๆ ให้จบ
if ! ls "$REPORT_DIR"/health_*.md >/dev/null 2>&1; then
  echo "❌ No CI health reports found (even after generate)."
  exit 1
fi

# แสดงรายการล่าสุด N ไฟล์
print -r -- "Latest CI Health Reports (max $N):"
print -r -- "mtime                  size     file"
print -r -- "---------------------  -------  ----------------------------------------------"
ls -lt "$REPORT_DIR"/health_*.md \
  | awk 'NR>1{print $6" "$7" "$8"  "$5"  "$9}' \
  | head -n "$N"

