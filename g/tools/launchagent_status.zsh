#!/usr/bin/env zsh
set -euo pipefail

ROOT="${LUKA_SOT:-${HOME}/02luka}"
exec python3 "${ROOT}/g/tools/launchagent_status.py" "$@"

