#!/usr/bin/env bash
set -euo pipefail
ROOT="${GITHUB_WORKSPACE:-$HOME/02luka}"
if [[ ! -d "$ROOT" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
  ROOT="$SCRIPT_DIR"
fi
cd "$ROOT"
mkdir -p g/reports
DATE="${1:-$(date +%F)}"
node knowledge/daily_digest.cjs --date="$DATE" --in="g/telemetry/web_actions.jsonl"
echo "Daily digest done for $DATE"
