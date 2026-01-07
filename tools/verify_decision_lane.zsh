#!/usr/bin/env zsh
# tools/verify_decision_lane.zsh
# Smoke test for decision summarizer pipeline
set -euo pipefail

REPO="$HOME/02luka"
cd "$REPO"

echo "🔍 Decision Lane Verification"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 1. Check required files
echo "1. Required files..."
for f in gemini_bridge.py decision_summarizer.py g/telemetry/decision_log.jsonl; do
  if [[ -f "$f" ]]; then
    echo "   ✅ $f"
  else
    echo "   ❌ $f MISSING"
    exit 1
  fi
done

# 2. Check bridge process
echo "2. Bridge process..."
if pgrep -fl "gemini_bridge\.py" >/dev/null 2>&1; then
  PID=$(pgrep -f "gemini_bridge\.py")
  echo "   ✅ Running (PID: $PID)"
else
  echo "   ⚠️  Not running"
fi

# 3. Check core history
echo "3. Core history files..."
for f in g/core_history/latest.json g/core_history/latest.md g/core_history/rule_table.json g/core_history/index.json; do
  if [[ -f "$f" ]]; then
    echo "   ✅ $f"
  else
    echo "   ⚠️  $f missing"
  fi
done

# 4. Validate JSON
echo "4. JSON validation..."
# Validate JSONL (line-by-line JSON)
if tail -1 g/telemetry/decision_log.jsonl | python3 -c 'import sys,json; json.loads(sys.stdin.read())' >/dev/null 2>&1; then
  echo "   ✅ decision_log.jsonl (JSONL format valid)"
else
  echo "   ❌ decision_log.jsonl (invalid JSON)"
  exit 1
fi

if [[ -f g/core_history/latest.json ]]; then
  if python3 -c 'import json; json.load(open("g/core_history/latest.json"))' >/dev/null 2>&1; then
    echo "   ✅ core_history/latest.json"
  else
    echo "   ❌ core_history/latest.json (invalid)"
    exit 1
  fi
fi

# 5. Check directory structure
echo "5. Directory structure..."
for d in magic_bridge/inbox magic_bridge/outbox g/telemetry g/core_history; do
  if [[ -d "$d" ]]; then
    echo "   ✅ $d/"
  else
    echo "   ⚠️  $d/ missing"
  fi
done

# 6. Check for inbox pollution
echo "6. Inbox cleanup check..."
INBOX_SUMMARIES=$(ls magic_bridge/inbox/*.summary.txt 2>/dev/null | wc -l | tr -d ' ')
if [[ "$INBOX_SUMMARIES" -eq 0 ]]; then
  echo "   ✅ No summaries in inbox (clean)"
else
  echo "   ⚠️  $INBOX_SUMMARIES summary files in inbox (should be in outbox)"
fi

# 7. Decision log stats
echo "7. Decision log stats..."
LOG_COUNT=$(wc -l < g/telemetry/decision_log.jsonl | tr -d ' ')
echo "   📊 Total entries: $LOG_COUNT"

if [[ "$LOG_COUNT" -gt 0 ]]; then
  LAST_ENTRY=$(tail -1 g/telemetry/decision_log.jsonl)
  RISK=$(echo "$LAST_ENTRY" | python3 -c 'import sys,json; print(json.loads(sys.stdin.read()).get("risk","?"))')
  echo "   📊 Last entry risk: $RISK"
fi

echo ""
echo "✅ Verification complete"
