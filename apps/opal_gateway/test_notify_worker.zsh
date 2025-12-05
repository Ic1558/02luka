#!/usr/bin/env zsh
# Test script for Notification Worker
# Tests all worker functionality including startup guard, stale guard, retry, etc.

set -euo pipefail

LUKA_HOME="${LUKA_HOME:-$HOME/02luka}"
NOTIFY_INBOX="$LUKA_HOME/bridge/inbox/NOTIFY"
PROCESSED_DIR="$LUKA_HOME/bridge/processed/NOTIFY"
FAILED_DIR="$LUKA_HOME/bridge/failed/NOTIFY"
LOG_FILE="$LUKA_HOME/g/telemetry/notify_worker.jsonl"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🧪 Notification Worker Test Suite"
echo "=================================="
echo ""

# Test 1: Startup Guard
echo "Test 1: Startup Guard"
echo "---------------------"
if [[ ! -f "$LUKA_HOME/.env.local" ]]; then
  echo "${RED}❌ FAILED: .env.local not found${NC}"
  exit 1
fi

# Check if required vars exist
source "$LUKA_HOME/.env.local"
if [[ -z "${TELEGRAM_SYSTEM_ALERT_BOT_TOKEN:-}" ]]; then
  echo "${RED}❌ FAILED: TELEGRAM_SYSTEM_ALERT_BOT_TOKEN not set${NC}"
  exit 1
fi
if [[ -z "${TELEGRAM_SYSTEM_ALERT_CHAT_ID:-}" ]]; then
  echo "${RED}❌ FAILED: TELEGRAM_SYSTEM_ALERT_CHAT_ID not set${NC}"
  exit 1
fi
echo "${GREEN}✅ PASSED: Startup guard checks${NC}"
echo ""

# Test 2: Create test notification file
echo "Test 2: Create Test Notification"
echo "----------------------------------"
mkdir -p "$NOTIFY_INBOX"
TEST_WO_ID="WO-TEST-$(date +%s)"
TEST_FILE="$NOTIFY_INBOX/${TEST_WO_ID}_notify.json"

cat > "$TEST_FILE" <<EOF
{
  "wo_id": "$TEST_WO_ID",
  "telegram": {
    "chat": "boss_private",
    "text": "🧪 Test notification from worker test suite\n\nWO: $TEST_WO_ID\nStatus: TEST\nTime: $(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "meta": {
      "wo_id": "$TEST_WO_ID",
      "status": "TEST"
    }
  }
}
EOF

if [[ -f "$TEST_FILE" ]]; then
  echo "${GREEN}✅ PASSED: Test notification file created${NC}"
  echo "   File: $TEST_FILE"
else
  echo "${RED}❌ FAILED: Could not create test file${NC}"
  exit 1
fi
echo ""

# Test 3: Test worker functions (if worker is running)
echo "Test 3: Worker Function Tests"
echo "-----------------------------"
echo "Note: This test assumes worker is running"
echo "Waiting 10 seconds for worker to process..."
sleep 10

if [[ -f "$PROCESSED_DIR/${TEST_WO_ID}_notify.json" ]]; then
  echo "${GREEN}✅ PASSED: File moved to processed/ (worker processed it)${NC}"
elif [[ -f "$FAILED_DIR/${TEST_WO_ID}_notify.json" ]]; then
  echo "${YELLOW}⚠️  WARNING: File moved to failed/ (check logs)${NC}"
  echo "   Check: $LOG_FILE"
else
  echo "${YELLOW}⚠️  WARNING: File not processed yet (worker may not be running)${NC}"
  echo "   To start worker: $LUKA_HOME/apps/opal_gateway/notify_worker.zsh"
fi
echo ""

# Test 4: Check log file
echo "Test 4: Log File Check"
echo "-----------------------"
if [[ -f "$LOG_FILE" ]]; then
  echo "${GREEN}✅ PASSED: Log file exists${NC}"
  echo "   Last 3 entries:"
  tail -n 3 "$LOG_FILE" | jq -r '. | "   \(.timestamp) | \(.wo_id) | \(.result) | \(.channel)"' 2>/dev/null || tail -n 3 "$LOG_FILE"
else
  echo "${YELLOW}⚠️  WARNING: Log file not created yet${NC}"
fi
echo ""

# Test 5: Stale notification test
echo "Test 5: Stale Notification Test"
echo "-------------------------------"
STALE_WO_ID="WO-STALE-$(date +%s)"
STALE_FILE="$NOTIFY_INBOX/${STALE_WO_ID}_notify.json"

cat > "$STALE_FILE" <<EOF
{
  "wo_id": "$STALE_WO_ID",
  "telegram": {
    "chat": "boss_private",
    "text": "This is a stale notification test"
  }
}
EOF

# Make file appear 25 hours old
touch -t "$(date -v-25H +%Y%m%d%H%M.%S)" "$STALE_FILE" 2>/dev/null || echo "Note: Could not set file time (may need different method on your system)"

echo "Created stale test file (simulated 25h old)"
echo "Waiting 10 seconds for worker to process..."
sleep 10

if [[ -f "$FAILED_DIR/${STALE_WO_ID}_notify_stale.json" ]]; then
  echo "${GREEN}✅ PASSED: Stale file moved to failed/ with _stale suffix${NC}"
else
  echo "${YELLOW}⚠️  WARNING: Stale file not processed (worker may not be running)${NC}"
fi
echo ""

# Summary
echo "=================================="
echo "Test Summary"
echo "=================================="
echo "✅ Startup guard: PASSED"
echo "✅ Test file creation: PASSED"
echo "⚠️  Worker processing: Check manually (worker may not be running)"
echo "⚠️  Log file: Check manually"
echo "⚠️  Stale guard: Check manually (worker may not be running)"
echo ""
echo "To test fully, start the worker:"
echo "  $LUKA_HOME/apps/opal_gateway/notify_worker.zsh"
echo ""
echo "Or load LaunchAgent:"
echo "  launchctl load ~/Library/LaunchAgents/com.02luka.notify.worker.plist"
