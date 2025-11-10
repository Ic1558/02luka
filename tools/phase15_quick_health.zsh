#!/usr/bin/env zsh
# Phase 15 Quick Health Check
# Quick diagnostic commands for MCP Bridge and MLS services

# Note: In JSON mode, we disable errexit to guarantee output
set -uo pipefail

# ============================================================
# Configuration
# ============================================================
LUKA_HOME="${HOME}/02luka"
USER_ID=$(id -u)
CURRENT_USER=$(whoami)
SERVICE_MCP_BRIDGE="com.02luka.gg.mcp-bridge"
PLIST_MCP_BRIDGE="${HOME}/Library/LaunchAgents/${SERVICE_MCP_BRIDGE}.plist"
TODAY=$(TZ=Asia/Bangkok date +%Y-%m-%d)
TS_ICT=$(TZ=Asia/Bangkok date '+%Y-%m-%dT%H:%M:%S%z')
LEDGER_FILE="${LUKA_HOME}/mls/ledger/${TODAY}.jsonl"
STREAK_FILE="${LUKA_HOME}/mls/status/mls_validation_streak.json"

# Flags
JSON_MODE=false
RESTART_BRIDGE=false
TAIL_LOG=false
FIX_LEDGER=false

# Health status
MCP_OK=1
LEDGER_OK=1

# Error trap for JSON mode - guarantee output on failure
emit_error_json() {
  if [[ "$JSON_MODE" == "true" ]]; then
    local error_msg="${1:-unknown error}"
    local ts=$(TZ=Asia/Bangkok date '+%Y-%m-%dT%H:%M:%S%z' 2>/dev/null || date -u +%FT%TZ)
    echo "{\"ok\":false,\"error\":\"${error_msg}\",\"ts_ict\":\"${ts}\"}"
  fi
}

# Trap errors in JSON mode
trap 'emit_error_json "script failed unexpectedly"' ERR EXIT

# ============================================================
# Parse arguments
# ============================================================
while [[ $# -gt 0 ]]; do
  case $1 in
    --json)
      JSON_MODE=true
      shift
      ;;
    --restart-bridge)
      RESTART_BRIDGE=true
      shift
      ;;
    --tail-log)
      TAIL_LOG=true
      shift
      ;;
    --fix-ledger-today)
      FIX_LEDGER=true
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --json              Output results as JSON"
      echo "  --restart-bridge    Restart MCP bridge service"
      echo "  --tail-log          Stream live logs"
      echo "  --fix-ledger-today  Fix today's ledger file"
      echo "  -h, --help          Show this help"
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# ============================================================
# Helper functions
# ============================================================
log_info() {
  if [[ "$JSON_MODE" == "false" ]]; then
    echo "$@"
  fi
}

log_json() {
  if [[ "$JSON_MODE" == "true" ]]; then
    echo "$@"
  fi
}

# ============================================================
# Quick Actions
# ============================================================
if [[ "$RESTART_BRIDGE" == "true" ]]; then
  log_info "🔄 Restarting MCP Bridge..."
  launchctl bootout "gui/${USER_ID}/${SERVICE_MCP_BRIDGE}" 2>/dev/null || true
  sleep 1
  launchctl bootstrap "gui/${USER_ID}" "${PLIST_MCP_BRIDGE}" 2>/dev/null || true
  sleep 1
  launchctl kickstart -k "gui/${USER_ID}/${SERVICE_MCP_BRIDGE}" 2>/dev/null || true
  log_info "✅ Restart complete. Re-checking status..."
  sleep 2
fi

if [[ "$TAIL_LOG" == "true" ]]; then
  log_info "📋 Streaming live logs (Ctrl+C to stop)..."
  log stream --predicate 'subsystem CONTAINS "02luka" OR process == "mcp-bridge"' --info
  exit 0
fi

