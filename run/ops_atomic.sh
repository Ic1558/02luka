#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# OPS_ATOMIC.sh
# Idempotent, resume-safe atomic operations for 02luka
#
# Phases:
#   1. Preflight - Git health check, auto-push when safe
#   2. Migration - Resume-safe rsync from parent
#   3. Verify   - Service health checks (API/UI/MCP)
#   4. MCP Verification - Detailed MCP gateway testing
#
# Output: g/reports/OPS_ATOMIC_<timestamp>.md
###############################################################################

# Config & Path Resolution
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PARENT="$HOME/Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/My Drive/02luka"
RT="$HOME/Library/02luka_runtime"
REPORT_DIR="$REPO_ROOT/g/reports"
TIMESTAMP=$(date +"%y%m%d_%H%M%S")
REPORT_FILE="$REPORT_DIR/OPS_ATOMIC_${TIMESTAMP}.md"

mkdir -p "$REPORT_DIR"

###############################################################################
# Report Helpers
###############################################################################

log_section() {
  echo "## $1" >> "$REPORT_FILE"
  echo "" >> "$REPORT_FILE"
}

log_msg() {
  echo "$1" >> "$REPORT_FILE"
}

log_code() {
  echo '```' >> "$REPORT_FILE"
  echo "$1" >> "$REPORT_FILE"
  echo '```' >> "$REPORT_FILE"
  echo "" >> "$REPORT_FILE"
}

###############################################################################
# Report Header
###############################################################################

cat > "$REPORT_FILE" <<EOF
---
project: ops
tags: [atomic,daily,automated]
date: $(date -u +"%Y-%m-%dT%H:%M:%S+07:00")
---

# OPS_ATOMIC Report

**Timestamp:** ${TIMESTAMP}
**Reporter:** CLC Atomic Operations
**Status:** Running...

---

EOF

###############################################################################
# Phase 1: Preflight - Git Health
###############################################################################

log_section "Phase 1: Preflight"

cd "$REPO_ROOT"

# Git status
GIT_STATUS=$(git status -sb 2>&1 || echo "error")
log_msg "**Git Status:**"
log_code "$GIT_STATUS"

# Check for uncommitted changes
UNCOMMITTED=$(git status --porcelain | wc -l)
log_msg "- Uncommitted changes: $UNCOMMITTED files"

# Check branch sync
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
AHEAD=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo "0")
BEHIND=$(git rev-list --count HEAD..@{u} 2>/dev/null || echo "0")

log_msg "- Branch: $BRANCH"
log_msg "- Ahead: $AHEAD commits"
log_msg "- Behind: $BEHIND commits"

# Auto-push if safe
PUSH_STATUS="⏭ Skipped"
if [ "$UNCOMMITTED" -eq 0 ] && [ "$AHEAD" -gt 0 ] && [ "$BEHIND" -eq 0 ]; then
  log_msg ""
  log_msg "**Auto-push:** Safe conditions met (clean working dir, ahead commits, not behind)"

  if git push origin "$BRANCH" 2>&1 | tee -a "$REPORT_FILE"; then
    PUSH_STATUS="✅ Success"
    log_msg ""
    log_msg "- Auto-push: ✅ Success"
  else
    PUSH_STATUS="❌ Failed"
    log_msg ""
    log_msg "- Auto-push: ❌ Failed"
  fi
else
  log_msg ""
  log_msg "- Auto-push: ⏭ Skipped (uncommitted=$UNCOMMITTED, ahead=$AHEAD, behind=$BEHIND)"
fi

log_msg ""

###############################################################################
# Phase 2: Migration - Resume-safe rsync
###############################################################################

log_section "Phase 2: Migration"

MIGRATION_ERRORS=0

