#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${PORT:-4000}"
export NODE_ENV="${NODE_ENV:-development}"

echo "[dev] Starting assistant API on port ${PORT}" >&2
PORT="${PORT}" node "${ROOT_DIR}/apps/assistant-api/server.js"
