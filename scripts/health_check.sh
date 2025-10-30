#!/usr/bin/env bash
set -euo pipefail

ok=1
warn=0

echo "== Core agents (with plist) =="
for lb in com.02luka.discovery.merge.daily org.02luka.sot.render; do
  if launchctl list | grep -q "$lb"; then
    echo "✅ $lb"
  else
    echo "❌ $lb not loaded"
    ok=0
  fi
done

echo ""
echo "== Planned agents (may not be deployed yet) =="
for lb in com.02luka.boot_guard com.02luka.health_proxy; do
  plist="$HOME/Library/LaunchAgents/$lb.plist"
  if [ ! -f "$plist" ]; then
    echo "⚠️  $lb (no plist - not yet deployed)"
    warn=1
  elif launchctl list | grep -q "$lb"; then
    echo "✅ $lb"
  else
    echo "❌ $lb (plist exists but not loaded)"
    ok=0
  fi
done

echo ""
echo "== Health endpoint =="
if curl -sf http://localhost:7217/health >/dev/null 2>&1; then
  echo "✅ health_proxy responding"
else
  echo "⚠️  health endpoint not responding (health_proxy may not be deployed)"
  warn=1
fi

echo ""
echo "== Logs freshness (last 6 hours) =="
LOGDIR="$HOME/Library/Logs/02luka"
if [ -d "$LOGDIR" ]; then
  recent=$(find "$LOGDIR" -name "com.02luka.*.out" -mmin -360 2>/dev/null | wc -l | tr -d ' ')
  if [ "$recent" -gt 0 ]; then
    echo "✅ $recent active logs found:"
    find "$LOGDIR" -name "com.02luka.*.out" -mmin -360 2>/dev/null | head -3 | sed 's/^/  /' || true
  else
    echo "⚠️  No recent logs (may be normal if agents just started)"
  fi
else
  echo "⚠️  Log directory missing: $LOGDIR"
fi

echo ""
if [ $ok -eq 1 ] && [ $warn -eq 0 ]; then
  echo "✅ HEALTH OK"
  exit 0
elif [ $ok -eq 1 ]; then
  echo "⚠️  HEALTH OK (with warnings - some agents not yet deployed)"
  exit 0
else
  echo "❌ HEALTH FAIL (deployed agents not running)"
  exit 1
fi
