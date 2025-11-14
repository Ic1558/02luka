#!/usr/bin/env zsh
set -euo pipefail
R="$HOME/02luka/g/reports/mcp_health"
L="$HOME/Library/LaunchAgents"
mkdir -p "$R"

ts() { date "+%Y-%m-%d %H:%M:%S %Z"; }
status() {
  echo "## MCP Health @ $(ts)"
  echo
  for svc in com.02luka.mcp.fs com.02luka.mcp.puppeteer; do
    echo "### $svc"
    launchctl print gui/$(id -u)/$svc 2>&1 | egrep -i 'state =|pid =|last exit code' || true
    echo
  done
  echo "### Logs (tail -5)"
  echo "- mcp_fs.stderr.log:"
  tail -n 5 ~/02luka/logs/mcp_fs.stderr.log 2>/dev/null || echo "  (no log)"
  echo
  echo "- mcp_puppeteer.stderr.log:"
  tail -n 5 ~/02luka/logs/mcp_puppeteer.stderr.log 2>/dev/null || echo "  (no log)"
}
status | tee "$R/$(date +%Y%m%d_%H%M%S).md" > "$R/latest.md"
