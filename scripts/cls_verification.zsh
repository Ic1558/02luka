#!/usr/bin/env zsh
set -euo pipefail
LOG="$HOME/Library/Logs/02luka/cls_verification.log"
TELEMETRY="$HOME/Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/My Drive/02luka/02luka-repo/g/telemetry"
mkdir -p "$TELEMETRY"
echo "$(date -u +%FT%TZ) CLS verification start" | tee -a "$LOG"
[[ -d "$HOME/Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/My Drive/02luka/02luka-repo" ]] || { echo "missing 02luka repo"; exit 2; }
echo "$(date -u +%FT%TZ) telemetry ok" >> "$TELEMETRY/cls_ping.log"
echo "$(date -u +%FT%TZ) CLS verification OK" | tee -a "$LOG"
