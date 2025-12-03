#!/usr/bin/env bash
set -euo pipefail

SYSTEM_TOOLS=(
  "tools/clear_mem_now.zsh"
  "tools/check_ram.zsh"
  "tools/system_health_check.zsh"
)

for tool in "${SYSTEM_TOOLS[@]}"; do
  if [[ ! -f "$tool" ]]; then
    echo "MISSING REQUIRED SYSTEM TOOL: $tool"
    exit 1
  fi
done

echo "System tools present."
