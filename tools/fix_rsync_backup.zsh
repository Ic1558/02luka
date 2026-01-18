#!/usr/bin/env zsh
set -euo pipefail

# Fix rsync LaunchAgent and verify backup system
# Fixes path mismatch: ~/02luka/g/tools/nas_backup.zsh → ~/02luka/tools/nas_backup.zsh

REPO="$HOME/02luka"
PLIST="$HOME/Library/LaunchAgents/com.02luka.nas_backup_daily.plist"
BACKUP_SCRIPT="$REPO/tools/nas_backup.zsh"
LOG_DIR="$REPO/logs"

ts() { date +"%Y-%m-%d %H:%M:%S"; }
log() { echo "[$(ts)] $*"; }

log "=== Fixing rsync Backup LaunchAgent ==="

# Step 1: Verify backup script exists
if [[ ! -f "$BACKUP_SCRIPT" ]]; then
    log "❌ ERROR: Backup script not found at $BACKUP_SCRIPT"
    exit 1
fi
log "✅ Backup script exists: $BACKUP_SCRIPT"

# Step 2: Create logs directory if missing
if [[ ! -d "$LOG_DIR" ]]; then
    log "Creating logs directory: $LOG_DIR"
    mkdir -p "$LOG_DIR"
fi
log "✅ Logs directory ready: $LOG_DIR"

# Step 3: Backup current plist
if [[ -f "$PLIST" ]]; then
    BACKUP_PLIST="${PLIST}.backup_$(date +%Y%m%d_%H%M%S)"
    log "Backing up current plist to: $BACKUP_PLIST"
    cp "$PLIST" "$BACKUP_PLIST"
    log "✅ Plist backed up"
else
    log "⚠️  No existing plist found, will create new one"
fi

# Step 4: Create corrected plist with absolute paths
log "Creating corrected LaunchAgent plist..."
cat > "$PLIST" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>com.02luka.nas_backup_daily</string>
	<key>ProgramArguments</key>
	<array>
		<string>/bin/zsh</string>
		<string>-lc</string>
		<string>~/02luka/tools/nas_backup.zsh</string>
	</array>
	<key>RunAtLoad</key>
	<false/>
	<key>StandardErrorPath</key>
	<string>~/02luka/logs/nas_backup.err.log</string>
	<key>StandardOutPath</key>
	<string>~/02luka/logs/nas_backup.out.log</string>
	<key>StartCalendarInterval</key>
	<dict>
		<key>Hour</key>
		<integer>2</integer>
		<key>Minute</key>
		<integer>0</integer>
	</dict>
</dict>
</plist>
EOF

log "✅ Plist created with correct path: ~/02luka/tools/nas_backup.zsh"

# Step 5: Reload LaunchAgent
log "Unloading old LaunchAgent..."
launchctl unload "$PLIST" 2>/dev/null || log "  (was not loaded)"

log "Loading new LaunchAgent..."
launchctl load "$PLIST"

# Verify it's loaded
if launchctl list | grep -q "com.02luka.nas_backup_daily"; then
    log "✅ LaunchAgent loaded successfully"
else
    log "❌ ERROR: LaunchAgent failed to load"
    exit 1
fi

# Step 6: Test backup manually
log ""
log "=== Testing Backup Manually ==="
log "Running: $BACKUP_SCRIPT"
log ""

# Check if backup volumes are available
VOLUMES_AVAILABLE=0
for vol in "/Volumes/lukadata" "/Volumes/Past Works"; do
    if [[ -d "$vol" ]]; then
        log "✅ Backup volume available: $vol"
        VOLUMES_AVAILABLE=1
    fi
done

if (( VOLUMES_AVAILABLE == 0 )); then
    log "⚠️  WARNING: No backup volumes mounted!"
    log "Available volumes:"
    ls -1 /Volumes/ | grep -v "Macintosh HD" | sed 's/^/  - /'
    log ""
    log "Skipping manual test - no destination available"
    log "LaunchAgent will attempt backup when volumes are mounted"
    exit 0
fi

# Run backup in dry-run mode first
log "Running dry-run test..."
if DRY_RUN=1 zsh "$BACKUP_SCRIPT"; then
    log "✅ Dry-run test passed"
else
    log "❌ Dry-run test failed (exit $?)"
    log "Check logs:"
    log "  - $LOG_DIR/nas_backup.log"
    log "  - $LOG_DIR/nas_backup.err.log"
    exit 1
fi

# Ask user if they want to run actual backup now
log ""
log "=== Fix Complete ==="
log ""
log "LaunchAgent Status:"
log "  Label: com.02luka.nas_backup_daily"
log "  Schedule: Daily at 2:00 AM"
log "  Script: $BACKUP_SCRIPT"
log "  Logs: $LOG_DIR/nas_backup*.log"
log ""
log "To run backup manually now:"
log "  zsh $BACKUP_SCRIPT"
log ""
log "To check scheduled runs:"
log "  launchctl list | grep nas_backup"
log "  cat $LOG_DIR/nas_backup.log"
log ""
