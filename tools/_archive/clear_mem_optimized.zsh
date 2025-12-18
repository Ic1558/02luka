#!/usr/bin/env zsh
# ============================================================================
# LEGACY - This script is deprecated and archived
# Replaced by: tools/mole_headless_clean.zsh
# Archive Date: 2025-12-19
# Original Purpose: Optimized RAM Cleanup
# ============================================================================
# Optimized RAM Cleanup - Auto-generated restoration
# Usage: ram-c (via alias)

echo "🧹 RAM Optimization Started..."
echo ""

# 1. Get current memory pressure
echo "📊 Current Memory Status:"
memory_pressure | grep -E "pressure|percentage"
echo ""

# 2. Identify memory hogs (top 10 processes)
echo "🔍 Top Memory Consumers:"
ps aux | sort -rnk 6 | head -10 | awk '{printf "  %-30s %10.2f MB\n", $11, $6/1024}'
echo ""

# 3. Gentle cleanup (no sudo required by default)
echo "🧼 Clearing user-level caches..."

# Clear user caches (safe)
rm -rf ~/Library/Caches/com.apple.Safari/Cache.db* 2>/dev/null
rm -rf ~/Library/Caches/Google/Chrome/Default/Cache/* 2>/dev/null
rm -rf ~/Library/Caches/com.google.Chrome/Default/Cache/* 2>/dev/null

# Clear system logs older than 7 days
find ~/Library/Logs -name "*.log" -mtime +7 -delete 2>/dev/null

echo "✅ User-level caches cleared"
echo ""

# 4. Show high memory processes (don't auto-kill)
echo "💡 High Memory Processes:"
ps aux | sort -rnk 6 | head -5 | awk '$6/1024 > 500 {printf "    - %s (%.2f MB)\n", $11, $6/1024}'
echo ""
echo "   Consider quitting these apps if not needed"
echo ""

# 5. Optional sudo purge
echo "Clear system cache? (requires sudo) [y/N]: "
read -q response
echo ""

if [[ "$response" == "y" ]]; then
    echo "Running sudo purge..."
    sudo purge
    echo "✅ System cache cleared"
else
    echo "Skipped system cache (use 'y' next time for deep clean)"
fi

echo ""
echo "✅ Optimization complete!"
echo ""
echo "📈 After cleanup:"
memory_pressure | grep -E "pressure|percentage"
