#!/usr/bin/env bash
set -euo pipefail
DIR="g/reports/memory_autosave"
ARCH="$DIR/.archive"
mkdir -p "$ARCH"

# เก็บไฟล์ล่าสุดต่อ hash
# ชื่อไฟล์รูปแบบ: autosave_YYYYmmdd_HHMMSS_<HASH>_<RUNID>.md
declare -A latest
while IFS= read -r -d '' f; do
  base="$(basename "$f")"
  hash="$(echo "$base" | awk -F'_' '{print $3}')"
  ts="$(echo "$base" | awk -F'_' '{print $2}')"
  key="$hash"
  if [ -z "${latest[$key]+x}" ]; then
    latest[$key]="$ts $f"
  else
    old_ts="$(echo "${latest[$key]}" | awk '{print $1}')"
    if [[ "$ts" > "$old_ts" ]]; then
      latest[$key]="$ts $f"
    fi
  fi
done < <(find "$DIR" -maxdepth 1 -type f -name "autosave_*.md" -print0)

# ย้ายตัวที่ไม่ใช่ล่าสุดเข้าคลัง
while IFS= read -r -d '' f; do
  base="$(basename "$f")"
  hash="$(echo "$base" | awk -F'_' '{print $3}')"
  keep="$(echo "${latest[$hash]}" | awk '{print $2}')"
  if [ "$f" != "$keep" ]; then
    mv -f "$f" "$ARCH/"
    echo "[dedupe] archived $base"
  fi
done < <(find "$DIR" -maxdepth 1 -type f -name "autosave_*.md" -print0)

echo "[dedupe] done"
