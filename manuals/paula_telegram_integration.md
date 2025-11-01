# Paula AI Trading Alerts → Telegram Integration

**Status:** ✅ Production Ready
**Date:** 2025-11-01
**Version:** 1.0

## Overview

Complete end-to-end integration that sends Paula AI trading signals to Telegram via Prometheus + Alertmanager monitoring stack.

```
Paula Signal → Pushgateway → Prometheus → Alert Rules → Alertmanager → Telegram
```

---

## Quick Start

### Send a Trading Signal

```bash
# BUY signal
paula buy 870 0.85 "Breakout above resistance" M30

# SELL signal
paula sell 792 0.90 "Breaking support level" H1

# FLAT (close position)
paula flat 830 0.75 "Neutral market conditions" M15
```

**Parameters:**
- `action`: buy | sell | flat
- `price`: Current price level
- `confidence`: 0.0 to 1.0 (0.6+ triggers alerts)
- `reason`: Description (use quotes, avoid < >)
- `timeframe`: Optional (default: M15)

---

## Architecture

### Components

| Component | Port | Purpose | Status |
|-----------|------|---------|--------|
| **Pushgateway** | 9091 | Receives trading signals | ✅ |
| **Prometheus** | 9090 | Scrapes metrics, evaluates rules | ✅ |
| **Alertmanager** | 9093 | Routes alerts to Telegram | ✅ |
| **Telegram Bot** | - | Trade Alert (@Ictrader_bot) | ✅ |

### Data Flow

1. **Paula sends signal** → `paula buy 870 0.85 "reason" M30`
2. **Pushgateway stores** → Metrics available at http://127.0.0.1:9091/metrics
3. **Prometheus scrapes** → Every 15 seconds
4. **Alert rules evaluate** → PaulaBuySignal fires if confidence > 0.6
5. **Alertmanager routes** → team="trading" → telegram_trading receiver
6. **Telegram delivers** → Message sent to chat 6351780525

---

## Configuration

### File Locations (Stable - Outside Google Drive)

```
~/bin/trading/
├── paula_signal.zsh      # Send Paula signals
├── push_price.zsh        # Push price metrics
└── push_account.zsh      # Push PnL/margin metrics

~/bin/
├── paula                 # Command wrapper
├── alertmanager_wrapper.zsh
└── pushgateway

~/.config/02luka/
├── alertmanager/
│   ├── alertmanager.yml           # Template
│   └── alertmanager_runtime.yml   # With credentials
└── secrets/
    └── telegram.env      # Bot tokens

~/.local/share/02luka/
├── alertmanager/         # Alert state
└── pushgateway/          # Metrics persistence
```

### Telegram Credentials

Located in `~/.config/02luka/secrets/telegram.env`:

```bash
# Trade Alert bot (@Ictrader_bot)
TRADE_BOT_TOKEN=7907375805:AAHRJqOYGuZUueBUdGpSklgOztao0LObPjY
CHAT_ID=6351780525

# Also available:
# GPT_ALERTS_BOT_TOKEN (02luka system alerts)
# EDGEWORK_BOT_TOKEN (work alerts)
# GGMESH_BOT_TOKEN (mesh network alerts)
```

### Alert Rules

Located in git: `config/prometheus/rules/trading.rules.yml`

**Active Rules:**

1. **PaulaBuySignal** - Fires when Paula sends BUY with confidence > 0.6
2. **PaulaSellSignal** - Fires when Paula sends SELL with confidence > 0.6
3. **PriceAboveLevel** - Price crosses above threshold
4. **PriceBelowLevel** - Price crosses below threshold
5. **DrawdownExceeded** - Net PnL drops too much
6. **MarginUsageHigh** - Margin usage > 70%
7. **PositionTooLarge** - Position size exceeds limit

---

## Usage Examples

### Basic Signal Sending

```bash
# Simple BUY
paula buy 850 0.78 "MA crossover" M15

# SELL with detailed reason
paula sell 792 0.85 "RSI overbought + bearish divergence" H1

# Close position (FLAT)
paula flat 825 0.65 "Taking profit" M30
```

### With Environment Variables

```bash
# Change symbol (default: SET50)
SYM=CRYPTO paula buy 42000 0.88 "Bitcoin breakout" H4

# Change Pushgateway URL
PG_URL=http://remote-host:9091 paula buy 870 0.80 "Remote signal"

# Change strategy name (default: paula_v1)
STRAT=paula_v2_experimental paula sell 795 0.92 "New strategy test"
```

### Push Additional Metrics

```bash
# Push current price
~/bin/trading/push_price.zsh 855

# Push account metrics (PnL, margin, position)
~/bin/trading/push_account.zsh -18000 75 8 SET50
# Args: net_pnl margin_pct position_size symbol
```

