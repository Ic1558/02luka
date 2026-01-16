#!/usr/bin/env zsh
set -euo pipefail

REPO="$HOME/02luka"
cd "$REPO"

echo "== Stage Phase 5 fixes (if present) =="
git add -A tools/certificate_validator.zsh tools/governance_alert_hook.zsh tools/governance_report_generator.zsh tools/memory_metrics_collector.zsh 2>/dev/null || true
git add -A tools/governance_self_audit.zsh 2>/dev/null || true

if ! git diff --cached --quiet; then
  git commit -m "fix(phase5): governance + metrics fixes, add self_audit" || true
fi

echo "== Stage Phase 6.1 Paula Intel (if present) =="
git add -A tools/paula_data_crawler.py tools/paula_predictive_analytics.py tools/paula_intel_orchestrator.zsh tools/paula_intel_health.zsh 2>/dev/null || true
if ! git diff --cached --quiet; then
  git commit -m "feat(phase6.1): Paula intel core scripts" || true
fi

echo "== Push (best-effort) =="
git pull --rebase || true
git push || true

echo "== Ensure LaunchAgent exists =="
PLIST="$HOME/Library/LaunchAgents/com.02luka.paula.intel.daily.plist"
if [[ -f "$PLIST" ]]; then
  launchctl unload "$PLIST" 2>/dev/null || true
  launchctl load -w "$PLIST"
  echo "Loaded: com.02luka.paula.intel.daily"
else
  echo "WARN: LaunchAgent not found: $PLIST"
fi

echo "== One-shot health & E2E test =="
if [[ -x tools/paula_intel_health.zsh ]]; then
  tools/paula_intel_health.zsh || true
fi
if [[ -x tools/paula_intel_orchestrator.zsh ]]; then
  tools/paula_intel_orchestrator.zsh || true
fi

echo "== Quick Redis peek (non-fatal) =="
if command -v redis-cli >/dev/null 2>&1; then
  REDIS_PASS="${REDIS_PASSWORD:-gggclukaic}"
  [[ -n "${REDIS_ALT_PASSWORD:-}" ]] && REDIS_PASS="$REDIS_ALT_PASSWORD"
  redis-cli -a "$REDIS_PASS" HGETALL memory:agents:paula 2>/dev/null || true
fi

echo "== Done =="
