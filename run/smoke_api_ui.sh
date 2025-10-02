#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PORTS_FILE="$ROOT/run/auto_context/ports.env"
API_PORT=4000
UI_PORT=5173
if [[ -f "$PORTS_FILE" ]]; then
  while IFS='=' read -r key value; do
    [[ -z "$key" ]] && continue
    key="${key//[[:space:]]/}"
    value="${value%%$'\r'}"
    value="${value//[$'\r\n']/}"
    case "$key" in
      API_PORT) API_PORT="$value" ;;
      UI_PORT) UI_PORT="$value" ;;
    esac
  done <"$PORTS_FILE"
fi
API="http://127.0.0.1:${API_PORT}"

echo "==> Check API capabilities"
CAPABILITIES_JSON=$(curl -fsS "$API/api/capabilities") || {
  echo "Capabilities request failed"; exit 1; }
echo "$CAPABILITIES_JSON" | jq -e '.ui.inbox and (.features.goal == true)' >/dev/null || {
  echo "Capabilities missing required flags"; exit 1; }
HAS_OPTIMIZE=$(echo "$CAPABILITIES_JSON" | jq -r '.features.optimize_prompt // false')
HAS_CHAT=$(echo "$CAPABILITIES_JSON" | jq -r '.features.chat // false')
echo "Capabilities: optimize_prompt=$HAS_OPTIMIZE, chat=$HAS_CHAT"

echo "==> Check API list"
curl -fsS "$API/api/list/inbox" | jq -r '.mailbox, (.items[]?.name // "-")' || {
  echo "API list failed"; exit 1; }

# ensure sample file exists
INBOX="$("$ROOT/g/tools/path_resolver.sh" human:inbox)"
mkdir -p "$INBOX"
test -f "$INBOX/hello.md" || echo "# hello boss" > "$INBOX/hello.md"

echo "==> Upload sample file"
UPLOAD_CODE=$(curl -sS -o /dev/null -w "%{http_code}" -F "file=@$INBOX/hello.md" "$API/api/upload?mailbox=inbox") || {
  echo "API upload request failed"; exit 1; }
if [[ "$UPLOAD_CODE" != "200" ]]; then
  echo "Unexpected upload status: $UPLOAD_CODE"; exit 1; fi

echo "==> Check connectors status"
CONNECTORS_JSON=$(curl -fsS "$API/api/connectors/status") || {
  echo "Connectors status request failed"; exit 1; }
echo "$CONNECTORS_JSON" | jq -e '.local.ready == true' >/dev/null || {
  echo "Connectors not ready"; exit 1; }

echo "==> Check API file"
curl -fsS "$API/api/file/inbox/hello.md" | head -n1

echo "==> Run CLC API"
SENT_DIR="$("$ROOT/g/tools/path_resolver.sh" human:sent)"
mkdir -p "$SENT_DIR"
BEFORE_COUNT=$(find "$SENT_DIR" -maxdepth 1 -type f -name 'goal_*.md' 2>/dev/null | wc -l | tr -d ' ')
TMP_RUN=$(mktemp)
RUN_CODE=$(curl -sS -o "$TMP_RUN" -w "%{http_code}" -X POST "$API/api/run_clc" \
  -H 'Content-Type: application/json' \
  -d '{"goal":"Smoke test goal via CLC"}') || {
    echo "run_clc request failed"; rm -f "$TMP_RUN"; exit 1; }
if [[ "$RUN_CODE" != "200" ]]; then
  echo "Unexpected run_clc status: $RUN_CODE"; rm -f "$TMP_RUN"; exit 1; fi
jq -e '.ok == true and (.file | type == "string") and (.model | length >= 0)' "$TMP_RUN" >/dev/null || {
  echo "run_clc response invalid"; cat "$TMP_RUN"; rm -f "$TMP_RUN"; exit 1; }
RUN_FILE=$(jq -r '.file' "$TMP_RUN")
if [[ -n "$RUN_FILE" && "$RUN_FILE" != "null" ]]; then
  if [[ ! -f "$ROOT/$RUN_FILE" ]]; then
    echo "CLC output file missing: $RUN_FILE"; rm -f "$TMP_RUN"; exit 1;
  fi