---

## Monitoring & Verification

### Check if Signal Reached Prometheus

```bash
# Query latest Paula signal
curl -s 'http://127.0.0.1:9090/api/v1/query?query=paula_signal' | jq -r '.data.result[] | "\(.metric.action) @ \(.metric.price)"'

# Check signal confidence
curl -s 'http://127.0.0.1:9090/api/v1/query?query=trading_signal_confidence' | jq '.data.result[0].value[1]'
```

### Check Active Alerts

```bash
# Prometheus alerts
curl -s 'http://127.0.0.1:9090/api/v1/alerts' | jq '.data.alerts[] | {name: .labels.alertname, state: .state}'

# Alertmanager alerts
curl -s 'http://127.0.0.1:9093/api/v2/alerts' | jq '.[] | {name: .labels.alertname, status: .status.state}'
```

### Check Telegram Delivery

```bash
# Check recent messages sent by bot
curl -s "https://api.telegram.org/bot7907375805:AAHRJqOYGuZUueBUdGpSklgOztao0LObPjY/getUpdates?offset=-5" | jq '.result[] | {message_id: .message.message_id, text: .message.text}'
```

### Check Service Health

```bash
# Pushgateway
curl -s http://127.0.0.1:9091/metrics | grep pushgateway_build_info

# Prometheus
curl -s http://127.0.0.1:9090/-/healthy

# Alertmanager
curl -s http://127.0.0.1:9093/-/healthy
```

---

## Troubleshooting

### Signal Not Appearing in Prometheus

```bash
# 1. Check if Pushgateway received it
curl -s http://127.0.0.1:9091/metrics | grep trading_signal

# 2. Check Prometheus scrape targets
curl -s http://127.0.0.1:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health}'

# 3. Verify Prometheus can reach Pushgateway
curl -s 'http://127.0.0.1:9090/api/v1/query?query=up{job="pushgateway"}'
```

### Alert Not Firing

```bash
# 1. Check alert rule evaluation
curl -s 'http://127.0.0.1:9090/api/v1/rules' | jq '.data.groups[] | select(.name=="trading") | .rules[] | {alert: .name, state: .state}'

# 2. Verify confidence threshold (must be > 0.6)
curl -s 'http://127.0.0.1:9090/api/v1/query?query=trading_signal_confidence' | jq '.data.result[0].value[1]'

# 3. Check if alert has labels team="trading"
curl -s 'http://127.0.0.1:9090/api/v1/alerts' | jq '.data.alerts[] | select(.labels.alertname | contains("Paula")) | .labels'
```

### Telegram Not Receiving Messages

```bash
# 1. Check Alertmanager config has bot token
grep "bot_token" ~/.config/02luka/alertmanager/alertmanager_runtime.yml

# 2. Test Telegram API directly
curl -X POST "https://api.telegram.org/bot7907375805:AAHRJqOYGuZUueBUdGpSklgOztao0LObPjY/sendMessage" \
  -d "chat_id=6351780525" \
  -d "text=Test from command line" \
  -d "parse_mode=HTML"

# 3. Check Alertmanager logs
tail -50 ~/02luka/logs/agent/alertmanager.err | grep -i telegram

# 4. Reload Alertmanager
launchctl stop com.02luka.alertmanager && sleep 2 && launchctl start com.02luka.alertmanager
```

### Services Not Running

```bash
# Check LaunchAgents
launchctl list | grep 02luka

# Start Pushgateway
launchctl load ~/Library/LaunchAgents/com.02luka.pushgateway.plist

# Start Prometheus (if you have it)
launchctl load ~/Library/LaunchAgents/com.02luka.prometheus.plist

# Start Alertmanager (should already be running)
launchctl list | grep alertmanager
```

---

## Alert Message Format

### Telegram Message Appearance

```
📈 Trading Alert
PaulaBuySignal
• Paula AI detected BUY signal at 870 — Confidence: 0.85 | Strategy: paula_v1 | Timeframe: M30 | Reason: Breakout_above_resistance
  labels: alertname=PaulaBuySignal, action=buy, price=870, confidence=0.85, symbol=SET50, team=trading, timeframe=M30, reason=Breakout_above_resistance
```

### Customizing Alert Templates

Edit `~/.config/02luka/alertmanager/alertmanager.yml` (template):

