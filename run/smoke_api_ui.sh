#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
<<<<<<< ours
API="http://127.0.0.1:${API_PORT:-4000}"
UI_PORT="${UI_PORT:-5173}"
=======
API="http://127.0.0.1:4000"
>>>>>>> theirs

echo "==> Check API capabilities"
CAPABILITIES_JSON=$(curl -fsS "$API/api/capabilities") || {
  echo "Capabilities request failed" >&2
  exit 1
}

echo "$CAPABILITIES_JSON" | jq -e '.ui.inbox == true and .features.goal == true' >/dev/null || {
  echo "Capabilities missing required flags" >&2
  exit 1
}

echo "$CAPABILITIES_JSON" | jq -e '.mailboxes.flow | (
    index("inbox") and index("outbox") and index("drafts") and index("sent") and index("deliverables")
  )' >/dev/null || {
  echo "Mailbox flow incomplete" >&2
  exit 1
}

echo "$CAPABILITIES_JSON" | jq -e '.mailboxes.aliases | any(.alias == "dropbox" and .target == "outbox")' >/dev/null || {
  echo "dropbox→outbox alias missing" >&2
  exit 1
}

HAS_OPTIMIZE=$(echo "$CAPABILITIES_JSON" | jq -r '.features.optimize_prompt // false')
HAS_CHAT=$(echo "$CAPABILITIES_JSON" | jq -r '.features.chat // false')

echo "Capabilities: optimize_prompt=$HAS_OPTIMIZE, chat=$HAS_CHAT"

echo "==> Resolve mailboxes"
INBOX_DIR="$($ROOT/g/tools/path_resolver.sh human:inbox)"
OUTBOX_DIR="$($ROOT/g/tools/path_resolver.sh human:outbox)"
SENT_DIR="$($ROOT/g/tools/path_resolver.sh human:sent)"
mkdir -p "$INBOX_DIR" "$OUTBOX_DIR" "$SENT_DIR"

SMOKE_FILE=""
cleanup() {
  if [[ -n "$SMOKE_FILE" ]]; then
    rm -f "$OUTBOX_DIR/$SMOKE_FILE" "$SENT_DIR/$SMOKE_FILE" 2>/dev/null || true
  fi
}
trap cleanup EXIT

echo "==> Check inbox listing"
curl -fsS "$API/api/list/inbox" | jq -e '.mailbox == "inbox"' >/dev/null || {
  echo "Inbox list failed" >&2
  exit 1
}

if [[ ! -f "$INBOX_DIR/hello.md" ]]; then
  echo "# hello boss" >"$INBOX_DIR/hello.md"
fi

UPLOAD_STATUS=$(curl -sS -o /dev/null -w "%{http_code}" -F "file=@$INBOX_DIR/hello.md" "$API/api/upload?mailbox=inbox") || {
  echo "Inbox upload request failed" >&2
  exit 1
}
if [[ "$UPLOAD_STATUS" != "200" ]]; then
  echo "Inbox upload returned $UPLOAD_STATUS" >&2
  exit 1
fi

echo "==> Create goal draft in outbox"
NOW_LABEL=$(date -Iseconds)
GOAL_PAYLOAD=$(jq -n --arg title "Smoke Goal $NOW_LABEL" --arg body "Smoke verification at $NOW_LABEL" '{title:$title, body:$body}')
GOAL_RESPONSE=$(curl -fsS -X POST "$API/api/goal?target=outbox" -H 'Content-Type: application/json' -d "$GOAL_PAYLOAD") || {
  echo "Goal creation failed" >&2
  exit 1
}
SMOKE_FILE=$(echo "$GOAL_RESPONSE" | jq -r '.name')
if [[ -z "$SMOKE_FILE" || "$SMOKE_FILE" == "null" ]]; then
  echo "Goal response missing name" >&2
  exit 1
fi

test -f "$OUTBOX_DIR/$SMOKE_FILE" || {
  echo "Goal file not found in outbox" >&2
  exit 1
}

echo "==> Verify outbox listings"
curl -fsS "$API/api/list/outbox" | jq -e --arg name "$SMOKE_FILE" '.items | map(.name) | index($name) >= 0' >/dev/null || {
  echo "Outbox listing missing goal" >&2
  exit 1
}

curl -fsS "$API/api/list/dropbox" | jq -e --arg name "$SMOKE_FILE" '.items | map(.name) | index($name) >= 0' >/dev/null || {
  echo "Dropbox alias listing missing goal" >&2
  exit 1
}

echo "==> Dispatch goal to sent"
mv "$OUTBOX_DIR/$SMOKE_FILE" "$SENT_DIR/$SMOKE_FILE"

curl -fsS "$API/api/list/sent" | jq -e --arg name "$SMOKE_FILE" '.items | map(.name) | index($name) >= 0' >/dev/null || {
  echo "Sent listing missing goal" >&2
  exit 1
}

echo "==> Check connectors status"
CONNECTORS_JSON=$(curl -fsS "$API/api/connectors/status") || {
  echo "Connectors status request failed" >&2
  exit 1
}
echo "$CONNECTORS_JSON" | jq -e '.local.ready == true' >/dev/null || {
  echo "Connectors not ready" >&2
  exit 1
}

echo "==> Fetch sample inbox file"
curl -fsS "$API/api/file/inbox/hello.md" | head -n1

if [[ "$HAS_OPTIMIZE" == "true" ]]; then
  echo "==> Check API optimize_prompt"
  TMP_OPT=$(mktemp)
  HTTP_CODE=$(curl -sS -o "$TMP_OPT" -w "%{http_code}" -X POST "$API/api/optimize_prompt" \
    -H 'Content-Type: application/json' \
    -d '{"prompt":"Summarize hello"}') || {
      echo "optimize_prompt request failed" >&2
      rm -f "$TMP_OPT"
      exit 1
    }
  if [[ "$HTTP_CODE" == "200" ]]; then
    jq -e '.prompt // .optimized | type == "string"' "$TMP_OPT" >/dev/null || {
      echo "optimize_prompt response invalid" >&2
      rm -f "$TMP_OPT"
      exit 1
    }
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

echo "==> Smoke checks complete"
