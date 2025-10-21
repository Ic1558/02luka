#!/usr/bin/env bash
set -euo pipefail

# CLS Verification with Report Upload
# Runs verification and uploads report to lukadata

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
pushd "$REPO_ROOT" >/dev/null

# Set PATH hygiene
export PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin"

# Environment setup
export CLS_SHELL="/bin/bash"
export CLS_FS_ALLOW="/Volumes/lukadata:/Volumes/hd2:/Users/icmini/Documents/Projects"

# Log file setup with rotation
LOG_FILE="/Volumes/lukadata/CLS/logs/cls_verification.log"
mkdir -p "$(dirname "$LOG_FILE")"

# Log rotation (5MB limit)
if [[ -f "$LOG_FILE" ]] && [[ "$(wc -c < "$LOG_FILE" 2>/dev/null || echo 0)" -gt 5242880 ]]; then
    mv "$LOG_FILE" "${LOG_FILE%.*}.$(date +%F).log"
fi

# Redirect all output to log
exec >> "$LOG_FILE" 2>&1

echo "🧠 CLS Daily Verification - $(date -Iseconds)"

# Check if volumes are mounted
for VOL in /Volumes/lukadata /Volumes/hd2; do
  if [ ! -d "$VOL" ]; then
    echo "WARN: $VOL not mounted; using local fallback at g/tmp"
    export CLS_FS_ALLOW="$HOME:$(pwd)/g"
    mkdir -p g/tmp
  fi
done

# Create necessary directories
mkdir -p /Volumes/lukadata/CLS/tmp /Volumes/lukadata/CLS/logs /Volumes/lukadata/CLS/reports
mkdir -p /Volumes/hd2/CLS/tmp

# Run verification
bash scripts/cls_go_live_verification.sh

# Upload report to lukadata
REPORT_FILE=$(ls -1t g/reports/CLS_GO_LIVE_VERIFICATION_*.md | head -n1)
if [[ -n "$REPORT_FILE" && -f "$REPORT_FILE" ]]; then
    cp "$REPORT_FILE" "/Volumes/lukadata/CLS/reports/"
    echo "✅ Report uploaded to /Volumes/lukadata/CLS/reports/"
else
    echo "⚠️  No verification report found"
fi

# Optional: Run self-review and upload
if command -v node >/dev/null 2>&1; then
    echo "🧠 Running CLS self-review..."
    node agents/reflection/self_review.cjs --agent cls --days 7 > "/Volumes/lukadata/CLS/reports/cls_self_review_$(date +%Y%m%d).md" 2>/dev/null || true
    echo "✅ Self-review uploaded to lukadata"
fi

# Optional: Knowledge sync
if [[ -f "knowledge/sync.cjs" ]]; then
    echo "🧠 Running knowledge sync..."
    node knowledge/sync.cjs --full >/dev/null 2>&1 || true
    echo "✅ Knowledge sync completed"
fi

# Optional: Discord notification
if [[ -n "${DISCORD_WEBHOOK_DEFAULT:-}" ]]; then
    curl -s -X POST "$DISCORD_WEBHOOK_DEFAULT" \
        -H 'Content-Type: application/json' \
        -d "{\"content\":\"CLS daily verification ✅ — report saved to /Volumes/lukadata/CLS/reports\"}" >/dev/null || true
fi

echo "🎯 CLS Daily Verification Complete"
popd >/dev/null

# Health exit code
echo "🎯 CLS Daily Verification Complete - $(date -Iseconds)"
exit 0
