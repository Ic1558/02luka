#!/bin/sh
set -eu
BRIDGE_DIR="${LUKA_SOT:-$HOME/02luka}/bridge/memory"
PROC_DIR="$BRIDGE_DIR/processed"
LOG="${LUKA_SOT:-$HOME/02luka}/logs/bridge_monitor.log"
mkdir -p "$PROC_DIR"
echo "$(date -Iseconds) start bridge_monitor" >> "$LOG"
process_file() {
  local file="$1" lock="${file}.lock"
  if ln -s "$file" "$lock" 2>/dev/null; then
    local agent="$(basename "$file" | cut -d_ -f1)"
    "${LUKA_SOT:-$HOME/02luka}/tools/memory_sync.sh" update "${agent:-unknown}" processing || {
      echo "$(date -Iseconds) ERROR: memory_sync failed for $(basename "$file")" >> "$LOG"
      rm -f "$lock"
      return 1
    }
    mv "$file" "$PROC_DIR/$(basename "$file")"
    echo "$(date -Iseconds) processed $(basename "$file") agent=$agent" >> "$LOG"
    if command -v redis-cli >/dev/null 2>&1; then
      redis-cli -a "${REDIS_PASSWORD:-changeme-02luka}" PUBLISH memory:updates \
        "{\"event\":\"new_data\",\"agent\":\"$agent\",\"file\":\"$(basename "$file")\"}" >/dev/null 2>&1 || true
    fi
    rm -f "$lock"
    return 0
  fi
  return 1
}
while :; do
  for f in "$BRIDGE_DIR"/inbox/*.json; do
    [ -e "$f" ] || { sleep 3; break; }
    process_file "$f" || true
  done
  sleep 2
done
