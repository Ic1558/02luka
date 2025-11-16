#!/usr/bin/env zsh
# RAG API Runner (compatibility shim)
# Created: 2025-11-17 (Phase 3 restoration per Boss request)
#
# NOTE: Actual RAG functionality now handled by knowledge/index.cjs
# This stub allows LaunchAgent to load without errors

set -euo pipefail

LOG_FILE="$HOME/02luka/logs/rag_api.log"
mkdir -p "$(dirname "$LOG_FILE")"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] RAG API shim - delegating to knowledge/index.cjs" >> "$LOG_FILE"

# Check if knowledge/index.cjs is available
if [[ -f "$HOME/02luka/knowledge/index.cjs" ]]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Knowledge system available, RAG handled by hybrid search" >> "$LOG_FILE"
else
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: knowledge/index.cjs not found" >> "$LOG_FILE"
fi

exit 0
