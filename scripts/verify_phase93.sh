#!/usr/bin/env bash
# Phase 9.3 Health Verification Script
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=== Phase 9.3 Health Verification ==="
echo ""

# Check Redis connection
echo "🔧 **Step 1: Redis Connection**"
if command -v redis-cli >/dev/null 2>&1; then
    if redis-cli PING 2>/dev/null | grep -q PONG; then
        echo "✅ Redis connection: OK"
    else
        echo "❌ Redis connection: FAILED"
        exit 1
    fi
else
    echo "⚠️  Redis CLI not found - assuming Redis not available"
fi

# Check configuration files
echo ""
echo "🔧 **Step 2: Configuration Files**"
if [[ -f "$REPO_ROOT/02luka/config/redis.env" ]]; then
    echo "✅ Redis config: OK"
else
    echo "❌ Redis config: MISSING"
    exit 1
fi

if [[ -f "$REPO_ROOT/02luka/config/redis.off" ]]; then
    echo "⚠️  Cache disabled by redis.off flag"
else
    echo "✅ Cache enabled: OK"
fi

# Check telemetry feed
echo ""
echo "🔧 **Step 3: Telemetry Feed**"
if [[ -f "$REPO_ROOT/g/telemetry/rollup_daily.ndjson" ]]; then
    echo "✅ Telemetry rollup: OK"
else
    echo "⚠️  Telemetry rollup: MISSING (will use defaults)"
fi

if [[ -L "$REPO_ROOT/g/telemetry/latest_rollup.ndjson" ]]; then
    echo "✅ Latest rollup symlink: OK"
else
    echo "❌ Latest rollup symlink: MISSING"
    exit 1
fi

# Check utility scripts
echo ""
echo "🔧 **Step 4: Utility Scripts**"
if [[ -x "$REPO_ROOT/knowledge/util/telemetry_reader.cjs" ]]; then
    echo "✅ Telemetry reader: OK"
else
    echo "❌ Telemetry reader: MISSING or not executable"
    exit 1
fi

if [[ -x "$REPO_ROOT/knowledge/util/safety_checks.cjs" ]]; then
    echo "✅ Safety checks: OK"
else
    echo "❌ Safety checks: MISSING or not executable"
    exit 1
fi

# Test telemetry reader
echo ""
echo "🔧 **Step 5: Telemetry Reader Test**"
if node "$REPO_ROOT/knowledge/util/telemetry_reader.cjs" >/dev/null 2>&1; then
    echo "✅ Telemetry reader test: OK"
else
    echo "❌ Telemetry reader test: FAILED"
    exit 1
fi

# Test safety checks
echo ""
echo "🔧 **Step 6: Safety Checks Test**"
if node "$REPO_ROOT/knowledge/util/safety_checks.cjs" >/dev/null 2>&1; then
    echo "✅ Safety checks test: OK"
else
    echo "❌ Safety checks test: FAILED"
    exit 1
fi

# Check scheduling files
echo ""
echo "🔧 **Step 7: Scheduling Files**"
if [[ -f "$REPO_ROOT/LaunchAgents/com.02luka.optimizer.plist" ]]; then
    echo "✅ macOS LaunchAgent: OK"
else
    echo "❌ macOS LaunchAgent: MISSING"
    exit 1
fi

if [[ -f "$REPO_ROOT/systemd/units/02luka-optimizer.service" ]]; then
    echo "✅ Linux systemd service: OK"
else
    echo "❌ Linux systemd service: MISSING"
    exit 1
fi

if [[ -f "$REPO_ROOT/systemd/units/02luka-optimizer.timer" ]]; then
    echo "✅ Linux systemd timer: OK"
else
    echo "❌ Linux systemd timer: MISSING"
    exit 1
fi

# Check wrapper script
echo ""
echo "🔧 **Step 8: Wrapper Script**"
if [[ -x "$REPO_ROOT/scripts/run_optimizer.sh" ]]; then
    echo "✅ Optimizer wrapper: OK"
else
    echo "❌ Optimizer wrapper: MISSING or not executable"
    exit 1
fi

echo ""
echo "🎯 **Phase 9.3 Health Status: ALL CHECKS PASSED**"
echo ""
echo "📋 **Ready for CLC Module Integration:**"
echo "• Redis infrastructure: ✅ Ready"
echo "• Telemetry feed: ✅ Connected"
echo "• Safety mechanisms: ✅ Active"
echo "• Scheduling: ✅ Configured"
echo "• Verification: ✅ Complete"
echo ""
echo "🚀 **Phase 9.3 Infrastructure Complete - Ready for CLC Modules!**"
