#!/usr/bin/env zsh
# ~/02luka/tools/mary_preflight.zsh
# Report-only preflight using Mary Router (no blocking)

set -uo pipefail
LUKA_ROOT="${LUKA_ROOT:-$HOME/02luka}"
cd "$LUKA_ROOT"

# เอาเฉพาะไฟล์ที่เปลี่ยนจริง (M, A, D)
changed_files=()
git_status_output=$(git status --porcelain=v1 2>/dev/null || true)
if [[ -n "$git_status_output" ]]; then
  while IFS= read -r line; do
    if [[ -n "$line" ]]; then
      file_status=$(echo "$line" | awk '{print $1}')
      file_path=$(echo "$line" | awk '{print $2}')
      if [[ "$file_status" =~ ^[MAD] ]]; then
        changed_files+=("$file_path")
      fi
    fi
  done <<< "$git_status_output"
fi

if (( ${#changed_files[@]} == 0 )); then
  echo "🚦 Mary preflight: ไม่มีไฟล์ที่เปลี่ยน แค่รายงานเฉย ๆ"
  return 0 2>/dev/null || exit 0
fi

echo "🚦 Mary preflight (report-only)"
echo "   Source : interactive"
echo "   Files  : ${#changed_files[@]}"
echo "----------------------------------------"

for rel in "${changed_files[@]}"; do
  # normalize path (Mary จะ handle เอง)
  abs="$LUKA_ROOT/$rel"

  echo ""
  echo "📄 $rel"
  python3 "$LUKA_ROOT/tools/mary_dispatch.py" \
    --source interactive \
    --path "$abs" \
    --op write \
    2>/dev/null || echo "   ⚠️ Mary router error (non-blocking)"
done

echo ""
echo "✅ Mary preflight เสร็จแล้ว (report-only, ไม่ block save/commit)"
return 0 2>/dev/null || exit 0
