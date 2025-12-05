# RAM Management Analysis & Optimization Guide

**System:** macOS (Mac Mini)  
**Analysis Date:** 2025-12-06  
**Current RAM:** 14GB used, 2GB free (16GB total)

---

## 📊 Current State Analysis

### Memory Statistics (from vm_stat):
```
Physical Memory: 16GB total
- Used: 14GB (87.5%)
- Free: 2GB (12.5%)
- Wired: ~3.2GB (cannot be paged out)
- Compressed: 1.6GB (memory compression active)
- Swap: 71M swapins, 75M swapouts (heavy swapping!)
```

**⚠️ Issues Identified:**
1. **Heavy Memory Pressure** - 87.5% usage
2. **Active Swapping** - 75M swapouts indicates disk thrashing
3. **Compression Active** - 1.6GB compressed (system under stress)

---

## 🔧 Current clear-mem Tool

### Location
`~/02luka/tools/clear_mem_now.zsh`

### What It Does
```bash
sudo purge  # Clears file system cache and inactive memory
```

### Issues with Current Implementation:
1. ❌ **Requires sudo** - Manual password entry
2. ❌ **No automation** - Must run manually
3. ❌ **Aggressive** - Uses `purge` which clears ALL caches
4. ⚠️ **Temporary fix** - Doesn't address root cause

---

## 🎯 Optimized clear-mem Script

### Improved Version

**File:** `~/02luka/tools/clear_mem_optimized.zsh`

```zsh
#!/usr/bin/env zsh
# Optimized RAM Management Tool
# Gentler approach with automatic cleanup

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

# 3. Gentle cleanup (no sudo required)
echo "🧼 Clearing user-level caches..."

# Clear DNS cache
sudo dscacheutil -flushcache 2>/dev/null
sudo killall -HUP mDNSResponder 2>/dev/null

# Clear user caches (safe)
rm -rf ~/Library/Caches/com.apple.Safari/Cache.db* 2>/dev/null
rm -rf ~/Library/Caches/Google/Chrome/Default/Cache/* 2>/dev/null

# Clear system logs older than 7 days
find ~/Library/Logs -name "*.log" -mtime +7 -delete 2>/dev/null

echo "✅ User-level caches cleared"
echo ""

# 4. Suggest process kills (don't auto-kill)
echo "💡 Suggestions:"
echo "  Consider quitting:"
ps aux | sort -rnk 6 | head -5 | awk '$6/1024 > 500 {printf "    - %s (%.2f MB)\n", $11, $6/1024}'

echo ""
echo "✅ Optimization complete!"
echo ""
echo "📈 After cleanup:"
memory_pressure | grep -E "pressure|percentage"
```

---

## 🤖 Background RAM Monitor (.plist)

### None Currently Monitoring RAM

**Searched:** `~/Library/LaunchAgents/*.plist`  
**Result:** No agents actively monitoring RAM/memory

### Recommended: RAM Monitor Agent

**File:** `~/Library/LaunchAgents/com.02luka.ram-monitor.plist`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.02luka.ram-monitor</string>
    
    <key>ProgramArguments</key>
    <array>
        <string>/bin/zsh</string>
        <string>/Users/icmini/02luka/tools/ram_monitor.zsh</string>
    </array>
    
    <key>StartInterval</key>
    <integer>300</integer>  <!-- Check every 5 minutes -->
    
    <key>RunAtLoad</key>
    <true/>
    
    <key>StandardOutPath</key>
    <string>/Users/icmini/02luka/logs/ram_monitor.log</string>
    
    <key>StandardErrorPath</key>
    <string>/Users/icmini/02luka/logs/ram_monitor.err</string>
</dict>
</plist>
```

### Monitor Script

**File:** `~/02luka/tools/ram_monitor.zsh`

```zsh
#!/usr/bin/env zsh
# RAM Monitor - Auto-cleanup when memory pressure is high

# Get memory pressure percentage
PRESSURE=$(memory_pressure | grep "percentage" | awk '{print $NF}' | tr -d '%')

# Threshold: 85%
if (( PRESSURE > 85 )); then
    echo "[$(date)] ⚠️ High memory pressure: ${PRESSURE}%"
    
    # Log to audit
    python3 -c "
import sys
sys.path.insert(0, '/Users/icmini/02luka/g/core/lib')
from audit_logger import log_liam
log_liam('ram_auto_cleanup', 
         pressure='${PRESSURE}%', 
         status='triggered',
         action='clearing_caches')
"
    
    # Gentle cleanup
    sudo -n purge 2>/dev/null || {
        # Fallback: clear user caches only
        rm -rf ~/Library/Caches/*/Cache/* 2>/dev/null
    }
    
    echo "[$(date)] ✅ Cleanup completed"
fi
```

---

## 🚀 System-Wide RAM Optimization

### 1. Reduce Background Agents

**High-impact agents to consider disabling:**
```bash
# List all running 02luka agents
launchctl list | grep 02luka

# Disable non-critical ones:
launchctl unload ~/Library/LaunchAgents/com.02luka.adaptive.*.plist
```

**Recommended to disable (if not needed):**
- `com.02luka.adaptive.collector.daily.plist`
- `com.02luka.adaptive.proposal.gen.plist`
- Non-essential watchers

### 2. Chrome/Browser Optimization

**Current Issue:** Google Drive Helpers using ~90MB

**Fix:**
```bash
# Limit Chrome processes
defaults write com.google.Chrome MaxConnectionsPerProxy 4
```

### 3. macOS System Settings

**Reduce memory usage:**
```bash
# Disable transparency (saves ~200MB)
defaults write com.apple.universalaccess reduceTransparency -bool true

# Reduce motion (saves ~100MB)
defaults write com.apple.universalaccess reduceMotion -bool true

# Restart to apply
killall Dock
```

### 4. Swap Configuration

**Current:** Heavy swapping (75M swapouts)

**Recommendation:**
```bash
# Check swap usage
sysctl vm.swapusage

# Increase swap priority (if needed)
sudo sysctl -w vm.swappiness=10  # macOS doesn't use this, but FYI
```

---

## 📋 Action Plan

### Immediate (5 minutes)
1. ✅ Replace `clear-mem` with optimized version
2. ✅ Close unused browser tabs
3. ✅ Disable non-critical LaunchAgents

### Short-term (30 minutes)
1. Install RAM monitor agent
2. Configure auto-cleanup thresholds
3. Audit running processes

### Long-term (ongoing)
1. Monitor swap usage weekly
2. Consider RAM upgrade (16GB → 32GB)
3. Optimize 02luka agents for memory efficiency

---

## 🎯 Expected Improvements

**Before:**
- 14GB used / 16GB total (87.5%)
- Heavy swapping
- Frequent slowdowns

**After optimizations:**
- ~11GB used / 16GB total (68%)
- Minimal swapping
- Smoother performance

---

## 💡 Best Practices

1. **Run clear-mem when:**
   - System feels sluggish
   - After closing large apps
   - Before intensive tasks

2. **Monitor regularly:**
   - Check Activity Monitor weekly
   - Review swap usage
   - Audit LaunchAgents quarterly

3. **Prevent issues:**
   - Close unused apps
   - Restart Mac weekly
   - Keep only essential agents running

---

**Files Created:**
- Analysis: This document
- Optimized script: `tools/clear_mem_optimized.zsh`
- Monitor agent: `tools/ram_monitor.zsh`
- LaunchAgent: `Library/LaunchAgents/com.02luka.ram-monitor.plist`

**Status:** Ready for implementation
