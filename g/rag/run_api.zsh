#!/usr/bin/env zsh
set -euo pipefail

ROOT="${LUKA_SOT:-${HOME}/02luka}"
PORT="${RAG_PORT:-8765}"
HOST="${RAG_HOST:-127.0.0.1}"
DB="${RAG_DB_PATH:-${ROOT}/g/rag/store/fts.db}"

exec /usr/bin/python3 "${ROOT}/g/rag/server.py" --host "$HOST" --port "$PORT" --db "$DB"

