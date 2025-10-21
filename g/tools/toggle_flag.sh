#!/usr/bin/env bash
# toggle_flag.sh  VAR VALUE   (edits .env and restarts "bridge" to pick up)
set -euo pipefail
ENV_FILE="${ENV_FILE:-.env}"
VAR="${1:-}"; VAL="${2:-}"
[[ -z "$VAR" || -z "$VAL" ]] && { echo "usage: $0 VAR VALUE"; exit 2; }

tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
if grep -qE "^${VAR}=" "$ENV_FILE"; then
  sed -E "s|^(${VAR}=).*|\1${VAL}|" "$ENV_FILE" > "$tmp"
else
  cat "$ENV_FILE" > "$tmp"
  echo "${VAR}=${VAL}" >> "$tmp"
fi
mv "$tmp" "$ENV_FILE"
echo "set: ${VAR}=${VAL}"

# restart bridge to read new env (cheap)
docker compose kill bridge >/dev/null 2>&1 || true
docker compose up -d bridge
