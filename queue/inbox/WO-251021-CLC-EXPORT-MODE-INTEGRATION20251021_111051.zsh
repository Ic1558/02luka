#!/usr/bin/env zsh
set -euo pipefail

# ================================
# WO: CLC Export-Mode Integration (Phase 7.6)
# ID : WO-251021-CLC-EXPORT-MODE-INTEGRATION
# Desc: Add state-based export toggle + wrapper + optional Redis listener + metrics
# Safe: Non-destructive; backups kept; no behavior changes unless wrapper used
# ================================

# --- 0) Locate repo root
CANDIDATES=(
  "$HOME/Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/My Drive/02luka/02luka-repo"
  "/workspaces/02luka-repo"
)
ROOT=""
for d in "${CANDIDATES[@]}"; do [[ -d "$d" ]] && ROOT="$d" && break; done
[[ -z "$ROOT" ]] && { echo "Repo root not found"; exit 1; }

TOOLS="$ROOT/g/tools"
SERV="$TOOLS/services"
STATE_DIR="$ROOT/g/state"
METRICS_DIR="$ROOT/g/metrics"
LOG_DIR="$ROOT/g/logs"
REP_DIR="$ROOT/g/reports"
mkdir -p "$SERV" "$STATE_DIR" "$METRICS_DIR" "$LOG_DIR"

# --- 1) State file & CLI (get/set) -----------------------------------------
STATE_FILE="$STATE_DIR/clc_export_mode.env"
cat > "$SERV/clc_export_mode_state.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
STATE_FILE="${STATE_FILE:-$(dirname "$0")/../../state/clc_export_mode.env}"

ensure_file() {
  if [[ ! -f "$STATE_FILE" ]]; then
    mkdir -p "$(dirname "$STATE_FILE")"
    cat > "$STATE_FILE" <<EOF
MODE=off
LOCAL_DIR=
UPDATED_AT=$(date -u +%FT%TZ)
EOF
  fi
}

cmd="${1:-get}"
case "$cmd" in
  get)
    ensure_file
    cat "$STATE_FILE"
    ;;
  set)
    mode="${2:-off}"
    local_dir="${3:-}"
    case "$mode" in off|local|drive) ;; *) echo "invalid mode"; exit 2;; esac
    ensure_file
    {
      echo "MODE=$mode"
      echo "LOCAL_DIR=$local_dir"
      echo "UPDATED_AT=$(date -u +%FT%TZ)"
    } > "$STATE_FILE.tmp"
    mv -f "$STATE_FILE.tmp" "$STATE_FILE"
    echo "OK set MODE=$mode LOCAL_DIR=$local_dir"
    ;;
  *)
    echo "usage: $0 get|set <off|local|drive> [LOCAL_DIR]"; exit 2;;
esac
SH
chmod +x "$SERV/clc_export_mode_state.sh"

# --- 2) Wrapper runner that applies state to env and calls sync.cjs ----------
cat > "$SERV/clc_sync_wrapper.zsh" <<'ZSH_W'
#!/usr/bin/env zsh
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
STATE_FILE="$ROOT_DIR/g/state/clc_export_mode.env"
SYNC="$ROOT_DIR/knowledge/sync.cjs"

# defaults
MODE="drive"
LOCAL_DIR=""

# read state if exists
if [[ -f "$STATE_FILE" ]]; then
  source "$STATE_FILE"
  MODE="${MODE:-drive}"
  LOCAL_DIR="${LOCAL_DIR:-}"
fi

case "$MODE" in
  off)
    KNOW_EXPORT_MODE=off node "$SYNC"
    ;;
  local)
    KNOW_EXPORT_MODE=local KNOW_EXPORT_DIR="${LOCAL_DIR:-$ROOT_DIR/.exports_local}" node "$SYNC"
    ;;
  drive)
    KNOW_EXPORT_MODE=drive node "$SYNC"
    ;;
  *)
    echo "Invalid MODE in state: $MODE"; exit 2;;
esac
ZSH_W
chmod +x "$SERV/clc_sync_wrapper.zsh"

# --- 3) Optional Redis listener (gg:clc:export_mode) ------------------------
# Message formats (JSON):
#   {"mode":"off"}
#   {"mode":"local","dir":"/path"}
#   {"mode":"drive"}
cat > "$SERV/redis_export_mode_listener.cjs" <<'JS'
const { createClient } = require('redis');
const { writeFileSync, mkdirSync } = require('fs');
const { dirname } = require('path');

const CHAN = process.env.CLC_EXPORT_MODE_CHANNEL || 'gg:clc:export_mode';
const STATE_FILE = process.env.CLC_EXPORT_STATE_FILE || __dirname + '/../../state/clc_export_mode.env';
const REDIS_URL = process.env.REDIS_URL || 'redis://localhost:6379';

function writeState(mode, dir) {
  mkdirSync(dirname(STATE_FILE), { recursive: true });
  const stamp = new Date().toISOString();
  let body = `MODE=${mode}\nLOCAL_DIR=${dir||''}\nUPDATED_AT=${stamp}\n`;
  writeFileSync(STATE_FILE + '.tmp', body);
  require('fs').renameSync(STATE_FILE + '.tmp', STATE_FILE);
  console.log(`[state] ${STATE_FILE} <- MODE=${mode} LOCAL_DIR=${dir||''}`);
}

