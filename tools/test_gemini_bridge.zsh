#!/usr/bin/env zsh
# test_gemini_bridge.zsh — Atomic test runner for Gemini Bridge
# Usage: ./tools/test_gemini_bridge.zsh [--cleanup]
# 
# Tests: on_created event → Vertex AI call → outbox write → dedup
# turbo-all

set -euo pipefail

# === Config ===
BRIDGE_DIR="${HOME}/02luka"
BRIDGE_SCRIPT="${BRIDGE_DIR}/bridge.sh"
BRIDGE_LOG="${BRIDGE_DIR}/bridge.log"
INBOX="${BRIDGE_DIR}/magic_bridge/inbox"
OUTBOX="${BRIDGE_DIR}/magic_bridge/outbox"
MOCK_BRAIN="${BRIDGE_DIR}/magic_bridge/mock_brain"
TEST_FILE="test_bridge_$(date +%s).md"
SUMMARY_FILE="${TEST_FILE}.summary.txt"
TIMEOUT_SECS=30  # 6s expected + 24s safety margin

# === Colors ===
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info()  { echo -e "${YELLOW}▶${NC} $1" }
log_pass()  { echo -e "${GREEN}✅ PASS:${NC} $1" }
log_fail()  { echo -e "${RED}❌ FAIL:${NC} $1" }

# === Cleanup mode ===
if [[ "${1:-}" == "--cleanup" ]]; then
    echo "🧹 Cleaning up test artifacts..."
    ( rm -f "${INBOX}"/test_bridge_*.md 2>/dev/null || true )
    ( rm -f "${OUTBOX}"/test_bridge_*.md.summary.txt 2>/dev/null || true )
    ( rm -rf "${MOCK_BRAIN}" 2>/dev/null || true )
    pkill -f gemini_bridge.py 2>/dev/null || true
    echo "Done."
    exit 0
fi

# === Test Sequence ===
echo ""
echo "═══════════════════════════════════════════════════"
echo "  Gemini Bridge Test Runner"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "═══════════════════════════════════════════════════"
echo ""

# 1. Stop any existing bridge
log_info "Stopping any running bridge..."
pkill -f gemini_bridge.py 2>/dev/null || true
sleep 1

# Setup Mock Brain for Wiring Test
MOCK_SESSION="${MOCK_BRAIN}/session_test_$(date +%s)"
mkdir -p "${MOCK_SESSION}"
log_info "Created mock brain session: ${MOCK_SESSION}"

# 2. Start bridge
log_info "Starting bridge..."
# Truncate log and start bridge (combined to avoid race)
: > "${BRIDGE_LOG}"
nohup env PYTHONUNBUFFERED=1 "${BRIDGE_SCRIPT}" >> "${BRIDGE_LOG}" 2>&1 &
nohup env PYTHONUNBUFFERED=1 AG_WIRE=1 AG_BRAIN_ROOT="${MOCK_BRAIN}" "${BRIDGE_SCRIPT}" >> "${BRIDGE_LOG}" 2>&1 &
BRIDGE_PID=$!
disown $BRIDGE_PID 2>/dev/null || true

# Wait for bridge to be ready (deterministic - MUST see "Watching" message)
log_info "Waiting for bridge to initialize (watching log)..."
MAX_WAIT=60
elapsed=0
while (( elapsed < MAX_WAIT * 2 )); do
    if grep -q "👀 Watching" "${BRIDGE_LOG}" 2>/dev/null; then
        log_pass "Bridge started and ready (PID: ${BRIDGE_PID})"
        break
    fi
    sleep 0.5
    elapsed=$((elapsed + 1))
done

if (( elapsed >= MAX_WAIT * 2 )); then
  echo "❌ FAIL: Bridge did not become ready in time."
  echo "DEBUG: bridge process candidates:"
  pgrep -fal "gemini_bridge\.py" || true
  echo "DEBUG: bridge log tail (last 80):"
  tail -n 80 "${BRIDGE_LOG}" || true
    log_fail "Bridge failed to initialize within ${MAX_WAIT}s"
    echo "--- Last 30 lines of bridge.log ---"
    tail -n 30 "${BRIDGE_LOG}" 2>/dev/null || echo "(no log)"
    exit 1
fi

# Verify bridge is running the latest code
log_info "Checking bridge version..."
BRIDGE_CODE_MTIME=$(stat -f%m "${BRIDGE_DIR}/gemini_bridge.py")
BRIDGE_START_TIME=$(ps -p ${BRIDGE_PID} -o lstart= 2>/dev/null | xargs -I {} date -j -f "%a %b %d %T %Y" "{}" +%s 2>/dev/null || echo "0")

if [[ "$BRIDGE_CODE_MTIME" -gt "$BRIDGE_START_TIME" ]] && [[ "$BRIDGE_START_TIME" != "0" ]]; then
    log_fail "Bridge code was modified after process started - stale code running!"
    log_info "Kill bridge and let test restart it fresh"
    exit 1
fi

