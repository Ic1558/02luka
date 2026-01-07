#!/usr/bin/env zsh
# ATG System Snapshot - Decision-Grade for GG
#
# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title ATG Snapshot
# @raycast.mode fullOutput
# @raycast.packageName 02luka
#
# Optional parameters:
# @raycast.icon 📸
# @raycast.argument1 { "type": "text", "placeholder": "mode (auto/full)", "optional": true }
#
# Documentation:
# @raycast.description Generate smart snapshot: 95% summary-only, 5% summary+raw (auto-detect)
# @raycast.author icmini

set -euo pipefail

ROOT="$HOME/02luka"
cd "$ROOT" || exit 1

MODE="${1:-auto}"  # auto = smart detection | full = always include raw

TIMESTAMP_UTC=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TIMESTAMP_LOCAL=$(date +"%Y-%m-%dT%H:%M:%S%z")
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
HEAD=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

OUTPUT_DIR="magic_bridge/inbox"
mkdir -p "$OUTPUT_DIR"

# ============================================================
# TIER 1: Quick Decision Summary (10-line standard)
# ============================================================
generate_summary() {
  local dirty git_status bridge_pid bridge_status error_count
  local latency_avg spool_inbox last_error anomalies action

  # 1. Overall status
  dirty=$(git -C "$ROOT" status --porcelain=v1 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$dirty" -eq 0 ]]; then
    git_status="✅ CLEAN"
  else
    git_status="⚠️ DIRTY ($dirty files)"
  fi

  # 2. Bridge status
  if [[ -f "$ROOT/g/reports/health/bridge_health.json" ]]; then
    bridge_pid=$(jq -r '.pid // "unknown"' "$ROOT/g/reports/health/bridge_health.json" 2>/dev/null || echo "unknown")
    local ts=$(jq -r '.timestamp // ""' "$ROOT/g/reports/health/bridge_health.json" 2>/dev/null || echo "")
    if pgrep -q "^${bridge_pid}$" 2>/dev/null; then
      bridge_status="✅ Running (PID $bridge_pid)"
    else
      bridge_status="❌ Not running"
    fi
  else
    bridge_status="⚠️ Health file missing"
  fi

  # 3. Error count (stderr logs)
  error_count=$(grep -c "error\|Error\|ERROR\|Exception" /tmp/com.antigravity.bridge.stderr.log 2>/dev/null || echo "0")
  if [[ "$error_count" -gt 0 ]]; then
    last_error=$(grep -i "error\|exception" /tmp/com.antigravity.bridge.stderr.log 2>/dev/null | tail -1 || echo "N/A")
  else
    last_error="None"
  fi

  # 4. Latency (from recent telemetry)
  if [[ -f "$ROOT/g/telemetry/atg_runner.jsonl" ]]; then
    latency_avg=$(tail -20 "$ROOT/g/telemetry/atg_runner.jsonl" 2>/dev/null | \
      jq -r 'select(.duration_ms) | .duration_ms' 2>/dev/null | \
      awk '{sum+=$1; n++} END {if(n>0) printf "%.1f", sum/n; else print "N/A"}')
    [[ "$latency_avg" == "N/A" ]] && latency_avg="No data"
  else
    latency_avg="No telemetry file"
  fi

  # 5. Spool/queue counts
  spool_inbox=$(ls -1 "$ROOT/magic_bridge/inbox" 2>/dev/null | wc -l | tr -d ' ')
  local spool_outbox=$(ls -1 "$ROOT/magic_bridge/outbox" 2>/dev/null | wc -l | tr -d ' ')

  # 6. Detect anomalies
  anomalies=()
  [[ "$dirty" -gt 5 ]] && anomalies+=("High git dirty count")
  [[ "$error_count" -gt 0 ]] && anomalies+=("$error_count stderr errors")
  [[ "$spool_inbox" -gt 10 ]] && anomalies+=("Inbox buildup: $spool_inbox files")
  if [[ "$latency_avg" =~ ^[0-9.]+$ ]] && (( $(echo "$latency_avg > 10000" | bc -l 2>/dev/null || echo 0) )); then
    anomalies+=("High latency: ${latency_avg}ms")
  fi

  # 7. Overall verdict
  local overall="✅ OK"
  if [[ "${bridge_status}" =~ "❌" ]] || [[ "$error_count" -gt 0 ]]; then
    overall="❌ FAIL"
  elif [[ ${#anomalies[@]} -gt 0 ]]; then
    overall="⚠️ WARN"
  fi

  # 8. Recommended actions
  if [[ "$overall" == "❌ FAIL" ]]; then
    action="🔴 Check bridge logs + restart if needed"
  elif [[ "$overall" == "⚠️ WARN" ]]; then
    action="⚠️ Review anomalies + check telemetry"
  else
    action="✅ No action needed"
  fi

  # ============================================================
  # 10-LINE DECISION SUMMARY
  # ============================================================
  cat <<EOF
╔═══════════════════════════════════════════════════════════╗
║  📊 ATG SNAPSHOT - DECISION SUMMARY                       ║
╚═══════════════════════════════════════════════════════════╝

1️⃣  Overall Status:    $overall
2️⃣  Timestamp:         $TIMESTAMP_LOCAL
3️⃣  Git Status:        $git_status (Branch: $BRANCH @ $HEAD)
4️⃣  Bridge Status:     $bridge_status
5️⃣  Error Count:       $error_count (Last: ${last_error:0:60})
6️⃣  Latency:           Avg ${latency_avg}ms
7️⃣  Queue Status:      Inbox: $spool_inbox, Outbox: $spool_outbox
8️⃣  Missing Deps:      $(check_deps)
9️⃣  Top Anomalies:     ${anomalies[*]:-None detected}
🔟 Recommended:        $action

═══════════════════════════════════════════════════════════
EOF
}

check_deps() {
  local missing=()
  [[ ! -x "$ROOT/tools/bridgectl.zsh" ]] && missing+=("bridgectl.zsh")
  [[ ! -f "$ROOT/g/telemetry/atg_runner.jsonl" ]] && missing+=("telemetry")
  [[ ${#missing[@]} -eq 0 ]] && echo "None" || echo "${missing[*]}"
}

# ============================================================
# TIER 2: Conditional Raw Evidence
# ============================================================
should_include_raw() {
  # Auto-detect: include raw if anomalies detected
  local dirty error_count
  dirty=$(git -C "$ROOT" status --porcelain=v1 2>/dev/null | wc -l | tr -d ' ')
  error_count=$(grep -c "error\|Error\|ERROR\|Exception" /tmp/com.antigravity.bridge.stderr.log 2>/dev/null || echo "0")
  
  if [[ "$MODE" == "full" ]]; then
    return 0  # Always include
  elif [[ "$dirty" -gt 5 ]] || [[ "$error_count" -gt 0 ]]; then
    return 0  # Anomaly detected
  else
    return 1  # Clean, summary only
  fi
}

generate_raw_slice() {
  cat <<EOF

╔═══════════════════════════════════════════════════════════╗
║  📄 RAW EVIDENCE (Anomaly Detected - Selective Slice)     ║
╚═══════════════════════════════════════════════════════════╝

## Git Status (Dirty Files)
$(git -C "$ROOT" status --porcelain=v1 2>/dev/null | head -20)

## Recent Errors (stderr)
$(tail -10 /tmp/com.antigravity.bridge.stderr.log 2>/dev/null || echo "No errors")

## Last 5 Telemetry Events
$(tail -5 "$ROOT/g/telemetry/atg_runner.jsonl" 2>/dev/null | jq -r '. | "\(.ts) | \(.event) | \(.file // "N/A")"' 2>/dev/null || echo "No telemetry")

## Active Processes
$(pgrep -fl 'gemini_bridge|api_server|fs_watcher' 2>/dev/null | head -10 || echo "No processes")

═══════════════════════════════════════════════════════════
📌 Full raw snapshot available at: $OUTPUT_DIR/atg_snapshot.md
EOF
}

# ============================================================
# TIER 3: Full Forensic (always generated, but shown conditionally)
# ============================================================
generate_full_raw() {
  local out="$OUTPUT_DIR/atg_snapshot.md"
  {
    echo "# 📸 Antigravity System Snapshot (Full Forensic)"
    echo "**Timestamp (UTC):** $TIMESTAMP_UTC"
    echo "**Timestamp (Local):** $TIMESTAMP_LOCAL"
    echo "**Repo Root:** $ROOT"
    echo "**Branch:** $BRANCH"
    echo "**HEAD:** $HEAD"
    echo ""
    
    echo "## 1. Git Context 🌳"
    echo '```'
    git -C "$ROOT" status --porcelain=v1 2>&1 || true
    echo '```'
    echo ""
    
    echo "## 2. Runtime Context ⚙️"
    echo '```'
    pgrep -fl 'gemini_bridge|bridge\.sh|api_server|antigravity|fs_watcher|python' 2>&1 | grep -v atg | head -50 || echo "(no processes)"
    echo '```'
    echo ""
    
    echo "## 3. Telemetry Pulse 📊"
    echo '```'
    tail -50 "$ROOT/g/telemetry/atg_runner.jsonl" 2>/dev/null || echo "_File not found_"
    echo '```'
    echo ""
    
    echo "## 4. System Logs 🔴"
    echo '```'
    echo "=== stderr ==="
    tail -30 /tmp/com.antigravity.bridge.stderr.log 2>/dev/null || echo "(no log)"
    echo ""
    echo "=== stdout ==="
    tail -30 /tmp/com.antigravity.bridge.stdout.log 2>/dev/null || echo "(no log)"
    echo '```'
    echo ""
    
    echo "## 5. Metadata"
    echo "Version: 2.2-decision-grade"
    echo "Mode: $MODE"
  } > "$out"
  
  echo "$out"
}

# ============================================================
# MAIN EXECUTION
# ============================================================

# Always generate full raw (for audit trail)
RAW_PATH=$(generate_full_raw)

# Generate decision summary
SUMMARY=$(generate_summary)

# Decide what to show + copy
if should_include_raw; then
  # Anomaly detected: show summary + raw slice
  OUTPUT="$SUMMARY
$(generate_raw_slice)"
  echo "⚠️  Anomaly detected - Including raw evidence slice"
else
  # Clean: show summary only
  OUTPUT="$SUMMARY"
  echo "✅ System healthy - Summary only"
fi

# Copy summary to clipboard
if command -v pbcopy >/dev/null 2>&1; then
  echo "$OUTPUT" | pbcopy
  echo "📋 Copied to clipboard"
else
  echo "⚠️  pbcopy not found"
fi

# Display output
echo "$OUTPUT"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📁 Full raw: $RAW_PATH"
echo "🎯 Mode: $MODE (auto-detect anomalies)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
