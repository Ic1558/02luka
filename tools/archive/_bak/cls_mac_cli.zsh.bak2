#!/usr/bin/env zsh
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 '<command>' [timeout_sec]" >&2
  exit 2
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${(%):-%N}")" && pwd)"
"${SCRIPT_DIR}/cls_shell_request.zsh" "$@"
