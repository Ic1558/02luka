#!/usr/bin/env zsh
set -euo pipefail

cd "$HOME/02luka"

echo "== Check dirty files =="
git status --porcelain=v1 || true
echo

echo "== Show last 30 ATG_RUNNER events =="
tail -n 30 g/telemetry/atg_runner.jsonl 2>/dev/null || echo "(no atg_runner.jsonl)"
echo

echo "== Temporarily stop bridge to halt runaway loop (you can re-run later) =="
# safest: stop via pkill by exact script name; adjust if you have launchd control wrappers
pgrep -fl "bridge.sh|gemini_bridge.py" || true
echo "-- killing gemini_bridge / bridge.sh --"
pkill -f "gemini_bridge.py" || true
pkill -f "/Users/icmini/02luka/bridge.sh" || true
sleep 0.5
pgrep -fl "bridge.sh|gemini_bridge.py" || echo "(stopped)"
echo

echo "Next: apply ignore+hash-guard+debounce in fs_watcher/gemini_bridge, then restart."
