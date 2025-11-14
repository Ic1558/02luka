# Alertmanager → Telegram Integration Manual

## Overview

Complete guide for Prometheus Alertmanager with Telegram notifications, including installation, configuration, management tools, and troubleshooting.

## Architecture

```
Prometheus (9090) → Alertmanager (9093) → Telegram Bot API
                ↑                    ↑
           BossAPI Rules      Template Expansion Wrapper
```

**Components:**
- **Prometheus**: Scrapes metrics from Boss API, evaluates alert rules
- **Alertmanager**: Receives alerts, groups/deduplicates, sends to Telegram
- **Wrapper Script**: Expands config template with secrets from `.env/alerts`
- **am_ctl.zsh**: CLI tool for managing alerts and silences

## Installation

### Prerequisites
- Prometheus running and configured (`config/prometheus/prometheus.yml`)
- Telegram bot created (get `bot_token` from @BotFather)
- Telegram chat ID (send message to bot, get from `https://api.telegram.org/bot<TOKEN>/getUpdates`)

### Files Created
```
~/bin/
├── alertmanager              # Binary v0.27.0 (darwin-arm64)
├── amtool                    # Alert management CLI
└── alertmanager_wrapper.zsh  # Startup wrapper with secret loading

g/
├── config/alertmanager/
│   └── alertmanager.yml      # Template config (tracked in git)
├── data/alertmanager/        # Runtime data (git-ignored)
│   ├── alertmanager_runtime.yml  # Expanded config with secrets
│   └── nlog/                 # Alert state database
├── .env/
│   └── alerts                # Secrets file (git-ignored)
└── tools/
    └── am_ctl.zsh            # Management shortcuts

~/Library/LaunchAgents/
└── com.02luka.alertmanager.plist  # macOS service definition
```

### Quick Install
```bash
export LUKA_HOME=/Users/icmini/LocalProjects/02luka_local_g/g
zsh /tmp/wire_alertmanager_fixed.zsh
```

## Configuration

### 1. Fill Telegram Credentials

Edit `g/.env/alerts`:
```bash
TELEGRAM_BOT_TOKEN=123456789:ABCdefGHIjklMNOpqrsTUVwxyz12345678
TELEGRAM_CHAT_ID=-1001234567890
```

**Important**: `TELEGRAM_CHAT_ID` must be a numeric ID (not @username)

### 2. Reload Alertmanager
```bash
launchctl kickstart gui/$(id -u)/com.02luka.alertmanager
```

### 3. Verify Service
```bash
# Check service is running
launchctl list | grep alertmanager

# Check API health
curl http://127.0.0.1:9093/api/v2/status | jq '.'

# View recent logs
tail -20 ~/02luka/logs/agent/alertmanager.err
```

## Alert Rules

Example rule in `config/prometheus/rules/bossapi.rules.yml`:
```yaml
groups:
  - name: bossapi_alerts
    interval: 30s
    rules:
      - alert: BossApiDown
        expr: up{job="bossapi"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Boss API is down"
          description: "Boss API has been unreachable for > 1 minute"
```

## Management Commands

### Using am_ctl.zsh

```bash
export LUKA_HOME=/Users/icmini/LocalProjects/02luka_local_g/g

# View all active alerts
g/tools/am_ctl.zsh alerts

# Silence all alerts for 1 hour
g/tools/am_ctl.zsh silence 1h

# Silence specific alerts
g/tools/am_ctl.zsh silence-by alertname=BossApiDown 30m

# List active silences
g/tools/am_ctl.zsh silences

# Remove a silence
g/tools/am_ctl.zsh unsilence <silence-id>

# Health check
g/tools/am_ctl.zsh check

# Show usage
g/tools/am_ctl.zsh
```

### Using amtool directly

```bash
# Query alerts
~/bin/amtool --alertmanager.url=http://127.0.0.1:9093 alert query

# Add silence
~/bin/amtool --alertmanager.url=http://127.0.0.1:9093 silence add \
  --duration=1h \
  --author="admin" \
  --comment="Maintenance window" \
  alertname=BossApiDown

# Expire silence
~/bin/amtool --alertmanager.url=http://127.0.0.1:9093 silence expire <id>

# Query silences
~/bin/amtool --alertmanager.url=http://127.0.0.1:9093 silence query

# Check config
~/bin/amtool --alertmanager.url=http://127.0.0.1:9093 config
```

## Telegram Message Format

Alerts arrive in Telegram with this format:
```
🔔 FIRING: BossApiDown
Job: bossapi
Instance: 127.0.0.1:4100
Severity: critical
Summary: Boss API is down
Description: Boss API has been unreachable for > 1 minute
Started: 2025-10-31T23:15:00Z
Link: http://localhost:9093
```

When resolved:
```
🔔 RESOLVED: BossApiDown
[same fields...]
```

## Troubleshooting

### Check Service Status
```bash
# Is LaunchAgent loaded?
launchctl list | grep alertmanager
# Output: -  1  com.02luka.alertmanager
#         ^  ^  ^
#         |  |  └─ Label
#         |  └──── Exit code (last exit)
#         └─────── PID (or - if not running)

# View logs
tail -50 ~/02luka/logs/agent/alertmanager.err
tail -50 ~/02luka/logs/agent/alertmanager.out
```

###Common Errors

**"missing bot_token"**
- **Cause**: Empty or invalid `TELEGRAM_BOT_TOKEN` in `g/.env/alerts`
- **Fix**: Fill valid bot token, reload service

