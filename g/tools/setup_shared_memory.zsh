#!/usr/bin/env zsh
set -euo pipefail
export LUKA_SOT="${LUKA_SOT:-$HOME/02luka}"
export LUKA_HOME="${LUKA_HOME:-$HOME/02luka/g}"
[[ -d "$LUKA_SOT" ]] || { echo "ERROR: LUKA_SOT not found" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "ERROR: jq not found" >&2; exit 1; }
mkdir -p "$LUKA_SOT"/{shared_memory,logs,bridge/memory/{inbox,outbox,processed}} "$LUKA_SOT/tools"
if [[ ! -f "$LUKA_SOT/shared_memory/context.json" ]]; then
  cat > "$LUKA_SOT/shared_memory/context.json" <<EOF
{
  "version": "1.0",
  "last_update": "$(date -Iseconds)",
  "agents": {},
  "current_work": {},
  "paths": {"sot": "$LUKA_SOT", "working": "$LUKA_HOME", "bridge": "$LUKA_SOT/bridge"},
  "token_usage": {"total": 0, "saved": 0}
}
EOF
  jq . "$LUKA_SOT/shared_memory/context.json" >/dev/null || { echo "ERROR: Invalid JSON" >&2; exit 1; }
fi
cat > "$LUKA_SOT/tools/memory_sync.sh" <<'EOF'
#!/bin/sh
set -eu
MEMORY_FILE="${LUKA_SOT:-$HOME/02luka}/shared_memory/context.json"
BRIDGE_DIR="${LUKA_SOT:-$HOME/02luka}/bridge/memory"
mkdir -p "$BRIDGE_DIR/outbox"
tmp="$(mktemp)"
timestamp() { date -Iseconds; }
case "${1:-}" in
  update)
    agent="${2:?ERROR: agent required}"
    status="${3:?ERROR: status required}"
    jq --arg a "$agent" --arg s "$status" --arg ts "$(timestamp)" \
      '.last_update=$ts | .agents[$a] = (.agents[$a] // {}) + {status:$s,last_seen:$ts}' \
      "$MEMORY_FILE" > "$tmp" && mv "$tmp" "$MEMORY_FILE"
    printf '{"event":"agent_update","agent":"%s","status":"%s","ts":"%s"}\n' "$agent" "$status" "$(timestamp)" \
      > "$BRIDGE_DIR/outbox/$(date +%s)_broadcast.json"
    ;;
  get) cat "$MEMORY_FILE" ;;
  *) echo "Usage: $0 {update|get} [agent] [status]" >&2; exit 1 ;;
esac
EOF
chmod +x "$LUKA_SOT/tools/memory_sync.sh"
cat > "$LUKA_SOT/tools/bridge_monitor.sh" <<'EOF'
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
EOF
chmod +x "$LUKA_SOT/tools/bridge_monitor.sh"
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$HOME/Library/LaunchAgents/com.02luka.memory.bridge.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.02luka.memory.bridge</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/sh</string>
    <string>-lc</string>
    <string>export LUKA_SOT="$HOME/02luka"; "$HOME/02luka/tools/bridge_monitor.sh"</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>ThrottleInterval</key><integer>30</integer>
  <key>StandardOutPath</key><string>~/02luka/logs/bridge_monitor.out.log</string>
  <key>StandardErrorPath</key><string>~/02luka/logs/bridge_monitor.err.log</string>
</dict></plist>
PLIST
launchctl unload "$HOME/Library/LaunchAgents/com.02luka.memory.bridge.plist" >/dev/null 2>&1 || true
launchctl load  "$HOME/Library/LaunchAgents/com.02luka.memory.bridge.plist"
echo "✅ Shared memory bootstrap complete."
