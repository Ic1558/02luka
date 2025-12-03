#!/usr/bin/env bash
set -euo pipefail

CORE_PATHS=(
  "agents/liam/core.py"
  "agents/liam/executor.py"
  "agents/liam/mary_router.py"
  "agents/alter/polish_service.py"
  "agents/clc/model_router.py"
)

for path in "${CORE_PATHS[@]}"; do
  if [[ ! -f "$path" ]]; then
    echo "MISSING REQUIRED CORE AGENT FILE: $path"
    exit 1
  fi
done

echo "Core agent files present."
