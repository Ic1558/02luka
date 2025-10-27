#!/usr/bin/env bash
set -euo pipefail
ROOT="${GITHUB_WORKSPACE:-$HOME/02luka}"
if [[ ! -d "$ROOT" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
  ROOT="$SCRIPT_DIR"
fi
cd "$ROOT"
# ensure sample telemetry exists
mkdir -p g/telemetry g/reports
test -s g/telemetry/web_actions.jsonl || {
  echo '{"ts":"'"$(date -Iseconds)"'","pattern":"token efficiency","ms":7.0,"ok":true,"agent":"CLS"}' >> g/telemetry/web_actions.jsonl
}
DATE="${1:-$(date +%F)}"
bash tools/run_daily_digest.sh "$DATE"
ls g/reports/daily_digest_*.json >/dev/null
ls g/reports/daily_digest_*.csv  >/dev/null
echo "OK: daily digest generated for $DATE"