if [[ "$FIX_LEDGER" == "true" ]]; then
  log_info "🔧 Fixing today's ledger file..."
  if [[ -f "${LEDGER_FILE}" ]]; then
    # Normalize JSONL (ensure one JSON per line, no trailing commas)
    if command -v jq >/dev/null 2>&1; then
      jq -c . "${LEDGER_FILE}" > "${LEDGER_FILE}.tmp" 2>/dev/null && mv "${LEDGER_FILE}.tmp" "${LEDGER_FILE}"
      log_info "✅ Ledger file normalized"
    else
      log_info "⚠️  jq not found - cannot normalize"
    fi
  else
    log_info "⚠️  Ledger file not found: ${LEDGER_FILE}"
  fi
fi

# ============================================================
# MCP Bridge Service Check
# ============================================================
check_mcp_bridge() {
  MCP_OK=1
  local pid=""
  local last_exit="unknown"
  local program=""
  local script_path=""
  local keep_alive="false"
  local run_at_load="false"
  local plist_ok=true
  local label_ok=true
  local program_ok=true
  local permissions_ok=true
  local owner_ok=true

  # Skip launchctl checks on non-macOS systems (but still emit JSON below)
  local OS_NAME="$(uname)"
  if [[ "${OS_NAME}" != "Darwin" ]]; then
    MCP_OK=1
    pid=""
    last_exit="unknown"
    program=""
    script_path=""
    keep_alive="false"
    run_at_load="false"
    plist_ok=true
    label_ok=true
    program_ok=true
    permissions_ok=true
    owner_ok=true
  fi

  if [[ "${OS_NAME}" == "Darwin" ]]; then
    # 1. Service Status & PID
    if launchctl list | grep -q "${SERVICE_MCP_BRIDGE}"; then
      pid=$(launchctl list | grep "${SERVICE_MCP_BRIDGE}" | awk '{print $1}')
      if [[ "$pid" == "-" ]]; then
        pid=""
      fi
    else
      MCP_OK=0
      plist_ok=false
    fi
  fi

  if [[ "${OS_NAME}" == "Darwin" ]]; then
    # 2. Service Details
    if launchctl print "gui/${USER_ID}/${SERVICE_MCP_BRIDGE}" >/dev/null 2>&1; then
      last_exit=$(launchctl print "gui/${USER_ID}/${SERVICE_MCP_BRIDGE}" 2>/dev/null | grep "LastExitStatus" | awk '{print $2}' || echo "unknown")
      if [[ "$last_exit" != "0" ]] && [[ "$last_exit" != "unknown" ]]; then
        MCP_OK=0
      fi
    fi
  fi

  if [[ "${OS_NAME}" == "Darwin" ]]; then
    # 3. Plist Validation
    if [[ ! -f "${PLIST_MCP_BRIDGE}" ]]; then
      MCP_OK=0
      plist_ok=false
    else
      # Check syntax
      if ! plutil -lint "${PLIST_MCP_BRIDGE}" >/dev/null 2>&1; then
        MCP_OK=0
        plist_ok=false
      fi

      # Check Label
      local label=$(grep -A 1 "<key>Label</key>" "${PLIST_MCP_BRIDGE}" | grep "<string>" | sed 's/.*<string>\(.*\)<\/string>.*/\1/' || echo "")
      if [[ "$label" != "${SERVICE_MCP_BRIDGE}" ]]; then
        MCP_OK=0
        label_ok=false
      fi

      # Check ProgramArguments
      if grep -q "ProgramArguments" "${PLIST_MCP_BRIDGE}" && command -v jq >/dev/null 2>&1; then
        local args_json=$(plutil -convert json -o - "${PLIST_MCP_BRIDGE}" 2>/dev/null | jq -r '.ProgramArguments[]?' 2>/dev/null)
        if [[ -n "$args_json" ]]; then
          local arg_count=0
          while IFS= read -r arg; do
            arg=$(echo "$arg" | sed "s|\$HOME|${HOME}|g")
            if [[ $arg_count -eq 0 ]]; then
              program="$arg"
              if [[ ! -f "$arg" ]] && ! command -v "$arg" >/dev/null 2>&1; then
                MCP_OK=0
                program_ok=false
              fi
            elif [[ "$arg" != "-lc" ]] && [[ "$arg" != "-c" ]] && echo "$arg" | grep -qE "^${HOME}|^/"; then
              script_path="$arg"
              if [[ ! -f "$arg" ]]; then
                # Script not found - but don't fail if service is running
                if [[ -z "$pid" ]]; then
                  MCP_OK=0
                  program_ok=false
                fi
              fi
              break
            fi
            arg_count=$((arg_count + 1))
          done <<< "$args_json"
        fi
      fi

      # Check KeepAlive
      if grep -q "<key>KeepAlive</key>" "${PLIST_MCP_BRIDGE}"; then
        keep_alive=$(grep -A 1 "<key>KeepAlive</key>" "${PLIST_MCP_BRIDGE}" | grep -E "<true/>|<false/>" | grep -q "<true/>" && echo "true" || echo "false")
      fi

      # Check RunAtLoad
      if grep -q "<key>RunAtLoad</key>" "${PLIST_MCP_BRIDGE}"; then
        run_at_load=$(grep -A 1 "<key>RunAtLoad</key>" "${PLIST_MCP_BRIDGE}" | grep -E "<true/>|<false/>" | grep -q "<true/>" && echo "true" || echo "false")
      fi

      # Check permissions (should be 600) - warning only, not critical
      local perms=$(stat -f %Lp "${PLIST_MCP_BRIDGE}" 2>/dev/null || echo "0")
      if [[ "$perms" -gt 600 ]]; then
        # Don't fail if service is running - just warn
        if [[ -z "$pid" ]]; then
          MCP_OK=0
        fi
        permissions_ok=false
      fi

      # Check owner (should be current user) - warning only, not critical
      local owner=$(stat -f %Su "${PLIST_MCP_BRIDGE}" 2>/dev/null || echo "")
      if [[ "$owner" != "$CURRENT_USER" ]]; then
        # Don't fail if service is running - just warn
        if [[ -z "$pid" ]]; then
          MCP_OK=0
        fi
        owner_ok=false
      fi
    fi
  fi

  # Output
  if [[ "$JSON_MODE" == "true" ]]; then
    # Sanitize boolean values for --argjson
    local keep_alive_json="false"
    [[ "$keep_alive" == "true" ]] && keep_alive_json="true"

    local run_at_load_json="false"
    [[ "$run_at_load" == "true" ]] && run_at_load_json="true"

    local ok_json="false"
    [[ $MCP_OK -eq 1 ]] && ok_json="true"

    jq -n \
      --arg label "${SERVICE_MCP_BRIDGE}" \
      --arg pid "$pid" \
      --arg last_exit "$last_exit" \
      --arg program "$program" \
      --arg script_path "$script_path" \
      --argjson keep_alive "$keep_alive_json" \
      --argjson run_at_load "$run_at_load_json" \
      --argjson ok "$ok_json" \
      '{
        label: $label,
        pid: (if $pid == "" then null else ($pid | tonumber) end),
        last_exit_status: (if $last_exit == "unknown" then null else ($last_exit | tonumber) end),
        program: $program,
        script_path: $script_path,
        keep_alive: $keep_alive,
        run_at_load: $run_at_load,
        ok: $ok
      }' 2>/dev/null || echo '{"ok":false,"error":"jq failed in check_mcp_bridge"}'
  else
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "📡 MCP Bridge: ${SERVICE_MCP_BRIDGE}"
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info ""
    log_info "1️⃣  Service Status & PID:"
    if [[ -n "$pid" ]]; then
      log_info "   ✅ Service loaded (PID: ${pid})"
    else
      log_info "   ❌ Service not found in launchctl list"
    fi
    log_info ""
    log_info "2️⃣  Service Details:"
    log_info "   LastExitStatus: ${last_exit}"
    if [[ "$last_exit" != "0" ]] && [[ "$last_exit" != "unknown" ]]; then
      log_info "   ⚠️  Non-zero exit status (may indicate crash)"
    fi
    log_info ""
    log_info "3️⃣  Plist Validation:"
    if [[ "$plist_ok" == "true" ]]; then
      log_info "   ✅ Plist syntax valid"
    else
      log_info "   ❌ Plist syntax invalid or not found"
    fi
    if [[ "$label_ok" == "true" ]]; then
      log_info "   ✅ Label matches: ${SERVICE_MCP_BRIDGE}"
    else
      log_info "   ❌ Label mismatch"
    fi
    if [[ "$program_ok" == "true" ]]; then
      log_info "   ✅ Program/script exists"
      [[ -n "$program" ]] && log_info "      Executable: ${program}"
      [[ -n "$script_path" ]] && log_info "      Script: ${script_path}"
    else
      log_info "   ❌ Program/script not found"
    fi
    if [[ "$permissions_ok" == "true" ]]; then
      log_info "   ✅ Permissions: $(stat -f %Lp "${PLIST_MCP_BRIDGE}" 2>/dev/null || echo "unknown")"
    else
      log_info "   ⚠️  Permissions insecure: $(stat -f %Lp "${PLIST_MCP_BRIDGE}" 2>/dev/null || echo "unknown") (expect 600)"
    fi
    if [[ "$owner_ok" == "true" ]]; then
      log_info "   ✅ Owner: $(stat -f %Su "${PLIST_MCP_BRIDGE}" 2>/dev/null || echo "unknown")"
    else
      log_info "   ⚠️  Owner mismatch: $(stat -f %Su "${PLIST_MCP_BRIDGE}" 2>/dev/null || echo "unknown") (expect ${CURRENT_USER})"
    fi
    log_info "   ℹ️  KeepAlive: ${keep_alive}"
    log_info "   ℹ️  RunAtLoad: ${run_at_load}"
  fi
}

