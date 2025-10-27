#!/usr/bin/env zsh
set -euo pipefail
export KEEP_HOURS="${KEEP_HOURS:-24}"
export DRYRUN="${DRYRUN:-0}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec "$ROOT/run/report_rotate.zsh"
