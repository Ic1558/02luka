#!/usr/bin/env bash
set -euo pipefail

API="http://127.0.0.1:${API_PORT:-4000}"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

jq_expect() {
  local json="$1"
  local filter="$2"
  local message="$3"
  if ! jq -e "$filter" <<<"$json" >/dev/null; then
    echo "$message" >&2
    echo "Response was:" >&2
    echo "$json" >&2
    exit 1
  fi
}

echo "==> Check API capabilities"
CAPABILITIES_JSON=$(curl -fsS "$API/api/capabilities") || {
  echo "Capabilities request failed" >&2
  exit 1
}
jq_expect "$CAPABILITIES_JSON" 'type == "object"' "Capabilities response was not a JSON object"

echo "==> RAG ingest sample document"
RAG_FILE="$TMP_DIR/rag.txt"
RAG_TEXT="Smoke RAG document at $(date -Iseconds)"
printf '%s\n' "$RAG_TEXT" >"$RAG_FILE"
RAG_INGEST_JSON=$(curl -fsS -X POST "$API/api/rag/ingest" \
  -H 'Accept: application/json' \
  -F "file=@$RAG_FILE;type=text/plain" \
  -F "metadata={\"namespace\":\"smoke\",\"source\":\"smoke_api_ui.sh\"};type=application/json") || {
    echo "RAG ingest request failed" >&2
    exit 1
  }
jq_expect "$RAG_INGEST_JSON" 'type == "object"' "RAG ingest did not return JSON"

RAG_DOC_ID=$(jq -r 'first((.ids // empty) + (.documents[]?.id // empty) + (.ingested[]?.id // empty) + (.document_id // empty))' <<<"$RAG_INGEST_JSON")
if [[ -z "$RAG_DOC_ID" || "$RAG_DOC_ID" == "null" ]]; then
  RAG_DOC_ID="smoke"
fi

echo "==> RAG query for recent ingest"
RAG_QUERY_PAYLOAD=$(jq -n --arg query "สรุปไฟล์ที่เพิ่ง ingest" --arg namespace "$RAG_DOC_ID" '{query: $query, namespace: $namespace}')
RAG_QUERY_JSON=$(curl -fsS -X POST "$API/api/rag/query" -H 'Content-Type: application/json' -d "$RAG_QUERY_PAYLOAD") || {
  echo "RAG query request failed" >&2
  exit 1
}
jq_expect "$RAG_QUERY_JSON" 'type == "object"' "RAG query did not return JSON"
jq_expect "$RAG_QUERY_JSON" '(.answer // .response // .result // "") | (type == "string" and length > 0)' "RAG query response missing answer"

echo "==> SQL query demo"
SQL_PAYLOAD=$(jq -n --arg query "นับผู้ใช้ทั้งหมด" '{query: $query}')
SQL_JSON=$(curl -fsS -X POST "$API/api/sql/query" -H 'Content-Type: application/json' -d "$SQL_PAYLOAD") || {
  echo "SQL query request failed" >&2
  exit 1
}
jq_expect "$SQL_JSON" 'type == "object"' "SQL query did not return JSON"
jq_expect "$SQL_JSON" '.columns | type == "array"' "SQL query response missing columns"
jq_expect "$SQL_JSON" '.rows | type == "array"' "SQL query response missing rows"

echo "==> OCR extract sample image"
OCR_IMAGE="$TMP_DIR/sample.png"
python - <<'PY' >"$OCR_IMAGE"
import base64
import sys

