#!/usr/bin/env zsh
set -euo pipefail
cd "$HOME/Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/My Drive/02luka/02luka-repo"

mkdir -p g/reports/archive/$(date +%Y-%m) g/logs

# Gzip logs >10MB
find g/logs -type f -name '*.log' -size +10M -exec gzip -f {} \; 2>/dev/null || true

# Archive old correlation & heartbeat reports (>7 days)
MONTH="g/reports/archive/$(date +%Y-%m)"
mkdir -p "$MONTH"
find g/reports/ops_atomic -maxdepth 1 -type f \( -name "ops_correlation_*.md" -o -name "heartbeat_*.md" \) -mtime +7 -exec mv {} "$MONTH"/ \; 2>/dev/null || true
find g/reports -maxdepth 1 -type f \( -name "ops_correlation_*.md" -o -name "heartbeat_*.md" \) -mtime +7 -exec mv {} "$MONTH"/ \; 2>/dev/null || true

echo "$(date -u +%F\ %T) rotate: OK" >> g/logs/_rotate_reports.log
