# CLC Local Controller

**tmux-based unified CLI for running Claude Code locally with remote control capability**

## Overview

`clc.zsh` provides a simple, unified interface for managing local CLC (Claude Code) sessions. It uses `tmux` for session persistence, logs all activity, integrates with your health monitoring stack, and supports remote control from mobile devices.

## Features

- ✅ **Single command** for start/stop/restart/status/attach/logs
- ✅ **tmux-based** - sessions survive network drops and reconnections
- ✅ **Auto-start** via LaunchAgent (starts on login, auto-restarts on crash)
- ✅ **Health checks** - integrates with `health_server` on :4000
- ✅ **Logging** - all CLC output captured to `~/02luka/logs/clc_local.log`
- ✅ **Mobile control** - via Tailscale + SSH or Happy Coder
- ✅ **Version-controlled** - script lives in repo, symlinked to `~/bin`

## Installation

### One-Time Setup

```bash
cd ~/LocalProjects/02luka_local_g/g
./tools/cli/install_clc_cli.zsh
```

This will:
1. Create `~/bin/` and `~/02luka/logs/` directories
2. Symlink `~/bin/clc.zsh` → `tools/cli/clc.zsh`
3. Install and load LaunchAgent (auto-start on login)
4. Verify the setup

### Manual Setup (if needed)

```bash
# 1. Create symlink
ln -s ~/LocalProjects/02luka_local_g/g/tools/cli/clc.zsh ~/bin/clc.zsh

# 2. Install LaunchAgent
cp ~/LocalProjects/02luka_local_g/g/LaunchAgents/com.02luka.clc.local.plist \
   ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.02luka.clc.local.plist

# 3. Create logs directory
mkdir -p ~/02luka/logs
```

## Usage

### Basic Commands

```bash
# Start CLC (with default: happy start-session)
clc start

# Stop CLC (sends Ctrl-C to tmux session)
clc stop

# Restart CLC
clc restart

# Show status (session, health_server, containers, logs)
clc status

# Attach to tmux session (interactive)
clc attach
# (Press Ctrl-B then D to detach)

# Watch logs in real-time
clc logs
```

### Custom Start Commands

```bash
# Start with a custom command
clc start "claude start-session"

# Override default via environment variable
CLC_CMD="node server.js" clc start

# Use different tmux session name
CLC_SESSION="DEV" clc start
```

### Environment Variables

All configuration can be overridden via environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `CLC_SESSION` | `CLC` | tmux session name |
| `CLC_REPO` | `~/LocalProjects/02luka_local_g/g` | Repository path |
| `CLC_LOG` | `~/02luka/logs/clc_local.log` | Log file path |
| `CLC_CMD` | `happy start-session` | Default start command |
| `CLC_HEALTH_URL` | `http://localhost:4000/ping` | Health check endpoint |

## Mobile Control

### Option 1: Tailscale + SSH (Recommended)

1. Install Tailscale on Mac and mobile device
2. Set up SSH key authentication
3. Use Termius (iOS) or any SSH client:

```bash
# From mobile SSH session
ssh your-mac
~/bin/clc.zsh status
~/bin/clc.zsh restart
~/bin/clc.zsh logs
```

### Option 2: iOS Shortcuts

Create Shortcuts that run:
```bash
ssh your-mac "~/bin/clc.zsh start"
ssh your-mac "~/bin/clc.zsh status"
```

### Option 3: Happy Coder Integration

If using Happy Coder (default):
- Mac runs the compute (local CLC)
- Phone is the controller/approver
- No additional setup needed - just start with `clc start`

## LaunchAgent (Auto-Start)

### Status

```bash
# Check if loaded
launchctl list | grep com.02luka.clc.local

# View logs
tail -f ~/02luka/logs/clc_local.out
tail -f ~/02luka/logs/clc_local.err
```

### Control

