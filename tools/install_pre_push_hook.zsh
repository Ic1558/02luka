#!/usr/bin/env zsh
# tools/install_pre_push_hook.zsh
# Install pre-push hook to block direct push to origin/main

set -euo pipefail

LUKA_SOT="${LUKA_SOT:-$HOME/02luka}"
HOOK_SOURCE="$LUKA_SOT/tools/pre-push-hook.zsh"
HOOK_TARGET="$LUKA_SOT/.git/hooks/pre-push"

if [[ ! -f "$HOOK_SOURCE" ]]; then
  echo "❌ Error: Hook source not found: $HOOK_SOURCE"
  exit 1
fi

# Copy hook
cp "$HOOK_SOURCE" "$HOOK_TARGET"
chmod +x "$HOOK_TARGET"

echo "✅ Pre-push hook installed: $HOOK_TARGET"
echo "   Blocks: git push origin main"
echo "   Override: ALLOW_PUSH_MAIN=1 git push origin main"
