#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$HOME/Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/My Drive/02luka/02luka-repo"
HEALTH_FILE="$REPO_ROOT/g/reports/system_health_stamp.txt"

mkdir -p "$(dirname "$HEALTH_FILE")"
date +"%F %T" > "$HEALTH_FILE"

echo "System health timestamp updated: $(cat "$HEALTH_FILE")"
