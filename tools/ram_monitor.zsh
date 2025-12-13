#!/usr/bin/env zsh
# RAM Monitor - Auto-cleanup when memory pressure is high
# Runs every 5 minutes via LaunchAgent

# 1. Critical: Safety flags
set -euo pipefail

# 2. Critical: Absolute paths
REPO_ROOT="/Users/icmini/02luka"
CLEANER_SCRIPT="${REPO_ROOT}/tools/mole_headless_clean.zsh"
LOG_PREFIX="[$(date '+%Y-%m-%d %H:%M:%S')]"

# Function for simpler logging
log() {
    echo "${LOG_PREFIX} $*"
}

# 4. Check dependency
if [[ ! -x "$CLEANER_SCRIPT" ]]; then
    log "❌ Configured cleaner script not found or not executable: $CLEANER_SCRIPT"
    exit 1
fi

# Get memory pressure percentage
# Using full path for system commands where possible, though basic ones are usually in PATH
PRESSURE=$(/usr/bin/memory_pressure | grep "percentage" | awk '{print $NF}' | tr -d '%')

# 3. Critical: Numeric validation
if [[ ! "$PRESSURE" =~ ^[0-9]+$ ]]; then
    log "❌ Invalid memory pressure reading: '$PRESSURE'"
    exit 1
fi

log "📊 Memory pressure: ${PRESSURE}%"

# 5. Simplify logic with elif
# === LEVEL 1: Normal (0-75%) ===
if (( PRESSURE <= 75 )); then
    # Do nothing - all good
    exit 0

# === LEVEL 2: Warning (76-84%) ===
elif (( PRESSURE >= 76 && PRESSURE <= 84 )); then
    log "⚠️ Memory pressure elevated: ${PRESSURE}%"
    exit 0

# === LEVEL 3: Cleanup (85-94%) ===
elif (( PRESSURE >= 85 && PRESSURE <= 94 )); then
    log "🧹 High memory pressure: ${PRESSURE}% - Running cleanup"
    
    # 6. Add timeout (limits execution to 60 seconds)
    # 7. Check if command succeeded
    if /usr/bin/timeout 60 "$CLEANER_SCRIPT" >/dev/null 2>&1; then
        # Check result
        PRESSURE_AFTER=$(/usr/bin/memory_pressure | grep "percentage" | awk '{print $NF}' | tr -d '%')
        log "✅ Cleanup completed. Pressure now: ${PRESSURE_AFTER}%"
    else
        log "⚠️ Cleanup script failed or timed out"
    fi
    
    exit 0

# === LEVEL 4: Emergency (95-100%) ===
elif (( PRESSURE >= 95 )); then
    log "🚨 CRITICAL memory pressure: ${PRESSURE}% - Emergency cleanup!"
    
    # Try sudo purge (if passwordless sudo configured)
    # Using timeout even for purge just in case
    if /usr/bin/timeout 10 sudo -n purge >/dev/null 2>&1; then
        log "✅ Emergency purge completed"
    else
        # Fallback: aggressive cleanup without sudo
        log "⚠️ Sudo purge failed/skipped, running cleaner + aggressive fallback"
        
        /usr/bin/timeout 60 "$CLEANER_SCRIPT" >/dev/null 2>&1 || true
        
        # 6. Safer glob usage for cache cleanup
        # Only delete specific cache types if they exist
        for cache_db in "$HOME/Library/Caches/"*"/Cache.db"* ; do
             [[ -f "$cache_db" ]] && rm -f "$cache_db" 2>/dev/null || true
        done
        
        # More targeted deep clean
        # rm -rf ~/Library/Caches/*/*/Cache/* could be risky if struct differs
        # Proceeding with caution using find to avoid empty globs issues
        find "$HOME/Library/Caches" -mindepth 3 -maxdepth 4 -name "Cache" -type d -exec rm -rf {} + 2>/dev/null || true
    fi
    
    # Check result
    PRESSURE_AFTER=$(/usr/bin/memory_pressure | grep "percentage" | awk '{print $NF}' | tr -d '%')
    log "✅ Emergency cleanup completed. Pressure now: ${PRESSURE_AFTER}%"
    
    exit 0
fi