# ============================================================
# MLS Streak & Ledger Check
# ============================================================
check_mls() {
  LEDGER_OK=1
  local streak_exists=false
  local streak=0
  local ledger_exists=false
  local ledger_jsonl_ok=false
  local entries_today=0

  # 1. Streak file
  if [[ -f "${STREAK_FILE}" ]]; then
    streak_exists=true
    if command -v jq >/dev/null 2>&1; then
      streak=$(jq -r '.success_streak // 0' "${STREAK_FILE}" 2>/dev/null || echo "0")
    fi
  fi

  # 2. Ledger file
  if [[ -f "${LEDGER_FILE}" ]]; then
    ledger_exists=true
    # Check JSONL format
    if command -v jq >/dev/null 2>&1; then
      if tail -n 3 "${LEDGER_FILE}" | jq -c . >/dev/null 2>&1; then
        ledger_jsonl_ok=true
        entries_today=$(wc -l < "${LEDGER_FILE}" 2>/dev/null || echo "0")
      else
        LEDGER_OK=0
      fi
    fi
  fi

  # Output
  if [[ "$JSON_MODE" == "true" ]]; then
    # Ensure numeric values are valid
    local streak_num=$((streak + 0))
    local entries_num=$((entries_today + 0))

    # Sanitize boolean values for --argjson
    local streak_exists_json="false"
    [[ "$streak_exists" == "true" ]] && streak_exists_json="true"

    local ledger_exists_json="false"
    [[ "$ledger_exists" == "true" ]] && ledger_exists_json="true"

    local ledger_jsonl_ok_json="false"
    [[ "$ledger_jsonl_ok" == "true" ]] && ledger_jsonl_ok_json="true"

    local ok_json="false"
    [[ $LEDGER_OK -eq 1 ]] && ok_json="true"

    jq -n \
      --argjson streak_exists "$streak_exists_json" \
      --argjson streak "$streak_num" \
      --arg ledger_path "${LEDGER_FILE}" \
      --argjson ledger_exists "$ledger_exists_json" \
      --argjson ledger_jsonl_ok "$ledger_jsonl_ok_json" \
      --argjson entries_today "$entries_num" \
      --argjson ok "$ok_json" \
      '{
        streak_file_exists: $streak_exists,
        streak: $streak,
        ledger_today_path: $ledger_path,
        ledger_exists: $ledger_exists,
        ledger_jsonl_ok: $ledger_jsonl_ok,
        entries_today: $entries_today,
        ok: $ok
      }' 2>/dev/null || echo '{"ok":false,"error":"jq failed in check_mls"}'
  else
    log_info ""
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "📊 MLS Streak & Ledger"
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info ""
    log_info "1️⃣  Validation Streak:"
    if [[ "$streak_exists" == "true" ]]; then
      log_info "   ✅ Streak file exists"
      log_info "   📊 Current streak: ${streak}"
    else
      log_info "   ⚠️  Streak file not found (will be created on first validation)"
      log_info "   Location: ${STREAK_FILE}"
    fi
    log_info ""
    log_info "2️⃣  Today's Ledger File (${TODAY}):"
    if [[ "$ledger_exists" == "true" ]]; then
      log_info "   ✅ Ledger file exists"
      if [[ "$ledger_jsonl_ok" == "true" ]]; then
        log_info "   ✅ JSONL format valid"
        log_info "   📊 Entries today: ${entries_today}"
      else
        log_info "   ❌ JSONL format invalid"
      fi
    else
      log_info "   ⚠️  Ledger file not found: ${LEDGER_FILE}"
    fi
  fi
}

