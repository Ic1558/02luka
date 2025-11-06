#!/usr/bin/env zsh
set -euo pipefail
BASE="${BASE:-$HOME/02luka}"
LIMIT="${1:-20}"
exec "$BASE/tools/ci/health_snapshot.sh" "$LIMIT"