```yaml
receivers:
  - name: telegram_trading
    telegram_configs:
      - bot_token: '__TELEGRAM_BOT_TOKEN__'
        chat_id: __TELEGRAM_CHAT_ID__
        parse_mode: HTML
        message: |-
          <b>📈 Trading Alert</b>
          <b>{{ (index .Alerts 0).Labels.alertname }}</b>
          {{- range .Alerts }}
          • {{ .Annotations.summary }} — {{ .Annotations.desc }}
            <i>labels:</i> {{ .Labels }}
          {{- end }}
```

After editing, restart Alertmanager:
```bash
launchctl stop com.02luka.alertmanager && sleep 2 && launchctl start com.02luka.alertmanager
```

---

## Advanced Usage

### Testing Alert Pipeline

Send a test alert directly to Alertmanager:

```bash
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
END=$(date -u -v+30M +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d '+30 minutes' +%Y-%m-%dT%H:%M:%SZ)

curl -X POST 'http://127.0.0.1:9093/api/v2/alerts' -H 'Content-Type: application/json' -d "[
  {
    \"labels\": {
      \"alertname\": \"PaulaBuySignal\",
      \"team\": \"trading\",
      \"action\": \"buy\",
      \"symbol\": \"SET50\",
      \"price\": \"900\"
    },
    \"annotations\": {
      \"summary\": \"Test alert\",
      \"desc\": \"Manual test via API\"
    },
    \"startsAt\": \"$NOW\",
    \"endsAt\": \"$END\"
  }
]"
```

### Silencing Alerts

```bash
# Silence all Paula alerts for 1 hour
amtool --alertmanager.url=http://127.0.0.1:9093 silence add alertname=~"Paula.*" --duration=1h --comment="Testing"

# List active silences
amtool --alertmanager.url=http://127.0.0.1:9093 silence query

# Expire a silence
amtool --alertmanager.url=http://127.0.0.1:9093 silence expire <silence_id>
```

### Rate Limiting

Alerts are rate-limited by `repeat_interval`:
- trading team: 30 minutes (from alertmanager.yml)
- primary receiver: 3 hours

To change, edit `~/.config/02luka/alertmanager/alertmanager.yml` and restart.

---

## Security Notes

1. **Telegram Bot Token** is stored in `~/.config/02luka/secrets/telegram.env` with permissions 600
2. **Never commit** telegram.env to git (.gitignore it)
3. **Runtime config** with expanded secrets in `~/.config/02luka/alertmanager/alertmanager_runtime.yml`
4. **Template** without secrets in git at `config/alertmanager/alertmanager.yml`

---

## Maintenance

### Update Credentials

```bash
# Edit secrets file
vim ~/.config/02luka/secrets/telegram.env

# Restart Alertmanager to pick up changes
launchctl stop com.02luka.alertmanager && sleep 2 && launchctl start com.02luka.alertmanager

# Verify new credentials loaded
grep "bot_token" ~/.config/02luka/alertmanager/alertmanager_runtime.yml
```

### Backup Alertmanager State

```bash
# State is in ~/.local/share/02luka/alertmanager/
tar -czf ~/alertmanager_backup_$(date +%Y%m%d).tar.gz ~/.local/share/02luka/alertmanager/
```

### Logs

```bash
# Alertmanager
tail -f ~/02luka/logs/agent/alertmanager.err
tail -f ~/02luka/logs/agent/alertmanager.out

# Pushgateway
tail -f ~/02luka/logs/agent/pushgateway.err
tail -f ~/02luka/logs/agent/pushgateway.out
```

---

## Reference

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PG_URL` | http://127.0.0.1:9091 | Pushgateway URL |
| `SYM` | SET50 | Trading symbol |
| `STRAT` | paula_v1 | Strategy name |
| `TRADE_BOT_TOKEN` | (from secrets) | Telegram bot token |
| `CHAT_ID` | (from secrets) | Telegram chat ID |

### Service URLs

- Pushgateway: http://127.0.0.1:9091
- Prometheus: http://127.0.0.1:9090
- Alertmanager: http://127.0.0.1:9093
- Telegram API: https://api.telegram.org/bot{token}/

### Useful Links

- [Prometheus Alerting Rules](https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/)
- [Alertmanager Configuration](https://prometheus.io/docs/alerting/latest/configuration/)
- [Telegram Bot API](https://core.telegram.org/bots/api)
- [Pushgateway](https://github.com/prometheus/pushgateway)

---

## Change Log

**v1.0 - 2025-11-01**
- ✅ Initial production deployment
- ✅ Telegram integration verified end-to-end
- ✅ Stable file locations outside Google Drive
- ✅ LaunchAgent configurations for all services
- ✅ 7 trading alert rules active
- ✅ Trade Alert bot (@Ictrader_bot) configured

---

**Support:** For issues, check GitHub repo or logs in `~/02luka/logs/agent/`
