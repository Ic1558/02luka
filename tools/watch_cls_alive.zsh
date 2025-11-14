#!/usr/bin/env zsh

set -u

# ==============================
#  CLS Watcher (Smart Version)
# ==============================
# Monitors CLS/Cursor IDE activity via heartbeat file
# Waits for real heartbeat before alerting (prevents spam)
# Supports macOS notifications, auto-kill with cooldown, logging

# --- Path / State ---
STATE_DIR=${STATE_DIR:-"$HOME/02luka/state"}
mkdir -p "$STATE_DIR" 2>/dev/null || true
LAST_ACTIVITY_FILE=${LAST_ACTIVITY_FILE:-"$STATE_DIR/cls_last_activity"}

LOG_DIR=${LOG_DIR:-"$HOME/02luka/logs"}
mkdir -p "$LOG_DIR" 2>/dev/null || true
LOG_FILE=${LOG_FILE:-"$LOG_DIR/cls_watcher.log"}

# --- Behaviour Config (override ได้ด้วย env) ---
CHECK_INTERVAL=${CHECK_INTERVAL:-5}      # วินาที เช็คทุกกี่วิ
TIMEOUT=${TIMEOUT:-15}                   # วินาที เกินนี้ = ถือว่า freeze
ENABLE_NOTIFY=${ENABLE_NOTIFY:-1}        # 1 = ส่ง macOS notification
ENABLE_AUTO_KILL=${ENABLE_AUTO_KILL:-0}  # 1 = สั่ง kill อัตโนมัติ
ENABLE_LOG=${ENABLE_LOG:-1}              # 1 = เขียน log ลงไฟล์

# คำสั่ง kill เวลา timeout (ต้องเซ็ตเอง)
# ตัวอย่าง: export CLS_KILL_CMD='pkill -f "Cursor"'
CLS_KILL_CMD=${CLS_KILL_CMD:-""}

# กัน kill ถี่เกินไป
KILL_COOLDOWN=${KILL_COOLDOWN:-60}       # วินาทีระหว่าง kill แต่ละรอบ
_last_kill_time=0

# ภายใน: เคยเห็น heartbeat แล้วหรือยัง
_seen_heartbeat=0

log_msg() {
  (( ENABLE_LOG )) || return 0
  local ts
  ts=$(date +"%Y-%m-%d %H:%M:%S")
  echo "[$ts] $*" >> "$LOG_FILE"
}

notify_mac() {
  (( ENABLE_NOTIFY )) || return 0
  if command -v osascript >/dev/null 2>&1; then
    osascript <<EOF >/dev/null 2>&1
display notification "CLS seems frozen (> ${TIMEOUT}s since last activity)" with title "CLS Watcher" subtitle "Check Cursor / Codex IDE"
EOF
  fi
}

auto_kill_if_enabled() {
  (( ENABLE_AUTO_KILL )) || return 0
  [[ -z "$CLS_KILL_CMD" ]] && return 0
  
  local now
  now=$(date +%s)
  
  if (( now - _last_kill_time < KILL_COOLDOWN )); then
    echo "⏳ Auto-kill cooldown active (last kill $(( now - _last_kill_time ))s ago)"
    return 0
  fi
  
  echo "⚠️  Auto-kill running: $CLS_KILL_CMD"
  log_msg "AUTO_KILL: running '$CLS_KILL_CMD'"
  _last_kill_time=$now
  
  zsh -c "$CLS_KILL_CMD" || {
    echo "⚠️  Auto-kill command exited with non-zero status."
    log_msg "AUTO_KILL: command failed (non-zero exit)"
  }
}

print_header() {
  echo "🔍 CLS Watcher started (interval=${CHECK_INTERVAL}s, timeout=${TIMEOUT}s)"
  echo "    LAST_ACTIVITY_FILE=${LAST_ACTIVITY_FILE}"
  echo "    LOG_FILE=${LOG_FILE}"
  echo "    ENABLE_NOTIFY=${ENABLE_NOTIFY}  ENABLE_AUTO_KILL=${ENABLE_AUTO_KILL}  ENABLE_LOG=${ENABLE_LOG}"
  [[ -n "$CLS_KILL_CMD" ]] && echo "    CLS_KILL_CMD=${CLS_KILL_CMD}"
  echo "Press Ctrl+C to stop."
  echo ""
  log_msg "WATCHER_START interval=${CHECK_INTERVAL}s timeout=${TIMEOUT}s"
}

print_header

while true; do
  now=$(date +%s)
  
  if [[ ! -f "$LAST_ACTIVITY_FILE" ]]; then
    # ยังไม่มี heartbeat จาก CLS
    echo "⏳ Waiting for first CLS heartbeat... (no $LAST_ACTIVITY_FILE yet)"
    log_msg "WAITING_FOR_HEARTBEAT"
    sleep "$CHECK_INTERVAL"
    continue
  fi
  
  last=$(cat "$LAST_ACTIVITY_FILE" 2>/dev/null || echo "$now")
  
  # ถ้าค่าในไฟล์ไม่ใช่ตัวเลข ใช้ now แทน
  if ! [[ "$last" == <-> ]]; then
    last="$now"
  fi
  
  diff=$(( now - last ))
  
  if (( diff < 0 )); then
    # เวลาในไฟล์ล้ำอนาคต (เช่น clock เปลี่ยน) → reset
    echo "⚠️  Detected future timestamp in LAST_ACTIVITY_FILE, resetting baseline."
    log_msg "FUTURE_TS_RESET diff=${diff}"
    diff=0
  fi
  
  if (( diff <= TIMEOUT )); then
    _seen_heartbeat=1
    echo "✅ CLS alive — last activity: ${diff}s ago"
    log_msg "ALIVE diff=${diff}s"
  else
    # เฉพาะกรณีที่เคยมี heartbeat แล้ว ถึงจะถือว่า freeze
    if (( _seen_heartbeat == 0 )); then
      echo "⏳ Still waiting for valid CLS activity (diff=${diff}s, but no prior heartbeat mark)"
      log_msg "WAITING_FIRST_VALID diff=${diff}s"
    else
      echo ""
      echo "❌  ALERT: CLS seems frozen or not responding (> ${TIMEOUT}s)"
      echo "❌  Check Cursor/Codex IDE — may require restart"
      echo ""
      log_msg "FREEZE_DETECTED diff=${diff}s"
      notify_mac
      auto_kill_if_enabled
    fi
  fi
  
  sleep "$CHECK_INTERVAL"
done
