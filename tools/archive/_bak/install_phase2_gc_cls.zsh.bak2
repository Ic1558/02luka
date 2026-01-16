#!/usr/bin/env zsh
set -euo pipefail

export LUKA_SOT="${LUKA_SOT:-$HOME/02luka}"
[[ -d "$LUKA_SOT" ]] || { echo "ERROR: LUKA_SOT not found: $LUKA_SOT" >&2; exit 1; }

mkdir -p "$LUKA_SOT/tools" "$LUKA_SOT/agents/cls_bridge" "$LUKA_SOT/logs" "$LUKA_SOT/metrics"

# 1) GC helper (fixed: inline timestamp, JSON validation)
cat > "$LUKA_SOT/tools/gc_memory_sync.sh" <<'EOF'
#!/bin/sh
set -eu

export LUKA_SOT="${LUKA_SOT:-$HOME/02luka}"
MEM_SYNC="$LUKA_SOT/tools/memory_sync.sh"
INBOX="$LUKA_SOT/bridge/memory/inbox"

gc_mem_update() {
  "$MEM_SYNC" update gc active >/dev/null
}

gc_mem_push() {
  body="${1:?json_string required}"
  ts=$(date +%s)
  # Validate JSON before writing
  echo "$body" | jq . >/dev/null || { echo "ERROR: Invalid JSON" >&2; exit 1; }
  echo "$body" | jq . > "$INBOX/gc_context_${ts}.json"
}

gc_mem_get() {
  "$MEM_SYNC" get | jq '.agents.gc? // {}'
}

case "${1:-}" in
  update) gc_mem_update ;;
  push)   gc_mem_push "${2:-"{}"}" ;;
  get)    gc_mem_get ;;
  *) echo "Usage: $(basename "$0") {update|push <json>|get}" >&2; exit 1 ;;
esac
EOF
chmod +x "$LUKA_SOT/tools/gc_memory_sync.sh"

# 2) CLS bridge (fixed: better error handling, millisecond timestamp)
cat > "$LUKA_SOT/agents/cls_bridge/cls_memory.py" <<'EOF'
import json, subprocess, time, os, sys
from pathlib import Path

SOT = Path(os.environ.get("LUKA_SOT", str(Path.home()/"02luka")))
MEM_TOOL = SOT / "tools" / "memory_sync.sh"
INBOX = SOT / "bridge" / "memory" / "inbox"

def _run(cmd):
    return subprocess.run(cmd, capture_output=True, text=True, check=True).stdout

def before_task():
    out = _run([str(MEM_TOOL), "get"])
    return json.loads(out)

def after_task(task_result: dict):
    try:
        _run([str(MEM_TOOL), "update", "cls", "active"])
    except Exception as e:
        print(f"WARN: memory_sync failed: {e}", file=sys.stderr)
    ts = int(time.time() * 1000)  # milliseconds for uniqueness
    INBOX.mkdir(parents=True, exist_ok=True)
    (INBOX / f"cls_result_{ts}.json").write_text(json.dumps(task_result, indent=2))

if __name__ == "__main__":
    print(json.dumps(before_task())[:200])
    after_task({"ok": True, "ts": int(time.time())})
    print("cls_memory: ok")
EOF

# 3) Metrics collector (fixed: ensure directory exists)
cat > "$LUKA_SOT/tools/memory_metrics.zsh" <<'EOF'
#!/usr/bin/env zsh
set -euo pipefail

export LUKA_SOT="${LUKA_SOT:-$HOME/02luka}"
CTX="$LUKA_SOT/shared_memory/context.json"
OUT="$LUKA_SOT/metrics/memory_usage.ndjson"

mkdir -p "$LUKA_SOT/metrics"

ts() { date -Iseconds; }

agents_count=$(jq '.agents|keys|length' "$CTX" 2>/dev/null || echo 0)
saved=$(jq '.token_usage.saved // 0' "$CTX" 2>/dev/null || echo 0)
total=$(jq '.token_usage.total // 0' "$CTX" 2>/dev/null || echo 0)

pct=0
[ "$total" -gt 0 ] && pct=$(( 100 * saved / total ))

printf '{"ts":"%s","agents":%s,"token_total":%s,"token_saved":%s,"saved_pct":%s}\n' \
  "$(ts)" "$agents_count" "$total" "$saved" "$pct" >> "$OUT"

echo "metrics: agents=$agents_count total=$total saved=$saved (${pct}%)"
EOF
chmod +x "$LUKA_SOT/tools/memory_metrics.zsh"

# 4) Health check (fixed: collect all failures)
cat > "$LUKA_SOT/tools/shared_memory_health.zsh" <<'EOF'
#!/usr/bin/env zsh
set -euo pipefail

errors=()
ok() { echo "✅ $1"; }
ng() { errors+=("$1"); echo "❌ $1"; }

export LUKA_SOT="${LUKA_SOT:-$HOME/02luka}"

test -d "$LUKA_SOT/shared_memory" && ok "shared_memory exists" || ng "shared_memory missing"
test -f "$LUKA_SOT/shared_memory/context.json" && ok "context.json exists" || ng "context.json missing"
jq . >/dev/null 2>&1 < "$LUKA_SOT/shared_memory/context.json" && ok "context.json valid JSON" || ng "context.json invalid"
test -x "$LUKA_SOT/tools/memory_sync.sh" && ok "memory_sync.sh executable" || ng "memory_sync.sh not executable"
test -x "$LUKA_SOT/tools/bridge_monitor.sh" && ok "bridge_monitor.sh executable" || ng "bridge_monitor.sh not executable"
launchctl list | grep -q com.02luka.memory.bridge && ok "LaunchAgent: bridge loaded" || ng "LaunchAgent: bridge not loaded"
test -x "$LUKA_SOT/tools/gc_memory_sync.sh" && ok "gc_memory_sync.sh executable" || ng "gc_memory_sync.sh not executable"
test -f "$LUKA_SOT/agents/cls_bridge/cls_memory.py" && ok "cls_memory.py exists" || ng "cls_memory.py missing"
launchctl list | grep -q com.02luka.memory.metrics && ok "LaunchAgent: metrics loaded" || ng "LaunchAgent: metrics not loaded"

if [ ${#errors[@]} -eq 0 ]; then
  ok "health passed"
  exit 0
else
  echo "Failures: ${errors[*]}"
  exit 1
fi
EOF
chmod +x "$LUKA_SOT/tools/shared_memory_health.zsh"

# 5) Metrics LaunchAgent (fixed: path expansion, ThrottleInterval)
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$HOME/Library/LaunchAgents/com.02luka.memory.metrics.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.02luka.memory.metrics</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/zsh</string>
    <string>-lc</string>
    <string>export LUKA_SOT="$HOME/02luka"; "$HOME/02luka/tools/memory_metrics.zsh"</string>
  </array>
  <key>StartInterval</key><integer>3600</integer>
  <key>RunAtLoad</key><true/>
  <key>ThrottleInterval</key><integer>30</integer>
  <key>StandardOutPath</key><string>~/02luka/logs/memory_metrics.out.log</string>
  <key>StandardErrorPath</key><string>~/02luka/logs/memory_metrics.err.log</string>
</dict></plist>
PLIST

launchctl unload "$HOME/Library/LaunchAgents/com.02luka.memory.metrics.plist" >/dev/null 2>&1 || true
launchctl load  "$HOME/Library/LaunchAgents/com.02luka.memory.metrics.plist"

echo "✅ Phase 2 installed: GC/CLS helpers, metrics, health."
