#!/usr/bin/env zsh
set -euo pipefail

echo "Rolling back RND Phase 5 components..."

# Unload LaunchAgent
launchctl unload ~/Library/LaunchAgents/com.02luka.rnd.gate.plist >/dev/null 2>&1 || true

# Remove LaunchAgent plist
rm -f ~/Library/LaunchAgents/com.02luka.rnd.gate.plist

# Remove scripts
rm -f ~/02luka/tools/rnd_score_and_gate.zsh
rm -f ~/02luka/tools/rnd_ack_pr_comment.zsh
rm -f ~/02luka/tools/rnd_evidence_append.zsh

# Remove policy (optional - may want to keep for reference)
# rm -f ~/02luka/config/rnd_policy.yaml

# Preserve logs and evidence (for audit trail)
echo "✅ Rolled back RND Phase 5 components."
echo "ℹ️  Logs and evidence preserved in:"
echo "   - ~/02luka/logs/rnd_gate.*"
echo "   - ~/02luka/mls/rnd/lessons.jsonl"
echo "ℹ️  Policy file preserved: ~/02luka/config/rnd_policy.yaml"
