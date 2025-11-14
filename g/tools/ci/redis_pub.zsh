#!/usr/bin/env zsh
set -euo pipefail

CHANNEL="${1:-ci:events}"
PAYLOAD="${2:-}"

if [[ -z "${LUKA_REDIS_URL:-}" ]]; then
  LUKA_REDIS_URL="redis://127.0.0.1:6379"
fi

if [[ -z "$PAYLOAD" ]]; then
  echo "Usage: $0 <channel> '<json-payload>'" >&2
  exit 2
fi

redis-cli -u "$LUKA_REDIS_URL" PUBLISH "$CHANNEL" "$PAYLOAD" >/dev/null
echo "Published to $CHANNEL"