# boss/legacy_parent
if [ -d "$PARENT/boss" ]; then
  mkdir -p "$REPO_ROOT/boss/legacy_parent"
  BOSS_COUNT=$(rsync -a --ignore-existing "$PARENT/boss/" "$REPO_ROOT/boss/legacy_parent/" 2>&1 | grep -c "^" || echo "0")
  BOSS_FILES=$(find "$REPO_ROOT/boss/legacy_parent" -type f | wc -l)
  log_msg "- boss/legacy_parent: $BOSS_FILES files"
else
  log_msg "- boss/legacy_parent: ⚠️ Source not found"
  MIGRATION_ERRORS=$((MIGRATION_ERRORS + 1))
fi

# g/legacy_parent
if [ -d "$PARENT/g" ]; then
  mkdir -p "$REPO_ROOT/g/legacy_parent"
  G_COUNT=$(rsync -a --ignore-existing "$PARENT/g/" "$REPO_ROOT/g/legacy_parent/" 2>&1 | grep -c "^" || echo "0")
  G_FILES=$(find "$REPO_ROOT/g/legacy_parent" -type f | wc -l)
  log_msg "- g/legacy_parent: $G_FILES files"
else
  log_msg "- g/legacy_parent: ⚠️ Source not found"
  MIGRATION_ERRORS=$((MIGRATION_ERRORS + 1))
fi

# docs/legacy_parent
if [ -d "$PARENT/docs" ]; then
  mkdir -p "$REPO_ROOT/docs/legacy_parent"
  DOCS_COUNT=$(rsync -a --ignore-existing "$PARENT/docs/" "$REPO_ROOT/docs/legacy_parent/" 2>&1 | grep -c "^" || echo "0")
  DOCS_FILES=$(find "$REPO_ROOT/docs/legacy_parent" -type f | wc -l)
  log_msg "- docs/legacy_parent: $DOCS_FILES files"
else
  log_msg "- docs/legacy_parent: ⚠️ Source not found"
  MIGRATION_ERRORS=$((MIGRATION_ERRORS + 1))
fi

log_msg ""
log_msg "**Migration Summary:**"
log_msg "- Errors: $MIGRATION_ERRORS"
log_msg ""

###############################################################################
# Phase 3: Verify - Service Health Checks
###############################################################################

log_section "Phase 3: Verify"

# API Check
API_STATUS="❌ DOWN"
if curl -sf http://127.0.0.1:4000/healthz > /dev/null 2>&1; then
  API_STATUS="✅ UP"
fi
log_msg "- API (http://127.0.0.1:4000): $API_STATUS"

# UI Check
UI_STATUS="❌ DOWN"
if curl -sf http://127.0.0.1:5173/apps/landing.html > /dev/null 2>&1; then
  UI_STATUS="✅ UP"
fi
log_msg "- UI (http://127.0.0.1:5173): $UI_STATUS"

# MCP Check
MCP_STATUS="❌ DOWN"
if curl -sf http://127.0.0.1:5012/health > /dev/null 2>&1; then
  MCP_STATUS="✅ UP"
fi
log_msg "- MCP (http://127.0.0.1:5012): $MCP_STATUS"

log_msg ""

###############################################################################
# Phase 4: MCP Verification
###############################################################################

log_section "Phase 4: MCP Verification"

# Find latest MCP verification report
MCP_REPORT=$(find "$REPORT_DIR" -name "*_mcp_verification.md" -type f 2>/dev/null | sort -r | head -1)

