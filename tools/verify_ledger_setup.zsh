#!/usr/bin/env zsh
# Verify Agent Ledger Setup
# Checks all setup components

set -euo pipefail

echo "🔍 Agent Ledger Setup Verification"
echo "==================================="
echo ""

# Check LaunchAgent symlinks
echo "1. LaunchAgent Symlinks:"
if [[ -L ~/Library/LaunchAgents/com.02luka.ledger.monitor.plist ]] && \
   [[ -L ~/Library/LaunchAgents/com.02luka.session.summary.automation.plist ]]; then
  echo "  ✅ Symlinks exist"
  ls -la ~/Library/LaunchAgents/com.02luka.ledger.* ~/Library/LaunchAgents/com.02luka.session.* 2>/dev/null | head -2
else
  echo "  ❌ Symlinks missing"
  echo "  Run: mkdir -p ~/Library/LaunchAgents"
  echo "  Run: ln -sf /Users/icmini/02luka/LaunchAgents/com.02luka.ledger.monitor.plist ~/Library/LaunchAgents/"
  echo "  Run: ln -sf /Users/icmini/02luka/LaunchAgents/com.02luka.session.summary.automation.plist ~/Library/LaunchAgents/"
fi
echo ""

# Check LaunchAgents loaded
echo "2. LaunchAgents Loaded:"
if launchctl list | grep -q "com.02luka.ledger.monitor"; then
  echo "  ✅ ledger.monitor loaded"
else
  echo "  ⚠️  ledger.monitor not loaded"
  echo "  Run: launchctl load ~/Library/LaunchAgents/com.02luka.ledger.monitor.plist"
fi

if launchctl list | grep -q "com.02luka.session.summary"; then
  echo "  ✅ session.summary.automation loaded"
else
  echo "  ⚠️  session.summary.automation not loaded"
  echo "  Run: launchctl load ~/Library/LaunchAgents/com.02luka.session.summary.automation.plist"
fi
echo ""

# Check scripts
echo "3. Scripts Executable:"
SCRIPTS=(
  "tools/test_agent_ledger_writes.zsh"
  "tools/monitor_ledger_growth.zsh"
  "tools/automate_session_summaries.zsh"
  "tools/cls_ledger_hook.zsh"
  "tools/andy_ledger_hook.zsh"
  "tools/hybrid_ledger_hook.zsh"
)

for script in "${SCRIPTS[@]}"; do
  if [[ -x "$script" ]]; then
    echo "  ✅ $(basename $script)"
  else
    echo "  ❌ $(basename $script) (not executable)"
  fi
done
echo ""

# Check ledger files
echo "4. Ledger Files:"
LEDGER_FILES=$(find g/ledger -name "*.jsonl" 2>/dev/null | wc -l | tr -d ' ')
if [[ $LEDGER_FILES -gt 0 ]]; then
  echo "  ✅ Found $LEDGER_FILES ledger file(s)"
  find g/ledger -name "*.jsonl" 2>/dev/null | head -3 | sed 's|^|    |'
else
  echo "  ⚠️  No ledger files yet (will be created on first agent activity)"
fi
echo ""

# Check status files
echo "5. Status Files:"
STATUS_FILES=$(ls -1 agents/*/status.json 2>/dev/null | wc -l | tr -d ' ')
if [[ $STATUS_FILES -gt 0 ]]; then
  echo "  ✅ Found $STATUS_FILES status file(s)"
  ls -1 agents/*/status.json 2>/dev/null | sed 's|^|    |'
else
  echo "  ⚠️  No status files yet (will be created on first agent activity)"
fi
echo ""

echo "==================================="
echo "✅ Verification complete"