```bash
# Disable auto-start
launchctl unload ~/Library/LaunchAgents/com.02luka.clc.local.plist

# Enable auto-start
launchctl load ~/Library/LaunchAgents/com.02luka.clc.local.plist

# Restart LaunchAgent
launchctl unload ~/Library/LaunchAgents/com.02luka.clc.local.plist
launchctl load ~/Library/LaunchAgents/com.02luka.clc.local.plist
```

## Log Files

| File | Purpose |
|------|---------|
| `~/02luka/logs/clc_local.log` | CLC output (via `tee`) |
| `~/02luka/logs/clc_local.out` | LaunchAgent stdout |
| `~/02luka/logs/clc_local.err` | LaunchAgent stderr |

View all logs:
```bash
tail -f ~/02luka/logs/clc_local.*
```

## Troubleshooting

### CLC won't start

```bash
# Check tmux session exists
tmux list-sessions

# Check health_server is running
curl http://localhost:4000/ping

# Check logs for errors
clc logs
```

### LaunchAgent not starting

```bash
# Check if loaded
launchctl list | grep com.02luka.clc.local

# View LaunchAgent logs
tail -50 ~/02luka/logs/clc_local.err

# Reload LaunchAgent
launchctl unload ~/Library/LaunchAgents/com.02luka.clc.local.plist
launchctl load ~/Library/LaunchAgents/com.02luka.clc.local.plist
```

### Symlink broken

```bash
# Check symlink
ls -la ~/bin/clc.zsh

# Recreate if needed
ln -sf ~/LocalProjects/02luka_local_g/g/tools/cli/clc.zsh ~/bin/clc.zsh
```

### PATH not set

If `clc` command not found:

```bash
# Add to ~/.zshrc
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc

# Or use full path
~/bin/clc.zsh status

# Or create alias
echo 'alias clc="~/bin/clc.zsh"' >> ~/.zshrc
source ~/.zshrc
```

## Architecture

```
┌─────────────────┐
│   Mobile/SSH    │ ──► Control via Tailscale + SSH
└─────────────────┘
         │
         ▼
┌─────────────────┐
│  ~/bin/clc.zsh  │ ──► Symlink to repo version
│   (symlink)     │
└─────────────────┘
         │
         ▼
┌─────────────────┐
│ tools/cli/      │ ──► Version-controlled scripts
│  clc.zsh        │
│  install_*.zsh  │
│  README.md      │
└─────────────────┘
         │
         ▼
┌─────────────────┐
│  tmux session   │ ──► Persistent CLC process
│   name: "CLC"   │
└─────────────────┘
         │
         ▼
┌─────────────────┐
│ happy start-    │ ──► Default CLC command
│   session       │
└─────────────────┘
         │
         ▼
┌─────────────────┐
│ ~/02luka/logs/  │ ──► All output logged
│  clc_local.log  │
└─────────────────┘
```

## Examples

### Daily Use

```bash
# Morning: check if running (LaunchAgent should have started it)
clc status

# Attach to see what's happening
clc attach
# (Ctrl-B D to detach)

# Need to restart after code changes
clc restart

# Check logs for errors
clc logs
```

### Development Workflow

```bash
# Start with different session for testing
CLC_SESSION="DEV" CLC_CMD="node test.js" clc start

# Monitor both sessions
tmux list-sessions
clc status
CLC_SESSION="DEV" clc status

# Clean shutdown
clc stop
CLC_SESSION="DEV" clc stop
```

### Remote Monitoring

```bash
# From phone (via Tailscale SSH)
ssh mac-mini "~/bin/clc.zsh status"

# Restart if needed
ssh mac-mini "~/bin/clc.zsh restart"

# Tail logs
ssh mac-mini "~/bin/clc.zsh logs"
```

## Related

- **health_server**: See `tools/health/health_server.cjs`
- **Docker services**: See `compose/docker-compose.yml`
- **Status helper**: See `tools/status/health_check.zsh`
- **LaunchAgents**: See `LaunchAgents/` directory

## Version

Part of 02luka production infrastructure (2025-11-01+)
