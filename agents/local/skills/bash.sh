#!/usr/bin/env bash
#
# Phase 7.2: Bash Skill Wrapper
# Safe bash execution with guardrails
#
# Usage: bash.sh [script_path] [args...]
#        bash.sh -c "command string"
#
# Safety features:
# - No interactive TTY
# - Timeout handled by orchestrator
# - Dangerous pattern checks (belt & suspenders)

set -euo pipefail

# Reject obviously dangerous commands (belt & suspenders with policy.cjs)
check_dangerous() {
  local cmd="$*"

  if echo "$cmd" | grep -E -q '(mkfs|/dev/sd|shutdown|reboot|init [06]|chmod 777 /|rm -rf /)'; then
    echo "❌ Blocked: Dangerous command detected" >&2
    echo "Command: $cmd" >&2
    exit 113
  fi

  # Check for fork bomb
  if echo "$cmd" | grep -q ':|:'; then
    echo "❌ Blocked: Fork bomb detected" >&2
    exit 113
  fi
}

# Check all arguments
check_dangerous "$@"

# Execute bash with no profile/rc files for clean environment
exec bash --noprofile --norc "$@"
