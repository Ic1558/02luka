#!/usr/bin/env zsh
# CLS Adapter: Run local commands/scripts deterministically
# Purpose: Execute tasks via CLS (local orchestrator)
# Usage: run_backend_task <command...>

set -euo pipefail

run_backend_task() {
  # $1..$N is the command you want the CLS lane to perform
  # For now we just exec the shell task; swap here if you later wrap CLS RPC.
  eval "$*"
}

