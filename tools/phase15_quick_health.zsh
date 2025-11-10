#!/usr/bin/env zsh
# Phase 15 Quick Health Check
# Quick diagnostic commands for MCP Bridge and MLS services

set -euo pipefail

LUKA_HOME="${HOME}/02luka"
USER_ID=$(id -u)
SERVICE_MCP_BRIDGE="com.02luka.gg.mcp-bridge"
PLIST_MCP_BRIDGE="${HOME}/Library/LaunchAgents/${SERVICE_MCP_BRIDGE}.plist"
TODAY=$(TZ=Asia/Bangkok date +%Y-%m-%d)
LEDGER_FILE="${LUKA_HOME}/mls/ledger/${TODAY}.jsonl"
STREAK_FILE="${LUKA_HOME}/mls/status/mls_validation_streak.json"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 Phase 15 Quick Health Check"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ============================================================
# MCP Bridge Service Check
# ============================================================
echo "📡 MCP Bridge: ${SERVICE_MCP_BRIDGE}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 1. สถานะ + PID
echo ""
echo "1️⃣  Service Status & PID:"
if launchctl list | grep -q "${SERVICE_MCP_BRIDGE}"; then
  launchctl list | grep "${SERVICE_MCP_BRIDGE}"
  echo "   ✅ Service is loaded"
else
  echo "   ❌ Service not found in launchctl list"
fi

# 2. รายละเอียดบริการ
echo ""
echo "2️⃣  Service Details (Program, KeepAlive, RunAtLoad, LastExitStatus):"
if launchctl print "gui/${USER_ID}/${SERVICE_MCP_BRIDGE}" >/dev/null 2>&1; then
  launchctl print "gui/${USER_ID}/${SERVICE_MCP_BRIDGE}" | grep -E "program|KeepAlive|RunAtLoad|LastExitStatus" || true
  LAST_EXIT=$(launchctl print "gui/${USER_ID}/${SERVICE_MCP_BRIDGE}" 2>/dev/null | grep "LastExitStatus" | awk '{print $2}' || echo "unknown")
  if [ "$LAST_EXIT" = "0" ] || [ "$LAST_EXIT" = "unknown" ]; then
    echo "   ✅ LastExitStatus: ${LAST_EXIT}"
  else
    echo "   ⚠️  LastExitStatus: ${LAST_EXIT} (non-zero - may indicate crash)"
  fi
else
  echo "   ⚠️  Cannot print service details (service may not be loaded)"
fi

# 3. ตรวจ plist
echo ""
echo "3️⃣  Plist Validation:"
if [ -f "${PLIST_MCP_BRIDGE}" ]; then
  if plutil -lint "${PLIST_MCP_BRIDGE}" >/dev/null 2>&1; then
    echo "   ✅ Plist syntax valid"
    
    # ตรวจ Label
    LABEL=$(grep -A 1 "<key>Label</key>" "${PLIST_MCP_BRIDGE}" | grep "<string>" | sed 's/.*<string>\(.*\)<\/string>.*/\1/')
    if [ "${LABEL}" = "${SERVICE_MCP_BRIDGE}" ]; then
      echo "   ✅ Label matches: ${LABEL}"
    else
      echo "   ⚠️  Label mismatch: expected ${SERVICE_MCP_BRIDGE}, found ${LABEL}"
    fi
    
    # ตรวจ Program/ProgramArguments
    if grep -q "ProgramArguments" "${PLIST_MCP_BRIDGE}"; then
      PROGRAM=$(grep -A 2 "ProgramArguments" "${PLIST_MCP_BRIDGE}" | grep "<string>" | head -1 | sed 's/.*<string>\(.*\)<\/string>.*/\1/' | sed "s|\$HOME|${HOME}|g")
      if [ -f "${PROGRAM}" ] || command -v "${PROGRAM}" >/dev/null 2>&1; then
        echo "   ✅ Program exists: ${PROGRAM}"
      else
        echo "   ⚠️  Program not found: ${PROGRAM}"
      fi
    fi
    
    # ตรวจ KeepAlive
    if grep -q "<key>KeepAlive</key>" "${PLIST_MCP_BRIDGE}"; then
      KEEPALIVE=$(grep -A 1 "<key>KeepAlive</key>" "${PLIST_MCP_BRIDGE}" | grep -E "<true/>|<false/>" | grep -q "<true/>" && echo "true" || echo "false")
      echo "   ℹ️  KeepAlive: ${KEEPALIVE}"
    fi
    
    # ตรวจ RunAtLoad
    if grep -q "<key>RunAtLoad</key>" "${PLIST_MCP_BRIDGE}"; then
      RUNATLOAD=$(grep -A 1 "<key>RunAtLoad</key>" "${PLIST_MCP_BRIDGE}" | grep -E "<true/>|<false/>" | grep -q "<true/>" && echo "true" || echo "false")
      echo "   ℹ️  RunAtLoad: ${RUNATLOAD}"
    fi
  else
    echo "   ❌ Plist syntax invalid"
    plutil -lint "${PLIST_MCP_BRIDGE}" 2>&1 || true
  fi
else
  echo "   ❌ Plist not found: ${PLIST_MCP_BRIDGE}"
fi

# ============================================================
# MLS Streak & Ledger Check
# ============================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 MLS Streak & Ledger"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 1. ดู streak
echo ""
echo "1️⃣  Validation Streak:"
if [ -f "${STREAK_FILE}" ]; then
  cat "${STREAK_FILE}" | jq . 2>/dev/null || echo "   ⚠️  File exists but not valid JSON"
else
  echo "   ⚠️  Streak file not found (will be created on first validation)"
  echo "   Location: ${STREAK_FILE}"
fi

# 2. ดู entry วันนี้
echo ""
echo "2️⃣  Today's MLS Entries (${TODAY}):"
if [ -f "${LUKA_HOME}/tools/mls_view.zsh" ]; then
  "${LUKA_HOME}/tools/mls_view.zsh" --today 2>/dev/null || echo "   ⚠️  Error running mls_view.zsh"
else
  echo "   ⚠️  mls_view.zsh not found: ${LUKA_HOME}/tools/mls_view.zsh"
fi

# 3. ยืนยัน ledger วันนี้
echo ""
echo "3️⃣  Today's Ledger File (${TODAY}):"
if [ -f "${LEDGER_FILE}" ]; then
  # ตรวจว่าเป็น JSONL ที่ถูกต้อง
  if tail -n 3 "${LEDGER_FILE}" | jq -c . >/dev/null 2>&1; then
    echo "   ✅ JSONL format valid"
    echo "   📄 File: ${LEDGER_FILE}"
    echo "   📊 Last 3 entries:"
    tail -n 3 "${LEDGER_FILE}" | jq -c . | sed 's/^/      /'
  else
    echo "   ⚠️  File exists but not valid JSONL"
  fi
else
  echo "   ⚠️  Ledger file not found: ${LEDGER_FILE}"
fi

# ============================================================
# Summary
# ============================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Quick Actions"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Restart MCP Bridge:"
echo "  launchctl bootout gui/${USER_ID}/${SERVICE_MCP_BRIDGE} 2>/dev/null || true"
echo "  launchctl bootstrap gui/${USER_ID} \"${PLIST_MCP_BRIDGE}\""
echo "  launchctl kickstart -k gui/${USER_ID}/${SERVICE_MCP_BRIDGE}"
echo ""
echo "View live logs:"
echo "  log stream --predicate 'subsystem CONTAINS \"02luka\" OR process == \"mcp-bridge\"' --info"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

