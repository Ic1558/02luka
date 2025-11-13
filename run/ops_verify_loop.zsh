#!/usr/bin/env zsh
set -euo pipefail
PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
REPO="$HOME/02luka"; cd "$REPO"
CURL="/usr/bin/curl"
DATE="/bin/date"
GREP="/usr/bin/grep"
STAMP=$($DATE -u +%Y%m%d_%H%MZ)
OUT="g/reports/phase5/verify_${STAMP}.md"
PASS=1

echo "# Phase 5 Nightly Verify — $STAMP" > "$OUT"
{
  echo "## Steps"
  echo "1) Run monitor once"
  /opt/homebrew/bin/node run/ops_atomic_monitor.cjs >/dev/null 2>&1 || true
  echo "2) Probe Phase 4 services"
  # health-proxy
  if $CURL -fsS "http://127.0.0.1:3002/health" >/dev/null 2>&1; then
    echo "- health-proxy (3002/health): **PASS**"
  else
    echo "- health-proxy (3002/health): **FAIL**"
    PASS=0
  fi
  # mcp-webbridge
  if $CURL -fsS "http://127.0.0.1:3003/health" >/dev/null 2>&1; then
    echo "- mcp-webbridge (3003/health): **PASS**"
  else
    echo "- mcp-webbridge (3003/health): **FAIL**"
    PASS=0
  fi
  # boss-api
  if $CURL -fsS "http://127.0.0.1:4000/healthz" >/dev/null 2>&1; then
    echo "- boss-api (4000/healthz): **PASS**"
  else
    echo "- boss-api (4000/healthz): **FAIL**"
    PASS=0
  fi

  echo "3) Check SLO metrics presence"
  if $CURL -fsS http://127.0.0.1:3002/metrics | $GREP -q 'service_up'; then
    echo "- metrics export: **PASS**"
  else
    echo "- metrics export: **FAIL**"; PASS=0
  fi

  echo "4) Log rotation status"
  tail -n 1 g/logs/_rotate_reports.log 2>/dev/null || echo "(no rotate log yet)"

  echo "5) Collect system metrics"
  if /opt/homebrew/bin/node run/metrics_collector.cjs >/dev/null 2>&1; then
    echo "- metrics collection: **PASS**"
  else
    echo "- metrics collection: **FAIL** (non-critical)"
  fi
} >> "$OUT"

[[ $PASS -eq 1 ]] && RESULT="PASS" || RESULT="FAIL"
echo -e "\n## Result: **${RESULT}**" >> "$OUT"

# Failure alert (file-based trigger for Discord/Kim watchers)
if [[ $PASS -ne 1 ]]; then
  echo "[$($DATE -u +%FT%TZ)] NIGHTLY_VERIFY_FAIL see ${OUT}" >> g/logs/ops_alerts.log
fi
