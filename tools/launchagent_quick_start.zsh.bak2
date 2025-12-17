#!/usr/bin/env zsh
# Phase 2 Quick Start - Choose your approach
set -euo pipefail

BASE="$HOME/02luka"

echo "🚀 LaunchAgent Phase 2 Quick Start"
echo "===================================="
echo ""
echo "Choose your approach:"
echo ""
echo "1) 🔹 Core Only (7 services)"
echo "   - Start with high-priority core services"
echo "   - Estimated: 30-45 min"
echo ""
echo "2) 🔹 Runtime First (9 services)"
echo "   - Fix runtime errors first (may be quick wins)"
echo "   - Estimated: 30-45 min"
echo ""
echo "3) 🔹 Full Sweep (47 services)"
echo "   - Core + Feature + Runtime all at once"
echo "   - Estimated: 2-3 hours"
echo ""
echo "4) 🔹 Custom (select specific services)"
echo ""
read -r "?Enter choice (1-4): " choice

case "$choice" in
  1)
    echo ""
    echo "🔹 Starting Core Services Investigation..."
    echo ""
    "$BASE/tools/launchagent_investigate_core.zsh"
    echo ""
    echo "👉 Next steps:"
    echo "   1. Review output above"
    echo "   2. Update: g/reports/system/launchagent_repair_PHASE2_STATUS.md"
    echo "   3. Fix services one by one"
    ;;
  2)
    echo ""
    echo "🔹 Starting Runtime Errors Investigation..."
    echo ""
    echo "Runtime Error Services (9 total):"
    echo ""
    echo "Exit Code 1:"
    echo "  - com.02luka.bridge.knowledge.sync"
    echo "  - com.02luka.gmx-clc-orchestrator"
    echo "  - com.02luka.lac-manager"
    echo "  - com.02luka.mls.status.update"
    echo "  - com.02luka.wo_executor.codex"
    echo ""
    echo "Exit Code 2:"
    echo "  - com.02luka.clc-executor"
    echo "  - com.02luka.delegation-watchdog"
    echo "  - com.02luka.doctor"
    echo "  - com.02luka.mary-coo"
    echo ""
    echo "Exit Code 254:"
    echo "  - com.02luka.mcp.memory"
    echo ""
    echo "👉 Check logs:"
    echo "   tail -50 ~/02luka/logs/<service>.log"
    echo ""
    echo "👉 Update status:"
    echo "   g/reports/system/launchagent_repair_PHASE2_STATUS.md"
    ;;
  3)
    echo ""
    echo "🔹 Starting Full Sweep (47 services)..."
    echo ""
    echo "This will take 2-3 hours. Recommended approach:"
    echo "  1. Run core investigation first"
    echo "  2. Fix core services"
    echo "  3. Then move to feature services"
    echo "  4. Finally runtime errors"
    echo ""
    echo "Starting with core services..."
    "$BASE/tools/launchagent_investigate_core.zsh"
    ;;
  4)
    echo ""
    echo "🔹 Custom Service Selection"
    echo ""
    echo "Enter service names (one per line, empty line to finish):"
    services=()
    while IFS= read -r "?Service: " service && [[ -n "$service" ]]; do
      services+=("$service")
    done
    echo ""
    echo "Selected services: ${services[*]}"
    echo "👉 Investigate each manually or create custom script"
    ;;
  *)
    echo "❌ Invalid choice"
    exit 1
    ;;
esac

echo ""
echo "📋 Status tracking:"
echo "   g/reports/system/launchagent_repair_PHASE2_STATUS.md"
echo ""
echo "📖 Plan reference:"
echo "   g/reports/system/launchagent_repair_PLAN_v01.md"
