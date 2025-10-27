# macOS LaunchAgent Deployment Guide

## Overview
This guide explains how to deploy the `com.02luka.digest` LaunchAgent for automated daily digest generation.

## Prerequisites
- macOS system
- Node.js installed (`/usr/local/bin/node`)
- 02luka project in `~/02luka/`
- LaunchAgent plist file: `LaunchAgents/com.02luka.digest.plist`

## Quick Deployment

### Option 1: Automated Script
```bash
# Run the deployment script
./scripts/deploy_macos_launchagent.sh
```

### Option 2: Manual Deployment
```bash
# 1. Create LaunchAgents directory
mkdir -p ~/Library/LaunchAgents

# 2. Stop existing LaunchAgent (if any)
launchctl unload ~/Library/LaunchAgents/com.02luka.digest.plist 2>/dev/null || true

# 3. Copy plist file
cp LaunchAgents/com.02luka.digest.plist ~/Library/LaunchAgents/

# 4. Set permissions
chmod 644 ~/Library/LaunchAgents/com.02luka.digest.plist

# 5. Load LaunchAgent
launchctl load ~/Library/LaunchAgents/com.02luka.digest.plist
```

## Verification

### Check Status
```bash
# List all LaunchAgents
launchctl list | grep com.02luka.digest

# Check specific LaunchAgent
launchctl list com.02luka.digest
```

### Manual Testing
```bash
# Run manually
launchctl start com.02luka.digest

# Check logs
tail -f ~/02luka/g/logs/digest.out
tail -f ~/02luka/g/logs/digest.err
```

## Configuration

### LaunchAgent Settings
- **Label:** `com.02luka.digest`
- **Schedule:** Daily at 09:00
- **Script:** `~/02luka/g/tools/services/daily_digest.cjs --since 24h`
- **Logs:** `~/02luka/g/logs/digest.{out,err}`
- **RunAtLoad:** `true`

### Path Resolution
The LaunchAgent uses home-relative paths (`~/02luka/`) to ensure compatibility across different user accounts and systems.

## Troubleshooting

### Common Issues

1. **LaunchAgent not loading**
   ```bash
   # Check plist syntax
   plutil -lint ~/Library/LaunchAgents/com.02luka.digest.plist
   
   # Check permissions
   ls -la ~/Library/LaunchAgents/com.02luka.digest.plist
   ```

2. **Script not found**
   ```bash
   # Verify script exists
   ls -la ~/02luka/g/tools/services/daily_digest.cjs
   
   # Test script manually
   node ~/02luka/g/tools/services/daily_digest.cjs --since 24h
   ```

3. **Log files not created**
   ```bash
   # Check log directory
   ls -la ~/02luka/g/logs/
   
   # Create log directory if missing
   mkdir -p ~/02luka/g/logs/
   ```

### Uninstalling
```bash
# Stop and unload LaunchAgent
launchctl unload ~/Library/LaunchAgents/com.02luka.digest.plist

# Remove plist file
rm ~/Library/LaunchAgents/com.02luka.digest.plist
```

## Files Created
- `~/Library/LaunchAgents/com.02luka.digest.plist` - LaunchAgent configuration
- `~/02luka/g/logs/digest.out` - Standard output log
- `~/02luka/g/logs/digest.err` - Error log
- `~/02luka/g/reports/daily_digest_YYYYMMDD.md` - Daily digest reports

## Security Notes
- LaunchAgent runs with user privileges
- Uses home-relative paths for portability
- Logs are stored in project directory
- No system-level permissions required
