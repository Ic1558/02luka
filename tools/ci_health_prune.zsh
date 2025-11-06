#!/usr/bin/env zsh
set -euo pipefail

BASE="${BASE:-$HOME/02luka}"
REPORT_DIR="$BASE/g/reports/ci"
DAYS="${1:-14}"          # อายุไฟล์เกินกี่วัน
MODE="${2:-dry}"         # dry หรือ force

mkdir -p "$REPORT_DIR"

# ถ้ายังไม่มีรายงาน สร้าง default ก่อนเพื่อให้โฟลเดอร์มีโครงสร้าง
if ! ls "$REPORT_DIR"/health_*.md >/dev/null 2>&1; then
  if [ -x "$BASE/tools/ci_health.zsh" ]; then
    "$BASE/tools/ci_health.zsh" 20 >/dev/null 2>&1 || true
  fi
fi

echo "🧹 CI Health Prune"
echo "• Directory : $REPORT_DIR"
echo "• Older than: ${DAYS} days"
echo "• Mode      : ${MODE}"

# รวบรวมไฟล์เป้าหมาย
set +e
IFS=$'\n' files=($(find "$REPORT_DIR" -type f -name 'health_*.md' -mtime +"$DAYS" 2>/dev/null))
set -e

if [ ${#files[@]} -eq 0 ]; then
  echo "✅ No files older than ${DAYS} days."
  exit 0
fi

echo "🔎 Candidates (${#files[@]}):"
for f in "${files[@]}"; do
  printf '  - %s\n' "$f"
done

if [ "$MODE" = "force" ]; then
  echo "🗑️  Deleting..."
  for f in "${files[@]}"; do
    rm -f -- "$f"
  done
  echo "✅ Deleted ${#files[@]} file(s)."
else
  echo "ℹ️  Dry-run only. Append '--force' to actually delete."
fi

