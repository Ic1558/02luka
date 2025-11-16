#!/usr/bin/env zsh
set -euo pipefail
source ~/.config/02luka/rag.env 2>/dev/null || true
cd "$HOME/02luka/g/rag"
exec ./.venv/bin/uvicorn server:app --host 127.0.0.1 --port 8765 --log-level info
