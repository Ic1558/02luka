#!/usr/bin/env zsh
set -u

echo "=== 1. Resetting Clipboard & Cleaning Flags ==="
printf "CLIP_RESET\n" | pbcopy
rm -f /tmp/atg_summary_done.txt /tmp/atg_summary_clip.log

echo "✅ Ready."
echo "👉 ACTION REQUIRED: Press the Raycast SUMMARY hotkey now!"
echo "   (Waiting for /tmp/atg_summary_done.txt to appear...)"

# Wait loop
while [[ ! -f /tmp/atg_summary_done.txt ]]; do
  sleep 0.1
done

echo ""
echo "=== LOG (/tmp/atg_summary_clip.log) ==="
cat /tmp/atg_summary_clip.log

echo ""
echo "=== CLIPBOARD CONTENT (First 12 lines) ==="
pbpaste | head -n 12