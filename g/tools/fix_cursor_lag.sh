#!/usr/bin/env bash
set -euo pipefail

echo "==> Killing stray Cursor processes"
pkill -f "Cursor" 2>/dev/null || true
# รอให้โปรเซสจบ
sleep 1
pgrep -fl Cursor || echo "(no Cursor processes running)"

# หา git root (ถ้ามี) เพื่อยืนยันอยู่ใน repo
if git rev-parse --show-toplevel >/dev/null 2>&1; then
  ROOT="$(git rev-parse --show-toplevel)"
else
  ROOT="$(pwd)"
fi
cd "$ROOT"

echo "==> Writing .cursorignore (safe defaults)"
cat > .cursorignore <<'IGNORE'
# Build / deps
node_modules/
dist/
build/
out/
output/
coverage/
.next/
*.tgz
*.zip

# Logs / caches / virtual envs
*.log
*.tmp
*.cache/
.cache/
.vscode-test/
.venv*/
__pycache__/

# Repo-specific heavy dirs
boss-api/node_modules/
run/**/artifacts/
run/**/tmp/
run/**/cache/
run/**/logs/
IGNORE

echo "==> Optional: clear Cursor cache (workspaceStorage)"
READABLE="${HOME}/Library/Application Support/Cursor/User/workspaceStorage"
if [ -d "$READABLE" ]; then
  echo "   Cache dir: $READABLE"
  # ป้องกันพลาด: สำรอง metadata แล้วค่อยลบ cache
  TAR="/tmp/cursor_ws_cache_backup_$(date +%s).tar.gz"
  tar -czf "$TAR" -C "$READABLE" . >/dev/null 2>&1 || true
  rm -rf "$READABLE"/* || true
  echo "   Cleared. Backup: $TAR"
else
  echo "   Skip (cache dir not found)"
fi

echo "==> Git add .cursorignore (optional)"
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git add .cursorignore || true
fi

echo "==> Done. Reopen Cursor and keep only this repo as a workspace."
echo "Tips:"
echo "  • Settings > Performance: limit background indexing"
echo "  • Avoid opening your whole Google Drive as a workspace"