# ============================================================
# Main execution
# ============================================================
if [[ "$JSON_MODE" == "true" ]]; then
  # Disable trap for normal exit
  trap - EXIT

  # JSON output mode
  mcp_json=$(check_mcp_bridge 2>/dev/null) || mcp_json='{"ok":false,"error":"check_mcp_bridge failed"}'
  mls_json=$(check_mls 2>/dev/null) || mls_json='{"ok":false,"error":"check_mls failed"}'

  # Re-check MCP_OK and LEDGER_OK after functions run
  mcp_ok_json=$(echo "$mcp_json" | jq -r '.ok' 2>/dev/null || echo "false")
  mls_ok_json=$(echo "$mls_json" | jq -r '.ok' 2>/dev/null || echo "false")

  # Sanitize boolean for --argjson
  local overall_ok_json="false"
  [[ "$mcp_ok_json" == "true" ]] && [[ "$mls_ok_json" == "true" ]] && overall_ok_json="true"

  jq -n \
    --arg ts_ict "$TS_ICT" \
    --argjson mcp_bridge "$mcp_json" \
    --argjson mls "$mls_json" \
    --argjson ok "$overall_ok_json" \
    '{
      ts_ict: $ts_ict,
      mcp_bridge: $mcp_bridge,
      mls: $mls,
      ok: $ok
    }' 2>/dev/null || echo '{"ok":false,"error":"final jq failed","ts_ict":"'"$TS_ICT"'"}'