DATA = (
    "iVBORw0KGgoAAAANSUhEUgAAAPAAAAB4CAIAAABD1OhwAAAEvElEQVR4nO3YzUtUexzH8SkvyJHg"
    "iJjpjOtcZeggaCOOkzOzcSFCGkKZBOXKv8BFrhyECFyIoKC4qRa5FR8iSHzIzSxmUQt3jlAUpW6c"
    "GGK+d3HwcKm5d3OCmM99v1aH35PnB28OOJfMLASouPynXwD4nQgaUggaUggaUggaUggaUggaUgga"
    "UggaUggaUggaUggaUggaUggaUggaUggaUggaUggaUggaUggaUggaUggaUggaUggaUggaUggaUgga"
    "UggaUggaUggaUggaUggaUggaUggaUggaUggaUggaUggaUggaUggaUggaUoIGnc1m0+l0IpFIpVL5"
    "fD4UCjmOMzw87C+4d++e4zje8/LycjQa7erqikajKysr3mBtba33kM/n29raPn36VFNT03vh2bNn"
    "/lFlty8uLra3t8fj8f7+fu8FQqGQd0I8Hm9vb3/79m3AO6KSWDA3b97M5/Nm9urVq+HhYTNzXbe1"
    "tfXHjx9mViqVOjs7Xdc1s/X19VgsdnJyYmYnJyexWGxra8tbb2aFQiEWi+3v7/sjPym7fXNzM5FI"
    "nJ+fm9na2trt27e9xf4JuVzuxo0bAe+IChI06KampsPDQzMrFovb29tm5rru2NiYl2Y2m338+LGX"
    "V19f397enr9xd3c3mUzaRXwPHjxYXFz0psoGXXZ7Op32/pDn0aNHxWLxnyeUSqW6urqAd0QFCRr0"
    "8vJyY2Pjw4cP37x54424rvvixYupqSkzy2Qyq6urXl7hcLhQKPgbC4VCOBz21s/Ozo6Pj/tTZYMu"
    "uz0SiXz//v3Xxf4J6+vrd+7cCXhHVJCgQZvZt2/flpaWWltbnzx5Ymau6379+rW7u9vMUqnU2dlZ"
    "2aDPz88jkYiZOY5z/fr1gYEBf8pxnPgF/6tcdntjY2PZoL0Tbt26VVdX9/Hjx+B3RKUIFPTnz593"
    "d3f952vXrtnF17Gnp+fo6CiVSvkjyWTSX2xmOzs76XTazK5cuXJ2dpZMJufn572psl/ostt7enre"
    "vXvnjZRKpdHR0Z9OmJmZyWQyQe6IyhIo6C9fvkQikaOjIzP78OFDR0eHXcQ0PT19//79mZkZf2Rj"
    "YyMWi52entrFf3WvX7/2Z/P5fDgcfv/+vf1L0GW3v3z5MplMeh/p58+f371711vsn5DNZgcHB4Pc"
    "EZXlryC/kNTX1y8sLAwNDTmOU1VVtbS05E/19/dPTk7mcjl/JJ1OHx8fJxKJ6urqYrE4MTHR19fn"
    "zzY3Nz99+nRkZOTg4KBYLPb29nrjXV1dmUzmP7YfHh5Go9GrV682NDTMzc399IYtLS25XK5UKl2+"
    "zC/u/wuXzOxPvwPw2/DdghSChhSChhSChhSChhSChhSChhSChhSChhSChhSChhSChhSChhSChhSC"
    "hhSChhSChhSChhSChhSChhSChhSChhSChhSChhSChhSChhSChhSChhSChhSChhSChhSChhSChhSC"
    "hhSChhSChhSChhSChhSChhSChhSChhSChhSChhSChhSChhSChhSChhSChhSChhSChhSChhSChhSC"
    "hhSChhSChhSChhSChhSChhSChhSChhSChhSChhSChhSChhSChhSChhSChhSChhSChpS/AT0vDo77"
    "/eeOAAAAAElFTkSuQmCC"
)
sys.stdout.buffer.write(base64.b64decode(DATA))
PY

OCR_JSON=$(curl -fsS -X POST "$API/api/ocr/extract" \
  -H 'Accept: application/json' \
  -F "file=@$OCR_IMAGE;type=image/png") || {
    echo "OCR extract request failed" >&2
    exit 1
  }
jq_expect "$OCR_JSON" 'type == "object"' "OCR extract did not return JSON"
jq_expect "$OCR_JSON" '(.text // .content // "") | (type == "string" and length > 0)' "OCR extract response missing text"

echo "==> Smoke checks complete"
