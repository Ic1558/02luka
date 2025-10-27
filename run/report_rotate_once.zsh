#!/usr/bin/env zsh
set -euo pipefail
export KEEP_HOURS="${KEEP_HOURS:-24}"
export DRYRUN="${DRYRUN:-0}"
exec "$HOME/02luka/run/report_rotate.zsh"
