#!/usr/bin/env zsh
set -euo pipefail

REPO="$HOME/02luka"
INBOX="$REPO/bridge/inbox/ATG"
PROCESSED="$REPO/bridge/processed/ATG"
OUTBOX="$REPO/bridge/outbox/ATG"
LOG_DIR="$REPO/g/logs/atg_runner"
TELEMETRY="$REPO/g/telemetry/atg_runner.jsonl"

RUNNER="$REPO/tools/atg_runner_daemon.zsh"
PLIST_DIR="$HOME/Library/LaunchAgents"
PLIST="$PLIST_DIR/com.02luka.atg_runner.plist"

mkdir -p "$INBOX" "$PROCESSED" "$OUTBOX" "$LOG_DIR" "$REPO/g/telemetry" "$PLIST_DIR"

cat > "$RUNNER" <<'DAEMON'
#!/usr/bin/env zsh
set -euo pipefail

REPO="${REPO:-$HOME/02luka}"
INBOX="${INBOX:-$REPO/bridge/inbox/ATG}"
PROCESSED="${PROCESSED:-$REPO/bridge/processed/ATG}"
OUTBOX="${OUTBOX:-$REPO/bridge/outbox/ATG}"
LOG_DIR="${LOG_DIR:-$REPO/g/logs/atg_runner}"
TELEMETRY="${TELEMETRY:-$REPO/g/telemetry/atg_runner.jsonl}"

POLL_SECONDS="${ATG_POLL_SECONDS:-2}"
LOCK_FILE="${ATG_LOCK_FILE:-$REPO/g/state/atg_runner.lock}"
mkdir -p "$LOG_DIR" "$(dirname "$TELEMETRY")" "$(dirname "$LOCK_FILE")" "$PROCESSED" "$OUTBOX"

_ts_utc(){ date -u +"%Y-%m-%dT%H:%M:%SZ"; }
_json_escape(){ python3 - <<'PY' "$1"
import json,sys
print(json.dumps(sys.argv[1])[1:-1])
PY
}
_log_json(){
  local ts="$(_ts_utc)"
  local level="$1"; shift
  local msg="$1"; shift || true
  local extra="${1:-}"
  local jmsg="$(_json_escape "$msg")"
  echo "{\"ts\":\"$ts\",\"level\":\"$level\",\"msg\":\"$jmsg\"${extra}}" >> "$TELEMETRY"
}

_is_dangerous(){
  local f="$1"
  if grep -nE '(^|[[:space:]])sudo([[:space:]]|$)' "$f" >/dev/null 2>&1; then return 0; fi
  if grep -nE 'rm[[:space:]]+-rf[[:space:]]+(/($|[[:space:]])|~($|/))' "$f" >/dev/null 2>&1; then return 0; fi
  return 1
}

_has_ticket_header(){
  local f="$1"
  head -n 5 "$f" | grep -qE '^# ATG_BATCH_TICKET v1$'
}

_process_one(){
  local src="$1"
  local base="$(basename "$src")"
  local id="${base%.zsh}"
  local work="$INBOX/.work_${base}.$$"
  local started="$(_ts_utc)"
  local log="$LOG_DIR/${id}_$(date -u +%Y%m%dT%H%M%SZ).log"

  mv "$src" "$work"

  if ! _has_ticket_header "$work"; then
    _log_json "WARN" "Rejected (missing ticket header): $base" ",\"file\":\"$base\""
    mv "$work" "$PROCESSED/${base}.rejected"
    return 0
  fi

  if _is_dangerous "$work"; then
    _log_json "ERROR" "Rejected (dangerous pattern): $base" ",\"file\":\"$base\""
    mv "$work" "$PROCESSED/${base}.danger"
    return 0
  fi

  _log_json "INFO" "Executing batch: $base" ",\"file\":\"$base\""
  {
    echo "=== ATG RUNNER ==="
    echo "ts_utc_start=$started"
    echo "file=$base"
    echo "repo=$REPO"
    echo "------------------"
    echo "[RUN] zsh -eu \"$work\""
    echo
  } > "$log"

  local exit_code=0
  ( cd "$REPO" && zsh -eu "$work" ) >> "$log" 2>&1 || exit_code=$?

  local ended="$(_ts_utc)"
  local safe_id="$(echo "$id" | tr -cd 'A-Za-z0-9._-')"

  local result="$OUTBOX/${safe_id}.result.json"
  cat > "$result" <<JSON
{"ts_start":"$started","ts_end":"$ended","file":"$base","exit_code":$exit_code,"log":"$log"}
JSON

  if [[ "$exit_code" -eq 0 ]]; then
    mv "$work" "$PROCESSED/${base}.done"
    _log_json "INFO" "Done: $base" ",\"file\":\"$base\",\"exit_code\":$exit_code"
  else
    mv "$work" "$PROCESSED/${base}.failed"
    _log_json "ERROR" "Failed: $base" ",\"file\":\"$base\",\"exit_code\":$exit_code"
  fi

  return 0
}

_main_loop(){
  _log_json "INFO" "ATG runner started" ""
  while true; do
    if ( set -o noclobber; echo "$$" > "$LOCK_FILE" ) 2>/dev/null; then
      trap 'rm -f "$LOCK_FILE"' EXIT INT TERM
      break
    else
      sleep 1
    fi
  done

  while true; do
    local f=""
    for f in "$INBOX"/batch_*.zsh(N); do
      _process_one "$f"
      break
    done
    sleep "$POLL_SECONDS"
  done
}

_main_loop
DAEMON

chmod +x "$RUNNER"

cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.02luka.atg_runner</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/env</string>
    <string>zsh</string>
    <string>$RUNNER</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>$HOME/02luka/g/logs/atg_runner/launchd.stdout.log</string>
  <key>StandardErrorPath</key><string>$HOME/02luka/g/logs/atg_runner/launchd.stderr.log</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>REPO</key><string>$HOME/02luka</string>
  </dict>
</dict>
</plist>
PLIST

launchctl unload "$PLIST" >/dev/null 2>&1 || true
launchctl load "$PLIST"

echo "✅ ATG Runner installed + started"
echo "   Inbox:      $INBOX"
echo "   Processed:  $PROCESSED"
echo "   Outbox:     $OUTBOX"
echo "   Telemetry:  $TELEMETRY"
echo "   Runner:     $RUNNER"
echo "   LaunchAgent:$PLIST"
