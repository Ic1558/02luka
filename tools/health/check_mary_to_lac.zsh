#!/usr/bin/env zsh
set -euo pipefail

ROOT="${LUKA_SOT:-${LUKA_ROOT:-$HOME/02luka}}"
INBOX="$ROOT/bridge/inbox/ENTRY"
PROCESSED="$ROOT/bridge/processed/lac"
LOG_FILE="$ROOT/logs/lac_daemon.log"
DISPATCHER="$ROOT/tools/watchers/mary_dispatcher.zsh"

mkdir -p "$INBOX" "$PROCESSED"

ts="$(date +%Y%m%d-%H%M%S)"
wo_id="WO-TEST-LAC-HEALTH-${ts}-$$"
wo_file="$INBOX/${wo_id}.yaml"
tmp_file="$INBOX/.${wo_id}.tmp"

cat > "$tmp_file" <<YAML
wo_id: "${wo_id}"
target: lac
intent: "health"
objective: "Mary -> LAC health check"
source: "health_check"
files: []
YAML

mv "$tmp_file" "$wo_file"

if [[ -f "$DISPATCHER" ]]; then
  if ! /bin/zsh "$DISPATCHER" >/dev/null 2>&1; then
    echo "WARN: mary_dispatcher.zsh returned non-zero" >&2
  fi
fi

tail_logs() {
  if [[ -f "$LOG_FILE" ]]; then
    tail -10 "$LOG_FILE"
  else
    echo "lac_daemon.log not found at $LOG_FILE"
  fi
}

archive_health_wos() {
  local archive_dir="$ROOT/bridge/processed/lac/_tests"
  mkdir -p "$archive_dir"
  local f
  for f in "$ROOT/bridge/outbox/ENTRY"/WO-TEST-LAC-HEALTH*.yaml; do
    [[ -e "$f" ]] || continue
    mv "$f" "$archive_dir/"
  done
}

on_exit() {
  archive_health_wos || true
  tail_logs || true
}

trap on_exit EXIT

deadline=$((SECONDS + 30))
while (( SECONDS < deadline )); do
  if [[ -f "$PROCESSED/${wo_id}.yaml" ]]; then
    echo "OK: ${wo_id} processed by LAC"
    exit 0
  fi
  sleep 1
done

echo "ERROR: ${wo_id} not found in bridge/processed/lac after 30s" >&2
exit 1
