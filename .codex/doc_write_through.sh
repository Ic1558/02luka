#!/usr/bin/env bash
set -euo pipefail

# กำหนด SOT (Google Drive) — ต้อง Available offline เท่านั้น
SOT="$HOME/Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/My Drive/02luka"

# รายการไฟล์/โฟลเดอร์ที่จะ push กลับไป SOT
declare -a FILES=(
  "02luka.md"
  "CONTEXT_ENGINEERING.md"
  "f/ai_context/ai_context_entry.md"
  "f/ai_context/mapping.json"
)

for p in "${FILES[@]}"; do
  src="$p"
  dst="$SOT/$p"
  mkdir -p "$(dirname "$dst")"
  # ตรวจ placeholder/streaming (กันกรณียังไม่ดาวน์โหลด)
  if [ ! -e "$dst" ] && [ ! -e "$(dirname "$dst")" ]; then
    echo "⚠️  Skip $p: $dst not present and parent missing; ensure SOT online/offline."
    continue
  fi
  cp -f "$src" "$dst"
  echo "↪︎ wrote $src -> $dst"
done

echo "✅ write-through complete"
