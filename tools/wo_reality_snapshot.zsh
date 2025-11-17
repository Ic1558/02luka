#!/usr/bin/env zsh
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: tools/wo_reality_snapshot.zsh [options] WO_ID

Options:
  --api-base URL  Override the dashboard API base (default: http://localhost:8767)

Environment variables:
  WO_API_BASE     Alternative way to override the API base.
EOF
  exit 1
}

BASE="${HOME}/02luka"
REPORT_DIR="${BASE}/g/reports/system/reality_hooks"

API_BASE_URL="${WO_API_BASE:-http://localhost:8767}"
WO_ID=""

while [ $# -gt 0 ]; do
  case "$1" in
    --api-base)
      shift || usage
      API_BASE_URL="$1"
      ;;
    --api-base=*)
      API_BASE_URL="${1#*=}"
      ;;
    -h|--help)
      usage
      ;;
    *)
      if [ -z "${WO_ID}" ]; then
        WO_ID="$1"
      else
        echo "Error: multiple WO IDs provided" >&2
        usage
      fi
      ;;
  esac
  shift
done

if [ -z "${WO_ID}" ]; then
  usage
fi

mkdir -p "${REPORT_DIR}"

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
