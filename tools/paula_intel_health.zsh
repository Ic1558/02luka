#!/usr/bin/env zsh
set -e

# Phase 6.1: Paula Intel Health Check

SOT="${LUKA_SOT:-/Users/icmini/02luka}"

ok() { print "✅ $1"; }
ng() { print "❌ $1"; exit 1; }

echo "=== Paula Intel Health Check ==="
echo ""

# Check scripts exist and are executable
echo "1. Checking scripts..."
[[ -x "$SOT/tools/paula_data_crawler.py" ]] && ok "crawler ready" || ng "crawler missing or not executable"
[[ -x "$SOT/tools/paula_predictive_analytics.py" ]] && ok "predictive ready" || ng "predictive missing or not executable"
[[ -x "$SOT/tools/paula_intel_orchestrator.zsh" ]] && ok "orchestrator ready" || ng "orchestrator missing or not executable"
echo ""

# Check directories
echo "2. Checking directories..."
[[ -d "$SOT/data/market" ]] && ok "data/market directory exists" || echo "⚠️  data/market directory missing (will be created)"
[[ -d "$SOT/mls/paula/intel" ]] && ok "mls/paula/intel directory exists" || echo "⚠️  mls/paula/intel directory missing (will be created)"
echo ""

# Check for output files (today)
echo "3. Checking today's output files..."
TODAY=$(date +%Y%m%d)
SYMBOL="${PAULA_SYMBOL:-SET50Z25}"

CRAWLER_FILE="$SOT/mls/paula/intel/crawler_${SYMBOL}_${TODAY}.json"
BIAS_FILE="$SOT/mls/paula/intel/paula_bias_${SYMBOL}_${TODAY}.json"

if [[ -f "$CRAWLER_FILE" ]]; then
  RECORDS=$(jq -r '.records // 0' "$CRAWLER_FILE" 2>/dev/null || echo "0")
  ok "crawler output exists: $CRAWLER_FILE ($RECORDS records)"
else
  echo "ℹ️  No crawler output for today (run orchestrator first)"
fi

if [[ -f "$BIAS_FILE" ]]; then
  BIAS=$(jq -r '.bias // "unknown"' "$BIAS_FILE" 2>/dev/null || echo "unknown")
  CONF=$(jq -r '.trend_confidence // 0' "$BIAS_FILE" 2>/dev/null || echo "0")
  ok "bias output exists: $BIAS_FILE (bias: $BIAS, confidence: $CONF)"
  
  # Verify bias key exists (as suggested)
  if jq -e '.bias' "$BIAS_FILE" >/dev/null 2>&1; then
    ok "bias key present in JSON"
  else
    ng "bias key missing in JSON"
  fi
else
  echo "ℹ️  No bias output for today (run orchestrator first)"
fi
echo ""

# Check Redis integration
echo "4. Checking Redis integration..."
if command -v redis-cli >/dev/null 2>&1; then
  REDIS_PASS="${REDIS_PASSWORD:-gggclukaic}"
  [[ -n "${REDIS_ALT_PASSWORD:-}" ]] && REDIS_PASS="$REDIS_ALT_PASSWORD"
  
  if redis-cli -a "$REDIS_PASS" PING >/dev/null 2>&1; then
    ok "Redis connection successful"
    
    PAULA_DATA=$(redis-cli -a "$REDIS_PASS" HGETALL memory:agents:paula 2>/dev/null || echo "")
    if [[ -n "$PAULA_DATA" ]]; then
      ok "Paula data in Redis"
      echo "$PAULA_DATA" | grep -q "bias" && ok "bias field in Redis" || echo "⚠️  bias field not in Redis"
    else
      echo "ℹ️  No Paula data in Redis yet"
    fi
  else
    echo "⚠️  Redis connection failed"
  fi
else
  echo "⚠️  redis-cli not found"
fi
echo ""

# Check LaunchAgent
echo "5. Checking LaunchAgent..."
if [[ -f "$HOME/Library/LaunchAgents/com.02luka.paula.intel.daily.plist" ]]; then
  ok "LaunchAgent plist exists"
  
  if launchctl list 2>/dev/null | grep -q "com.02luka.paula.intel.daily"; then
    ok "LaunchAgent is loaded"
  else
    echo "⚠️  LaunchAgent plist exists but not loaded"
  fi
else
  echo "⚠️  LaunchAgent plist missing"
fi
echo ""

# Dry run test (optional)
echo "6. Dry run test (optional)..."
echo "ℹ️  To test orchestrator: $SOT/tools/paula_intel_orchestrator.zsh"
echo "ℹ️  Check logs: tail -f $SOT/logs/paula_intel_orchestrator.log"
echo ""

echo "=== Health Check Complete ==="
