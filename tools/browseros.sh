#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PAYLOAD=""

if [[ $# -gt 0 ]]; then
  PAYLOAD="$1"
else
  PAYLOAD="$(cat)"
fi

if [[ -z "${PAYLOAD}" ]]; then
  cat <<USAGE >&2
Usage: tools/browseros.sh '{"tool":"browseros.workflow","params":{...}}'
       echo '{"tool":"browseros.workflow","params":{...}}' | tools/browseros.sh
USAGE
  exit 1
fi

CALLER="${BROWSEROS_CLI_CALLER:-CLI}"

printf '%s' "${PAYLOAD}" | node "${REPO_DIR}/knowledge/mcp/browseros.cjs" --direct --caller "${CALLER}"
