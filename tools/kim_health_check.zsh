#!/usr/bin/env zsh
set -euo pipefail

HOST="${REDIS_HOST:-127.0.0.1}"
PORT="${REDIS_PORT:-6379}"
PASSWORD="${REDIS_PASSWORD:-}" 
CHANNEL="${REDIS_CHANNEL_IN:-gg:nlp}"

function check_redis() {
  local args=( -h "$HOST" -p "$PORT" )
  if [[ -n "$PASSWORD" ]]; then
    args+=( -a "$PASSWORD" )
  fi
  local resp
  if resp=$(redis-cli "${args[@]}" PING 2>/dev/null); then
    echo "✅ Redis reachable (${resp})"
  else
    echo "❌ Redis check failed"
    return 1
  fi
}

function check_dispatcher_process() {
  if pgrep -f "nlp_command_dispatcher.py" >/dev/null 2>&1; then
    echo "✅ Dispatcher running"
  else
    echo "⚠️ Dispatcher not running"
  fi
}

function check_profile_store() {
  local store_path="${KIM_PROFILE_STORE:-$HOME/02luka/core/nlp/kim_session_profiles.json}"
  if [[ -f "$store_path" ]]; then
    echo "✅ Profile store present at $store_path"
  else
    echo "⚠️ Profile store missing ($store_path)"
  fi
}

function check_launchagent() {
  local plist="$HOME/Library/LaunchAgents/com.02luka.nlp-dispatcher.plist"
  if [[ -f "$plist" ]]; then
    echo "✅ LaunchAgent installed ($plist)"
  else
    echo "⚠️ LaunchAgent not found ($plist)"
  fi
}

check_redis || true
check_dispatcher_process
check_profile_store
check_launchagent

echo "Health check complete for channel $CHANNEL"
