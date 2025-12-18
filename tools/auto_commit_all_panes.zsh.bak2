#!/usr/bin/env zsh
# Auto-commit all configured repos (each "pane")

set -euo pipefail

# 🔧 รายชื่อ repo ที่จะ auto-commit
REPOS=(
  "$HOME/02luka"
  "$HOME/02luka-memory"
)

# ข้อความ commit (ใส่เองได้ตอนเรียก, ถ้าไม่ใส่จะใช้ default)
DEFAULT_MSG="chore(auto): GG snapshot all panes"
MSG="${1:-$DEFAULT_MSG}"

echo "[auto-commit] message: $MSG"
echo

for REPO in "${REPOS[@]}"; do
  if [[ ! -d "$REPO/.git" ]]; then
    echo "[skip] $REPO (no .git)"
    continue
  fi

  echo "▶ Repo: $REPO"
  cd "$REPO"

  # ดูว่ามีอะไรที่ยังไม่ commit มั้ย
  CHANGES="$(git status --porcelain=v1)"
  if [[ -z "$CHANGES" ]]; then
    echo "  → clean (no changes), skip"
    echo
    continue
  fi

  echo "  → changes detected:"
  echo "$CHANGES" | sed 's/^/    /'

  # stage แล้ว commit ทีเดียว
  git add -A
  if git diff --cached --quiet; then
    echo "  → nothing staged after add -A, skip"
    echo
    continue
  fi

  git commit -m "$MSG" && echo "  ✅ committed"
  echo
done

echo "[auto-commit] done."
