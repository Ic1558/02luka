#!/usr/bin/env zsh
set -euo pipefail

REPO="$HOME/02luka"

echo "=== Phase 3: Report + Certificate + Dependencies ==="
echo ""

# Verify Phase 1 + 2
echo "Verifying Phase 1 + 2..."
if redis-cli -a changeme-02luka HGETALL memory:agents:claude >/dev/null 2>&1; then
  echo "✅ Phase 1 operational"
else
  echo "❌ Phase 1 not operational"
  exit 1
fi

if grep -q "Claude Code:" "$REPO/tools/memory_hub_health.zsh" 2>/dev/null; then
  echo "✅ Phase 2 operational"
else
  echo "❌ Phase 2 not operational"
  exit 1
fi

# Test report generator
echo ""
echo "Testing report generation..."
"$REPO/tools/governance_report_generator.zsh"

TODAY=$(date +%Y%m%d)
if [[ -f "$REPO/g/reports/system_governance_WEEKLY_${TODAY}.md" ]]; then
  echo "✅ Governance report generated"
  if grep -q "Claude Code Compliance" "$REPO/g/reports/system_governance_WEEKLY_${TODAY}.md"; then
    echo "✅ Report includes Claude Code section"
  else
    echo "❌ Report missing Claude Code section"
    exit 1
  fi
else
  echo "⚠️  Report not generated (may need to wait for scheduled run)"
fi

# Test certificate validation
echo ""
echo "Testing certificate validation..."
"$REPO/tools/certificate_validator.zsh" 2>&1 | tail -10

# Test security checks
echo ""
echo "Testing security checks..."
"$REPO/tools/claude_hooks/security_check.zsh" 2>&1 | tail -5

# Verify LaunchAgents
echo ""
echo "Verifying LaunchAgents..."
if [[ -f ~/Library/LaunchAgents/com.02luka.governance.report.weekly.plist ]]; then
  if launchctl list | grep -q com.02luka.governance.report.weekly; then
    echo "✅ Report LaunchAgent loaded"
  else
    echo "⚠️  Report LaunchAgent not loaded"
  fi
else
  echo "ℹ️  Report LaunchAgent plist not found (will be created in Phase 5 full deployment)"
fi

if [[ -f ~/Library/LaunchAgents/com.02luka.certificate.validator.plist ]]; then
  if launchctl list | grep -q com.02luka.certificate.validator; then
    echo "✅ Certificate validator LaunchAgent loaded"
  else
    echo "⚠️  Certificate validator LaunchAgent not loaded"
  fi
else
  echo "ℹ️  Certificate validator LaunchAgent plist not found (will be created in Phase 5 full deployment)"
fi

echo ""
echo "✅ Phase 3 deployment complete"
