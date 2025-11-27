#!/usr/bin/env zsh
# RAM Management Tool - Clear Memory Cache on macOS
# Location: ~/02luka/tools/clear_mem_now.zsh
# Usage: clear-mem (via alias) or ./clear_mem_now.zsh

set -e

echo "======================================"
echo "🧹 RAM Management Tool"
echo "======================================"
echo ""

# Function to format bytes to human readable
format_bytes() {
    local bytes=$1
    if [ $bytes -lt 1024 ]; then
        echo "${bytes}B"
    elif [ $bytes -lt 1048576 ]; then
        echo "$((bytes / 1024))KB"
    elif [ $bytes -lt 1073741824 ]; then
        echo "$((bytes / 1048576))MB"
    else
        echo "$((bytes / 1073741824))GB"
    fi
}

# Function to get memory stats
get_memory_stats() {
    echo "📊 Current Memory Status:"
    echo ""

    # Get detailed memory statistics
    vm_stat | head -10

    echo ""
    echo "💾 Memory Pressure:"
    memory_pressure

    echo ""
}

# Show memory before cleanup
echo "🔍 Before Cleanup:"
get_memory_stats

echo ""
echo "======================================"
echo "🚀 Clearing Memory Cache..."
echo "======================================"
echo ""

# Check if running with sudo
if [ "$EUID" -ne 0 ]; then
    echo "⚠️  This script requires sudo privileges to purge memory."
    echo "🔑 Running: sudo purge"
    echo ""

    # Run purge with sudo
    if sudo purge; then
        echo "✅ Memory cache cleared successfully!"
    else
        echo "❌ Failed to clear memory cache"
        exit 1
    fi
else
    # Already running as root
    if purge; then
        echo "✅ Memory cache cleared successfully!"
    else
        echo "❌ Failed to clear memory cache"
        exit 1
    fi
fi

# Wait a moment for system to stabilize
echo ""
echo "⏳ Waiting 2 seconds for system to stabilize..."
sleep 2

echo ""
echo "======================================"
echo "📈 After Cleanup:"
echo "======================================"
echo ""
get_memory_stats

echo ""
echo "======================================"
echo "✅ Memory Management Complete!"
echo "======================================"
echo ""
echo "💡 Tips:"
echo "   - Run this when system feels slow"
echo "   - Close unused applications for best results"
echo "   - Check Activity Monitor for memory hogs"
echo ""