**"chat not found"**
- **Cause**: Invalid `TELEGRAM_CHAT_ID`
- **Fix**: Verify chat ID is numeric (not @username), reload service

**"read-only file system"**
- **Cause**: Alertmanager tried to create data/ in wrong directory
- **Fix**: Already fixed by `--storage.path` flag in wrapper

**"unknown long flag '--config.expand-env'"**
- **Cause**: Alertmanager v0.27.0 doesn't support this flag
- **Fix**: Already fixed by template expansion in wrapper script

### Manual Restart
```bash
# Unload service
launchctl unload ~/Library/LaunchAgents/com.02luka.alertmanager.plist

# Load service
launchctl load ~/Library/LaunchAgents/com.02luka.alertmanager.plist

# Or force restart
launchctl kickstart -k gui/$(id -u)/com.02luka.alertmanager
```

### Testing Alerts

Test by stopping Boss API:
```bash
# Stop Boss API (triggers BossApiDown alert)
launchctl stop com.02luka.bossapi

# Wait ~1 minute for alert to fire

# Check alert is active
g/tools/am_ctl.zsh alerts

# Restart Boss API
launchctl start com.02luka.bossapi
```

### Viewing Expanded Config
```bash
# View template (in git)
cat g/config/alertmanager/alertmanager.yml

# View expanded runtime config (has secrets)
cat g/data/alertmanager/alertmanager_runtime.yml
```

## Maintenance

### Updating Alertmanager
```bash
# Check current version
~/bin/alertmanager --version

# Download new version
VERSION="0.28.0"
ARCH="darwin-arm64"
cd /tmp
curl -fsSL "https://github.com/prometheus/alertmanager/releases/download/v${VERSION}/alertmanager-${VERSION}.${ARCH}.tar.gz" -o am.tar.gz
tar -xzf am.tar.gz
mv "alertmanager-${VERSION}.${ARCH}/alertmanager" ~/bin/
mv "alertmanager-${VERSION}.${ARCH}/amtool" ~/bin/

# Restart service
launchctl kickstart -k gui/$(id -u)/com.02luka.alertmanager
```

### Backup Configuration
```bash
# Backup config and state
tar -czf "~/02luka_backups/alertmanager_$(date +%y%m%d).tar.gz" \
  g/config/alertmanager/ \
  g/.env/alerts \
  g/data/alertmanager/
```

### Log Rotation
Logs are written to:
- `~/02luka/logs/agent/alertmanager.out`
- `~/02luka/logs/agent/alertmanager.err`

LaunchAgent automatically manages log files. For manual cleanup:
```bash
# Archive old logs
gzip ~/02luka/logs/agent/alertmanager.*.old

# Or truncate if too large
> ~/02luka/logs/agent/alertmanager.out
> ~/02luka/logs/agent/alertmanager.err
```

## Security Notes

1. **Secrets Protection**
   - `g/.env/alerts` is git-ignored
   - Runtime config (`alertmanager_runtime.yml`) is git-ignored
   - Template config (in git) uses placeholders, not real tokens

2. **Network Access**
   - Alertmanager binds to `127.0.0.1:9093` (localhost only)
   - Only accessible from local machine
   - Telegram outbound HTTPS (port 443) required

3. **File Permissions**
   ```bash
   chmod 600 g/.env/alerts
   chmod 700 g/data/alertmanager
   ```

## Integration with Other Services

### Prometheus Integration
Already configured in `config/prometheus/prometheus.yml`:
```yaml
alerting:
  alertmanagers:
    - static_configs:
        - targets: ['127.0.0.1:9093']
```

Prometheus will automatically send alerts to Alertmanager.

### Adding More Receivers
Edit template `g/config/alertmanager/alertmanager.yml`:
```yaml
receivers:
  - name: telegram_primary
    telegram_configs: [...]

  - name: slack_backup
    slack_configs:
      - api_url: '__SLACK_WEBHOOK_URL__'
```

Add corresponding env vars to `g/.env/alerts`:
```bash
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/...
```

## References

- [Alertmanager Documentation](https://prometheus.io/docs/alerting/latest/alertmanager/)
- [Telegram Bot API](https://core.telegram.org/bots/api)
- [amtool Guide](https://github.com/prometheus/alertmanager#amtool)
- [Alert Rules Best Practices](https://prometheus.io/docs/practices/alerting/)

## Quick Reference Card

```bash
# Service Management
launchctl list | grep alertmanager          # Check status
launchctl kickstart -k gui/$(id -u)/com.02luka.alertmanager  # Restart

# View Alerts
g/tools/am_ctl.zsh alerts                   # List active alerts
g/tools/am_ctl.zsh check                    # Health check

# Silence Management
g/tools/am_ctl.zsh silence 1h               # Silence all for 1 hour
g/tools/am_ctl.zsh silences                 # List silences
g/tools/am_ctl.zsh unsilence <id>           # Remove silence

# Logs
tail -f ~/02luka/logs/agent/alertmanager.err  # Watch logs

# Configuration
cat g/.env/alerts                           # View secrets (chmod 600)
cat g/config/alertmanager/alertmanager.yml  # View template
cat g/data/alertmanager/alertmanager_runtime.yml  # View expanded config
```

## Status

✅ Alertmanager installed (v0.27.0)
✅ LaunchAgent configured and running
✅ Template expansion working
✅ Prometheus integration complete
⏳ **Pending**: Fill Telegram credentials in `g/.env/alerts`
⏳ **Pending**: Test alert delivery

---

**Last Updated**: 2025-10-31
**Version**: 1.0.0
**Component**: Observability Stack
