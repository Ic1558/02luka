#!/usr/bin/env zsh
# RAM Monitoring Tool - Check Memory Usage on macOS
# Location: ~/02luka/tools/check_ram.zsh
# Usage: check-ram (via alias) or ./check_ram.zsh

echo "======================================"
echo "📊 RAM Monitoring Report"
echo "======================================"
echo ""

# System memory info
echo "💻 System Memory:"
sysctl hw.memsize | awk '{printf "   Total RAM: %.2f GB\n", $2/1073741824}'
echo ""

# Detailed VM statistics
echo "📈 Virtual Memory Statistics:"
vm_stat | perl -ne '/page size of (\d+)/ and $size=$1; /Pages\s+([^:]+)[^\d]+(\d+)/ and printf("   %-20s % 16.2f MB\n", "$1:", $2 * $size / 1048576);'
echo ""

# Memory pressure
echo "🎯 Memory Pressure:"
memory_pressure | tail -5
echo ""

# Active processes using most memory
echo "🔝 Top 10 Memory Consumers:"
ps aux | sort -rk 4,4 | head -11 | awk 'NR==1 {print "   "$4"  "$11} NR>1 {printf "   %-6s %s\n", $4"%", $11}'
echo ""

# Swap usage
echo "💱 Swap Usage:"
sysctl vm.swapusage | sed 's/vm.swapusage: /   /'
echo ""

echo "======================================"
echo "💡 Memory Management Commands:"
echo "======================================"
echo "   clear-mem   - Clear memory cache (requires sudo)"
echo "   check-ram   - Show this report"
echo ""

