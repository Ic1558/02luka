#!/usr/bin/env zsh
# GMX System/Plain Mode Launcher
# Purpose: Launch Gemini CLI in system/plain mode (no sandbox, OAuth)

set -euo pipefail

# Change to 02luka directory
cd ~/02luka || exit 1

# Unset GEMINI_API_KEY to force OAuth flow
# System/plain mode: --sandbox=false, --approval-mode=default
# Don't use --model auto (not valid in v0.21.1); use default or real model name
env -u GEMINI_API_KEY /opt/homebrew/bin/gemini --sandbox=false --approval-mode=default "$@"
