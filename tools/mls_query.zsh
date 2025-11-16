#!/usr/bin/env zsh
set -euo pipefail

##
## mls_query.zsh
##
## Thin Zsh wrapper around tools/mls_query.py so that agents
## (Mary / CLC / CLS / Codex) can call a single stable CLI:
##
##   tools/mls_query.zsh recent --limit 10 --type failure --format json
##   tools/mls_query.zsh summary
##

SCRIPT_DIR="$(cd "$(dirname "${(%):-%N}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

MLS_PY="${SCRIPT_DIR}/mls_query.py"

if [[ ! -f "${MLS_PY}" ]]; then
  echo "[mls_query] error: ${MLS_PY} not found" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "[mls_query] error: python3 not available on PATH" >&2
  exit 1
fi

cd "${REPO_ROOT}"

exec python3 "${MLS_PY}" "$@"
