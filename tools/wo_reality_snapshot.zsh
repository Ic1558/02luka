#!/usr/bin/env zsh
set -euo pipefail

# Simple Reality Hook snapshot script.
# Fetches WO insights and stores them in g/reports/system/reality_hooks/.
# Honors WO_API_BASE env var for non-default dashboard ports.

BASE="${HOME}/02luka"
REPORT_DIR="${BASE}/g/reports/system/reality_hooks"

if [ $# -lt 1 ]; then
  echo "Usage: $0 WO_ID" >&2
  exit 1
fi

WO_ID="$1"

mkdir -p "${REPORT_DIR}"

API_BASE_URL="${WO_API_BASE:-http://localhost:8767}"
URL="${API_BASE_URL%/}/api/wos/${WO_ID}/insights"
echo "Using API base: ${API_BASE_URL}" >&2

TMP_FILE="$(mktemp)"
OUT_FILE="${REPORT_DIR}/WO-${WO_ID}.json"

echo "Fetching insights for ${WO_ID} from ${URL}..."
if command -v curl >/dev/null 2>&1; then
  curl -fsSL "${URL}" -o "${TMP_FILE}"
else
  echo "Error: curl not found" >&2
  exit 1
fi

if [ ! -s "${TMP_FILE}" ]; then
  echo "Error: empty response for ${WO_ID}" >&2
  rm -f "${TMP_FILE}"
  exit 1
fi

if command -v jq >/dev/null 2>&1; then
  jq '.' "${TMP_FILE}" > "${OUT_FILE}"
else
  mv "${TMP_FILE}" "${OUT_FILE}"
fi

rm -f "${TMP_FILE}"

echo "Reality snapshot written to: ${OUT_FILE}"
