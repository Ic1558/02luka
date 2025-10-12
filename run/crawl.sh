#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <seeds-file> [crawler args...]" >&2
  exit 1
fi

SEEDS_FILE="$1"
shift || true

python3 "${REPO_ROOT}/crawler/crawl.py" "${SEEDS_FILE}" "$@"
python3 "${REPO_ROOT}/crawler/ingest.py"