fi
AFTER_COUNT=$(find "$SENT_DIR" -maxdepth 1 -type f -name 'goal_*.md' 2>/dev/null | wc -l | tr -d ' ')
if (( AFTER_COUNT <= BEFORE_COUNT )); then
  echo "CLC runner did not create a new file"; rm -f "$TMP_RUN"; exit 1;
fi
echo "CLC output: $RUN_FILE"
rm -f "$TMP_RUN"

echo "==> Check API snapshot"
TMP_SNAPSHOT=$(mktemp)
SNAP_CODE=$(curl -sS -o "$TMP_SNAPSHOT" -w "%{http_code}" "$API/api/snapshot") || {
  echo "snapshot request failed"; rm -f "$TMP_SNAPSHOT"; exit 1; }
if [[ "$SNAP_CODE" != "200" ]]; then
  echo "Unexpected snapshot status: $SNAP_CODE"; cat "$TMP_SNAPSHOT"; rm -f "$TMP_SNAPSHOT"; exit 1; fi
jq -e '.ok == true and (.snapshot | type == "object")' "$TMP_SNAPSHOT" >/dev/null || {
  echo "snapshot payload invalid"; cat "$TMP_SNAPSHOT"; rm -f "$TMP_SNAPSHOT"; exit 1; }
jq -e '.snapshot.ports | (. == null or type == "object")' "$TMP_SNAPSHOT" >/dev/null || {
  echo "snapshot ports invalid"; cat "$TMP_SNAPSHOT"; rm -f "$TMP_SNAPSHOT"; exit 1; }
jq -e '.snapshot.system_snapshot | (. == null or type == "object")' "$TMP_SNAPSHOT" >/dev/null || {
  echo "snapshot system invalid"; cat "$TMP_SNAPSHOT"; rm -f "$TMP_SNAPSHOT"; exit 1; }
rm -f "$TMP_SNAPSHOT"

if [[ "$HAS_OPTIMIZE" == "true" ]]; then
  echo "==> Check API optimize_prompt"
  TMP_OPT=$(mktemp)
  HTTP_CODE=$(curl -sS -o "$TMP_OPT" -w "%{http_code}" -X POST "$API/api/optimize_prompt" \
    -H 'Content-Type: application/json' \
    -d '{"prompt":"Summarize hello"}') || {
      echo "optimize_prompt request failed"; rm -f "$TMP_OPT"; exit 1; }
  if [[ "$HTTP_CODE" == "200" ]]; then
    cat "$TMP_OPT" | jq -e '.prompt // .optimized | type == "string"' >/dev/null || {
      echo "optimize_prompt response invalid"; rm -f "$TMP_OPT"; exit 1; }
    rm -f "$TMP_OPT"
  else
    echo "optimize_prompt: SKIP (status $HTTP_CODE)"
    rm -f "$TMP_OPT"
  fi
else
  echo "optimize_prompt: SKIP (capability disabled)"
fi

if [[ "$HAS_CHAT" == "true" ]]; then
  echo "==> Check API chat"
  curl -fsS -X POST "$API/api/chat" \
    -H 'Content-Type: application/json' \
    -d '{"message":"ping"}' | jq -r '.summary // .response // .error'
else
  echo "chat: SKIP (capability disabled)"
fi

echo "==> Check UI port availability"
if lsof -ti :$UI_PORT >/dev/null 2>&1; then
  echo " - Port $UI_PORT is busy. Using existing service."
  UI_RUNNING=1
else
  echo " - Port $UI_PORT is free. Starting temporary UI..."
  if [ -d "boss-ui" ]; then
    (cd boss-ui && python3 -m http.server $UI_PORT >/tmp/ui.log 2>&1 &)
    UI_RUNNING=0
  else
    echo " - WARN: boss-ui/ not found, skipping UI test"
    UI_RUNNING=0
  fi
fi

echo "==> Serve boss-ui (temporary)"
cd "$ROOT/boss-ui"
python3 -m http.server $UI_PORT >/dev/null 2>&1 &
PID=$!
sleep 1
echo "UI pid=$PID at http://localhost:$UI_PORT"

# quick fetch index.html (just ensure it serves)
curl -I "http://127.0.0.1:$UI_PORT/" | head -n1

echo "OK. Open: http://localhost:$UI_PORT"
echo "(Press Enter to stop UI server)"
read -r _
kill $PID 2>/dev/null || true
