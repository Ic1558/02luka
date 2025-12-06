#!/usr/bin/env zsh
# Fast RAM Cleanup - No Password Required
# Usage: ram-cc (via alias)

echo "🚀 Fast RAM Cleanup (no sudo)..."
echo ""

# 1. Get current memory pressure
echo "📊 Current Memory Status:"
memory_pressure | grep -E "pressure|percentage"
echo ""

# 2. Identify memory hogs (top 10 processes)
echo "🔍 Top Memory Consumers:"
ps aux | sort -rnk 6 | head -10 | awk '{printf "  %-30s %10.2f MB\n", $11, $6/1024}'
echo ""

# 3. Gentle cleanup (no sudo required)
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

echo "✅ Fast cleanup complete!"
echo ""
echo "📈 After cleanup:"
memory_pressure | grep -E "pressure|percentage"
echo ""
echo "💡 For deeper cleanup: use 'ram-c' (will ask for sudo)"
