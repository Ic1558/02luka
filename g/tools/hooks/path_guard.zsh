#!/usr/bin/env zsh
set -euo pipefail

# Path Guard: Enforce function-first structure for reports
# Prevents reports from being committed to wrong locations

bad=$(git diff --cached --name-only | grep -E '^g/reports/[^/]+\.md$' || true)

if [[ -n "$bad" ]]; then
  echo "❌ Reports must be in g/reports/{phase5_governance,phase6_paula,system}/ only"
  echo ""
  echo "Files in wrong location:"
  echo "$bad" | sed 's/^/  - /'
  echo ""
  echo "Please move to appropriate subdirectory:"
  echo "  - Phase 5 reports → g/reports/phase5_governance/"
  echo "  - Phase 6 reports → g/reports/phase6_paula/"
  echo "  - System reports → g/reports/system/"
  exit 1
fi

# Allow reports in correct subdirectories
exit 0