else
  # Human-readable output mode
  log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  log_info "🔍 Phase 15 Quick Health Check"
  log_info "🕓 TS (ICT): ${TS_ICT}"
  log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  log_info ""
  
  check_mcp_bridge
  check_mls
  
  log_info ""
  log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  log_info "📋 Quick Actions"
  log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  log_info ""
  log_info "Restart MCP Bridge:"
  log_info "  $0 --restart-bridge"
  log_info ""
  log_info "View live logs:"
  log_info "  $0 --tail-log"
  log_info ""
  log_info "Fix today's ledger:"
  log_info "  $0 --fix-ledger-today"
  log_info ""
  log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
fi

# ============================================================
# Exit with appropriate code
# ============================================================
if [[ "$JSON_MODE" == "true" ]]; then
  # In JSON mode, always exit 0 - CI will check the JSON content
  exit 0
elif [[ $MCP_OK -eq 1 ]] && [[ $LEDGER_OK -eq 1 ]]; then
  log_info "✅ Phase15 Quick Health: OK"
  exit 0
else
  log_info "❌ Phase15 Quick Health: FAILED"
  [[ $MCP_OK -ne 1 ]] && log_info "   - MCP Bridge issues detected"
  [[ $LEDGER_OK -ne 1 ]] && log_info "   - Ledger issues detected"
  exit 1
fi
