# 02luka Opal Gateway

Bridge between Opal App (Mobile/Web) and 02luka Work Order System.

## Architecture

```
Opal App (Cloud) 
    ↓ HTTPS Webhook
Cloudflare Tunnel (gateway.theedges.work)
    ↓ Secure Bridge
Mac Mini:5000 (This Gateway)
    ↓ Save JSON
bridge/inbox/LIAM/*.json
    ↓ Watched by
02luka Agents (Liam, Trader, etc.)
```

## Features

- ✅ Receives Work Orders from Opal via webhook
- ✅ Validates relay key authentication (optional)
- ✅ Saves to bridge/inbox/LIAM for agent processing
- ✅ Supports all app modes: Expense, Trade, GuiAuto, Progress, DevTask, Estimation
- ✅ Handles attachments and notifications
- ✅ Full AP/IO v3.1 compatible logging

## Quick Start

### 1. Install Dependencies

```bash
cd ~/02luka/apps/opal_gateway
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

### 2. Start the Gateway

```bash
chmod +x start_gateway.sh
./start_gateway.sh
```

Or run directly:

```bash
python gateway.py
```

The server will start on `http://localhost:5000`

### 3. Test Locally

```bash
# Health check
curl http://localhost:5000/ping

# Test Work Order submission
curl -X POST http://localhost:5000/api/wo \
  -H "Content-Type: application/json" \
  -H "X-Relay-Key: YOUR_RELAY_KEY_HERE" \
  -d '{
    "wo_id": "WO-TEST-001",
    "app_mode": "Trade",
    "objective": "Test work order from curl",
    "priority": "medium",
    "lane": "trader"
  }'
```

## Cloudflare Tunnel Setup

### Option A: Using existing tunnel

Add to your `~/.cloudflared/config.yml`:

```yaml
ingress:
  - hostname: gateway.theedges.work
    service: http://localhost:5000
  # ... other rules
  - service: http_status:404
```

Then reload:
```bash
cloudflared tunnel route dns <tunnel-name> gateway.theedges.work
```

### Option B: Quick test tunnel

```bash
cloudflared tunnel --url http://localhost:5000
```

This gives you a temporary URL like `https://random-name.trycloudflare.com`

## Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/` | Health check & service info |
| GET | `/ping` | Quick ping (returns `{"status":"ok"}`) |
| POST | `/api/wo` | **Main endpoint** - Receive Work Orders |
| GET | `/stats` | Gateway statistics & pending WOs |

## Security

The gateway supports optional authentication via `X-Relay-Key` header.

**Enable security:**
1. Ensure `RELAY_KEY` is set in `/Users/icmini/02luka/.env.local`
2. Gateway will automatically load it
3. All requests to `/api/wo` must include header: `X-Relay-Key: YOUR_KEY`

**Note:** If no `RELAY_KEY` is configured, the gateway runs in open mode (not recommended for production).

## Work Order Schema

Expected JSON from Opal:

```json
{
  "wo_id": "WO-Trade-ABC123",
  "app_mode": "Trade|Expense|GuiAuto|Progress|DevTask|Estimation",
  "objective": "User's request description",
  "priority": "low|medium|high|urgent",
  "lane": "trader|dev|clc|liam",
  
  "notify": {
    "telegram": true,
    "line": false
  },
  
  "execution": {
    "mode": "trade_analysis|gui_automation|atg_pipeline|none",
    "target_app": "Excel|Browser|null",
    "requires_hybrid_agent": false
  },
  
  "trade_context": {
    "market": "SET50|Crypto",
    "timeframe": "H1|D1",
    "chart_screenshots": ["chart1.jpg"]
  },
  
  "expense": { /* ... */ },
  "progress": { /* ... */ },
  "attachments": { /* ... */ },
  "apio_log": { /* ... */ }
}
```

## Monitoring

**Check gateway logs:**
```bash
# If running in foreground, logs appear in terminal
# If running as service, check system logs
```

**Check pending work orders:**
```bash
ls -la ~/02luka/bridge/inbox/LIAM/
```

**Gateway stats:**
```bash
curl http://localhost:5000/stats
```

## Running as Background Service (macOS)

Create LaunchAgent at `~/Library/LaunchAgents/com.02luka.opal-gateway.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.02luka.opal-gateway</string>
    
    <key>ProgramArguments</key>
    <array>
        <string>/Users/icmini/02luka/apps/opal_gateway/.venv/bin/python</string>
        <string>/Users/icmini/02luka/apps/opal_gateway/gateway.py</string>
    </array>
    
    <key>WorkingDirectory</key>
    <string>/Users/icmini/02luka/apps/opal_gateway</string>
    
    <key>RunAtLoad</key>
    <true/>
    
    <key>KeepAlive</key>
    <true/>
    
    <key>StandardOutPath</key>
    <string>/Users/icmini/02luka/logs/opal_gateway.log</string>
    
    <key>StandardErrorPath</key>
    <string>/Users/icmini/02luka/logs/opal_gateway.err</string>
</dict>
</plist>
```

Load the service:
```bash
launchctl load ~/Library/LaunchAgents/com.02luka.opal-gateway.plist
```

## Troubleshooting

**Gateway won't start:**
- Check Python version: `python3 --version` (need 3.8+)
- Check port 5000 not in use: `lsof -i :5000`
- Check dependencies installed: `pip list | grep flask`

**Work Orders not appearing in inbox:**
- Check inbox exists: `ls -la ~/02luka/bridge/inbox/LIAM/`
- Check file permissions
- Watch gateway logs for errors

**401 Unauthorized:**
- Check `X-Relay-Key` header matches `.env.local`
- Verify Opal is sending the correct header

## Next Steps

After gateway is running:

1. **Configure Cloudflare Tunnel** to expose `localhost:5000`
2. **Update Opal Flow** with the public webhook URL
3. **Test end-to-end** by submitting a work order from Opal
4. **Monitor** `bridge/inbox/LIAM/` for arriving work orders
5. **Verify** agents pick up and process the work orders

---

**Version:** 1.0.0  
**Last Updated:** 2025-12-05  
**Maintainer:** 02luka System
