#!/usr/bin/env zsh
set -euo pipefail
usage(){ echo "Usage: $0 [--fix]"; exit 0 }
[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && usage

IS_DARWIN=false; [[ "$OSTYPE" == darwin* ]] && IS_DARWIN=true
$IS_DARWIN || { echo "This script targets macOS launchd."; exit 0; }

FIX=false; [[ "${1:-}" == "--fix" ]] && FIX=true

PL_DIR="$HOME/Library/LaunchAgents"
LIST=$(launchctl list | awk 'NR>1 && $3 ~ /^com\.02luka\./{print $1,$2,$3}')
echo "🔎 Scanning com.02luka.* LaunchAgents"
print -r -- "$LIST" | while read -r exit_code pid label; do
  exit_code=${exit_code:-"-"}; pid=${pid:-"-"}
  printf "• %-35s exit=%s pid=%s\n" "$label" "$exit_code" "$pid"
  PL="$PL_DIR/${label}.plist"
  if [[ -f "$PL" ]]; then
    plutil -lint "$PL" >/dev/null && echo "   plist OK" || echo "   plist INVALID"
    if $FIX; then
      echo "   reload…"
      launchctl unload "$PL" 2>/dev/null || true
      launchctl load   "$PL"
    fi
  else
    echo "   plist not found at $PL"
  fi
done
echo "✅ LaunchAgents scan complete."
