#!/usr/bin/env zsh
# RAM Monitor - Auto-cleanup when memory pressure is high
# Runs every 5 minutes via LaunchAgent

# Get memory pressure percentage
PRESSURE=$(memory_pressure | grep "percentage" | awk '{print $NF}' | tr -d '%')

# Safety: Exit if can't read pressure
if [[ -z "$PRESSURE" ]]; then
    echo "[$(date)] ❌ Cannot read memory pressure"
    exit 1
fi

# Log current status (always)
echo "[$(date)] 📊 Memory pressure: ${PRESSURE}%"

# === LEVEL 1: Normal (0-75%) ===
if (( PRESSURE <= 75 )); then
    # Do nothing - all good
    exit 0
fi

# === LEVEL 2: Warning (76-84%) ===
if (( PRESSURE >= 76 && PRESSURE <= 84 )); then
    echo "[$(date)] ⚠️ Memory pressure elevated: ${PRESSURE}%"
    # Just log, no cleanup yet
    exit 0
fi

# === LEVEL 3: Cleanup (85-94%) ===
if (( PRESSURE >= 85 && PRESSURE <= 94 )); then
    echo "[$(date)] 🧹 High memory pressure: ${PRESSURE}% - Running cleanup"
    
    # Run ram-cc (gentle cleanup, no sudo)
    ~/02luka/tools/ram_cleanup_fast.zsh > /dev/null 2>&1
    
    # Wait 2 seconds for cleanup to complete
    sleep 2
    
    # Check result
    PRESSURE_AFTER=$(memory_pressure | grep "percentage" | awk '{print $NF}' | tr -d '%')
    echo "[$(date)] ✅ Cleanup completed. Pressure now: ${PRESSURE_AFTER}%"
    
    exit 0
fi

# === LEVEL 4: Emergency (95-100%) ===
if (( PRESSURE >= 95 )); then
    echo "[$(date)] 🚨 CRITICAL memory pressure: ${PRESSURE}% - Emergency cleanup!"
    
    # Try sudo purge (if passwordless sudo configured)
    if sudo -n purge 2>/dev/null; then
        echo "[$(date)] ✅ Emergency purge completed"
    else
        # Fallback: aggressive cleanup without sudo
        echo "[$(date)] ⚠️ Sudo purge failed, using aggressive fallback"
        ~/02luka/tools/ram_cleanup_fast.zsh > /dev/null 2>&1
        rm -rf ~/Library/Caches/*/Cache.db* 2>/dev/null
        rm -rf ~/Library/Caches/*/*/Cache/* 2>/dev/null
    fi
    
    # Check result
    PRESSURE_AFTER=$(memory_pressure | grep "percentage" | awk '{print $NF}' | tr -d '%')
    echo "[$(date)] ✅ Emergency cleanup completed. Pressure now: ${PRESSURE_AFTER}%"
    
    exit 0
fi
