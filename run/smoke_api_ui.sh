#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
API="http://127.0.0.1:4000"
UI_PORT=5173

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

echo "==> Check API snapshot"
SNAPSHOT_JSON=$(curl -fsS "$API/api/snapshot") || {
  echo "Snapshot request failed"; exit 1; }
echo "$SNAPSHOT_JSON" | jq -e 'has("system") and has("mapping") and has("ports") and has("capabilities") and has("timestamp")' >/dev/null || {
  echo "Snapshot response missing keys"; exit 1; }

echo "==> Check API run preflight"
RUN_JSON=$(curl -fsS -X POST "$API/api/run" -H 'Content-Type: application/json' -d '{"cmd":"preflight"}') || {
  echo "Run preflight request failed"; exit 1; }
echo "$RUN_JSON" | jq -e '.ok == true' >/dev/null || {
  echo "Run preflight failed"; exit 1; }

echo "==> Check API file"
curl -fsS "$API/api/file/inbox/hello.md" | head -n1

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