(async () => {
  const sub = createClient({ url: REDIS_URL });
  sub.on('error', (e) => console.error('redis error', e));
  await sub.connect();
  console.log(`[sub] ${REDIS_URL} # ${CHAN}`);
  await sub.subscribe(CHAN, (msg) => {
    try {
      const m = JSON.parse(msg);
      if (!m.mode) return;
      const mode = String(m.mode);
      if (!['off','local','drive'].includes(mode)) return;
      writeState(mode, m.dir);
    } catch(e) {
      console.error('bad message', msg, e);
    }
  });
})();
JS

# --- 4) Metrics: current mode + last benchmark snapshot ---------------------
cat > "$SERV/export_mode_metrics.zsh" <<'ZSH_M'
#!/usr/bin/env zsh
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
STATE_FILE="$ROOT_DIR/g/state/clc_export_mode.env"
METRICS="$ROOT_DIR/g/metrics/clc_export_mode.json"
BENCH="$ROOT_DIR/g/reports/251021_drive_bench.md"

MODE="unknown"; LOCAL_DIR=""; UPDATED_AT=""
[[ -f "$STATE_FILE" ]] && source "$STATE_FILE"

# Parse last line durations from bench (if exists)
DUR_OFF=""; DUR_LOCAL=""; DUR_DRIVE=""
if [[ -f "$BENCH" ]]; then
  DUR_OFF="$(grep -E '^\| off' "$BENCH"    | awk -F'|' '{print $4}' | xargs)"
  DUR_LOCAL="$(grep -E '^\| local' "$BENCH"| awk -F'|' '{print $4}' | xargs)"
  DUR_DRIVE="$(grep -E '^\| drive' "$BENCH"| awk -F'|' '{print $4}' | xargs)"
fi

cat > "$METRICS.tmp" <<JSON
{
  "updated_at": "$(date -u +%FT%TZ)",
  "mode": "${MODE:-unknown}",
  "local_dir": "${LOCAL_DIR:-}",
  "state_updated_at": "${UPDATED_AT:-}",
  "bench_seconds": {
    "off": "${DUR_OFF:-}",
    "local": "${DUR_LOCAL:-}",
    "drive": "${DUR_DRIVE:-}"
  }
}
JSON
mv -f "$METRICS.tmp" "$METRICS"
echo "Metrics -> $METRICS"
ZSH_M
chmod +x "$SERV/export_mode_metrics.zsh"

# --- 5) (Optional) Switch LaunchAgents to call the wrapper ------------------
LA_DIR="$HOME/Library/LaunchAgents"
mkdir -p "$LA_DIR"

# dev: every 10 min using wrapper (state controls behavior; default off)
cat > "$LA_DIR/com.02luka.clc.sync.dev.plist" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.02luka.clc.sync.dev</string>
  <key>ProgramArguments</key>
  <array><string>/bin/zsh</string><string>-lc</string><string>"$SERV/clc_sync_wrapper.zsh"</string></array>
  <key>StartInterval</key><integer>600</integer>
  <key>StandardOutPath</key><string>$LOG_DIR/clc.dev.out.log</string>
  <key>StandardErrorPath</key><string>$LOG_DIR/clc.dev.err.log</string>
  <key>RunAtLoad</key><true/>
</dict></plist>
PL

# nightly: 02:00 via wrapper (state usually set to drive by scheduler or GG)
cat > "$LA_DIR/com.02luka.clc.sync.nightly.plist" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.02luka.clc.sync.nightly</string>
  <key>ProgramArguments</key>
  <array><string>/bin/zsh</string><string>-lc</string><string>"$SERV/clc_sync_wrapper.zsh"</string></array>
  <key>StartCalendarInterval</key><dict><key>Hour</key><integer>2</integer><key>Minute</key><integer>0</integer></dict>
  <key>StandardOutPath</key><string>$LOG_DIR/clc.nightly.out.log</string>
  <key>StandardErrorPath</key><string>$LOG_DIR/clc.nightly.err.log</string>
</dict></plist>
PL

# --- 6) Usage notes for operators ------------------------------------------
cat > "$REP_DIR/251021_phase7_6_export_mode_integration.md" <<'MD'
# Phase 7.6 — CLC Export-Mode Integration

## Toggle the mode
```bash
g/tools/services/clc_export_mode_state.sh get
g/tools/services/clc_export_mode_state.sh set off
g/tools/services/clc_export_mode_state.sh set local "$HOME/02luka/tmp_exports"
g/tools/services/clc_export_mode_state.sh set drive
```

## Run sync via wrapper (respects state)
```bash
g/tools/services/clc_sync_wrapper.zsh
```

## Optional Redis listener
- Channel: gg:clc:export_mode
- Messages:
  - {"mode":"off"}
  - {"mode":"local","dir":"/path"}
  - {"mode":"drive"}
- Start:
```bash
REDIS_URL="redis://localhost:6379" node g/tools/services/redis_export_mode_listener.cjs
```

## Metrics (for dashboard)
```bash
g/tools/services/export_mode_metrics.zsh
# -> g/metrics/clc_export_mode.json
```

## LaunchAgents (macOS)
```bash
launchctl load  -w ~/Library/LaunchAgents/com.02luka.clc.sync.dev.plist
launchctl load  -w ~/Library/LaunchAgents/com.02luka.clc.sync.nightly.plist
# unload with: launchctl unload -w <plist>
```
MD

echo "OK — Phase 7.6 integration files written."