# Give watchdog observer time to fully initialize
log_info "Waiting for watchdog observer to initialize..."
sleep 3

# 3. Create test file in inbox
log_info "Creating test file: ${TEST_FILE}"
echo "Test event created at $(date '+%Y-%m-%d %H:%M:%S')" > "${INBOX}/${TEST_FILE}"

# 4. Wait for summary to appear (with progress)
log_info "Waiting for Vertex AI response (timeout: ${TIMEOUT_SECS}s)..."
START_WAIT=$(date +%s)
elapsed=0
while [[ ! -f "${OUTBOX}/${SUMMARY_FILE}" ]] && (( elapsed < TIMEOUT_SECS )); do
    sleep 1
    elapsed=$((elapsed + 1))
    if (( elapsed % 5 == 0 )); then
        printf " [%ds]" $elapsed
    else
        printf "."
    fi
done
END_WAIT=$(date +%s)
WAIT_DURATION=$((END_WAIT - START_WAIT))
echo ""
log_info "Wait completed in ${WAIT_DURATION}s"

# 5. Check results
PASS_COUNT=0
FAIL_COUNT=0

# Test A: Summary file exists
if [[ -f "${OUTBOX}/${SUMMARY_FILE}" ]]; then
    log_pass "Summary created: ${SUMMARY_FILE}"
    (( PASS_COUNT++ )) || true
else
    log_fail "Summary not created within ${TIMEOUT_SECS}s (waited ${WAIT_DURATION}s)"
    log_info "Diagnostics:"
    log_info "  - Expected time: ~6s (1s debounce + 5s API)"
    log_info "  - Check if bridge restarted after code changes"
    log_info "  - Check bridge.log for errors"
    log_info "  - Check telemetry for actual API duration"
    (( FAIL_COUNT++ )) || true
fi

# Test B: Summary has content
if [[ -f "${OUTBOX}/${SUMMARY_FILE}" ]] && [[ -s "${OUTBOX}/${SUMMARY_FILE}" ]]; then
    SUMMARY_SIZE=$(stat -f%z "${OUTBOX}/${SUMMARY_FILE}" 2>/dev/null || echo "0")
    log_pass "Summary has content (${SUMMARY_SIZE} bytes)"
    (( PASS_COUNT++ )) || true
else
    log_fail "Summary is empty or missing"
    (( FAIL_COUNT++ )) || true
fi

# Test C: Bridge log shows successful processing
if grep -q "✅ Saved response to: ${SUMMARY_FILE}" "${BRIDGE_LOG}" 2>/dev/null; then
    log_pass "Bridge log confirms Vertex AI success"
    (( PASS_COUNT++ )) || true
else
    log_fail "No success message in bridge log"
    (( FAIL_COUNT++ )) || true
fi

# Test D: Dedup works (touch same file again, should skip)
log_info "Testing dedup (re-touching same content)..."
touch "${INBOX}/${TEST_FILE}"
sleep 2
SKIP_COUNT=$(grep -c "⏭️  Skipping (content unchanged): ${TEST_FILE}" "${BRIDGE_LOG}" 2>/dev/null) || SKIP_COUNT=0
if [[ "$SKIP_COUNT" -gt 0 ]]; then
    log_pass "Dedup working (skipped unchanged content)"
    (( PASS_COUNT++ )) || true
else
    log_fail "Dedup not triggered"
    (( FAIL_COUNT++ )) || true
fi

# Test E: Wiring Verification (Check if feedback was injected)
FEEDBACK_FILE="${MOCK_SESSION}/99_BRIDGE_FEEDBACK.md"
if [[ -f "${FEEDBACK_FILE}" ]] && grep -q "Bridge Insight:" "${FEEDBACK_FILE}"; then
    log_pass "Wiring active (Feedback injected into mock brain)"
    (( PASS_COUNT++ )) || true
else
    log_fail "Wiring failed (No feedback file in mock brain)"
    (( FAIL_COUNT++ )) || true
fi

# === Summary ===
echo ""
echo "═══════════════════════════════════════════════════"
if (( FAIL_COUNT == 0 )); then
    echo -e "  ${GREEN}ALL TESTS PASSED${NC} (${PASS_COUNT}/${PASS_COUNT})"
else
    echo -e "  ${RED}SOME TESTS FAILED${NC} (${PASS_COUNT}/$((PASS_COUNT + FAIL_COUNT)) passed)"
fi
echo "═══════════════════════════════════════════════════"
echo ""

# Show summary content
if [[ -f "${OUTBOX}/${SUMMARY_FILE}" ]]; then
    echo "--- Generated Summary ---"
    cat "${OUTBOX}/${SUMMARY_FILE}"
    echo ""
    echo "-------------------------"
fi

# Show last few log lines
echo ""
echo "--- Bridge Log (last 8 lines) ---"
tail -n 8 "${BRIDGE_LOG}"

echo ""
echo "💡 Run with --cleanup to remove test artifacts"
echo "💡 Bridge is still running. Stop with: pkill -f gemini_bridge.py"

exit ${FAIL_COUNT}