if [ -n "$MCP_REPORT" ] && [ -f "$MCP_REPORT" ]; then
  log_msg "**Source:** Existing MCP verification report"
  log_msg "**File:** $(basename "$MCP_REPORT")"
  log_msg ""

  # Extract key metrics from report
  MCP_CONTAINER=$(grep -A1 "Container:" "$MCP_REPORT" | tail -1 | xargs || echo "unknown")
  MCP_UPTIME=$(grep "Up.*days" "$MCP_REPORT" | grep -o "Up [^(]*" || echo "unknown")
  MCP_TEST_RATE=$(grep "Success Rate" "$MCP_REPORT" | grep -o "[0-9]*%" || echo "unknown")

  log_msg "**Container:** $MCP_CONTAINER"
  log_msg "**Uptime:** $MCP_UPTIME"
  log_msg "**Test Success Rate:** $MCP_TEST_RATE"

  # Extract test results
  log_msg ""
  log_msg "**Test Results:**"
  if grep -q "Connectivity.*✅" "$MCP_REPORT"; then
    log_msg "- Connectivity: ✅ PASS"
  fi
  if grep -q "User Profile.*✅" "$MCP_REPORT"; then
    log_msg "- User Profile: ✅ PASS"
  fi
  if grep -q "Repository Search.*✅" "$MCP_REPORT"; then
    log_msg "- Repository Search: ✅ PASS"
  fi
  if grep -q "Workflows.*✅" "$MCP_REPORT"; then
    log_msg "- Workflows: ✅ PASS"
  fi
  if grep -q "Notifications.*⚠️" "$MCP_REPORT"; then
    log_msg "- Notifications: ⚠️ LIMITED (OAuth required)"
  fi

  log_msg ""
  log_msg "_Full report: $(basename "$MCP_REPORT")_"
else
  log_msg "**Source:** Live health check"
  log_msg ""

  # Run live MCP health check
  MCP_HEALTH_RESPONSE=$(curl -s http://127.0.0.1:5012/health 2>&1 || echo '{"error": "connection_failed"}')

  log_msg "**MCP Gateway Health:**"
  log_code "$MCP_HEALTH_RESPONSE"

  # Try to get container status
  if command -v docker &> /dev/null; then
    MCP_CONTAINER_STATUS=$(docker ps --filter "name=mcp" --format "{{.Names}}: {{.Status}}" 2>/dev/null || echo "No MCP container found")
    log_msg "**Container Status:**"
    log_msg "- $MCP_CONTAINER_STATUS"
  fi

  log_msg ""
  log_msg "_Note: For detailed verification, run MCP test suite and generate full report_"
fi

log_msg ""

###############################################################################
# Final Status
###############################################################################

OVERALL_STATUS="✅ OK"
if [ "$API_STATUS" != "✅ UP" ] || [ "$UI_STATUS" != "✅ UP" ] || [ "$MCP_STATUS" != "✅ UP" ]; then
  OVERALL_STATUS="❌ FAIL"
elif [ "$MIGRATION_ERRORS" -gt 0 ]; then
  OVERALL_STATUS="⚠️ WARN"
fi

log_section "Summary"
log_msg "**Overall Status:** $OVERALL_STATUS"
log_msg ""
log_msg "**Services:**"
log_msg "- API: $API_STATUS"
log_msg "- UI: $UI_STATUS"
log_msg "- MCP: $MCP_STATUS"
log_msg ""
log_msg "**Git:**"
log_msg "- Branch: $BRANCH"
log_msg "- Auto-push: $PUSH_STATUS"
log_msg ""
log_msg "**Migration:**"
log_msg "- Errors: $MIGRATION_ERRORS"
log_msg ""
log_msg "---"
log_msg ""
log_msg "**Report:** $REPORT_FILE"
log_msg "**Generated:** $(date -u +"%Y-%m-%d %H:%M:%S UTC")"

###############################################################################
# Run Reportbot
###############################################################################

echo ""
echo "=== Generating JSON summary ==="
if [ -f "$REPO_ROOT/agents/reportbot/index.cjs" ]; then
  node "$REPO_ROOT/agents/reportbot/index.cjs"
else
  echo "⚠️ Reportbot not found at $REPO_ROOT/agents/reportbot/index.cjs"
fi

###############################################################################
# Output
###############################################################################

echo ""
echo "=== OPS_ATOMIC Complete ==="
echo "Status: $OVERALL_STATUS"
echo "Report: $REPORT_FILE"
echo ""
cat "$REPORT_FILE"
