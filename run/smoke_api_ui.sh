#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
API="http://127.0.0.1:4000"
UI_PORT=5173

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

echo "==> Check API optimize_prompt"
curl -fsS -X POST "$API/api/optimize_prompt" \
  -H 'Content-Type: application/json' \
  -d '{"prompt":"Summarize hello"}' | jq -r '.optimized // .prompt // .error'

echo "==> Check API chat"
curl -fsS -X POST "$API/api/chat" \
  -H 'Content-Type: application/json' \
  -d '{"message":"ping"}' | jq -r '.summary // .error'

echo "==> Check UI port availability"
if lsof -ti :$UI_PORT >/dev/null 2>&1; then
  echo " - Port $UI_PORT is busy. Kill? (y/N)"
  read -r a; [[ "$a" == "y" || "$a" == "Y" ]] && lsof -ti :$UI_PORT | xargs kill -9 || true
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
