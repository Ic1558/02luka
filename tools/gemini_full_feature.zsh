#!/usr/bin/env zsh
# Gemini Full Feature Launcher (Human/Full Mode)
# Purpose: Launch Gemini CLI with OAuth (not API key) + full feature flags

set -euo pipefail

# Change to 02luka directory
cd ~/02luka || exit 1

# Unset GEMINI_API_KEY to force OAuth flow
# This prevents CLI from using API key when OAuth is intended
# Use --approval-mode=default (not auto_edit) for proper approval flow
# Don't use --model auto (not valid in v0.21.1); use default or real model name
env -u GEMINI_API_KEY /opt/homebrew/bin/gemini --sandbox --approval-mode=default "$@"
