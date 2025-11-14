# Agent Heartbeat Map & Auto-Alert

**Phase 21.3** - Real-time monitoring and alerting for agent heartbeats via Redis pub/sub.

## Overview

This system collects heartbeats from agents (Mary, Lisa, Paula, Hybrid) via Redis pub/sub channels and monitors their status. It automatically sends Telegram alerts when an agent has been offline for more than 300 seconds (5 minutes).

## Architecture

```
Agents → Redis Pub/Sub → Heartbeat Monitor → Status Map + Telegram Alerts
  ↓                           ↓                      ↓
Mary                    Subscribe to           hub/agent_heartbeat.json
Lisa                    heartbeat channels     + Alert notifications
Paula
Hybrid
```

## Components

### 1. Agent Heartbeat Monitor (`agent_heartbeat.mjs`)

Node.js service that:
- Subscribes to Redis channels: `agents:heartbeat:{mary,lisa,paula,hybrid}`
- Tracks last heartbeat timestamp for each agent
- Checks agent status every 60 seconds
- Sends Telegram alerts if agent offline > 300s
- Generates `hub/agent_heartbeat.json` with current status

### 2. Heartbeat Schema (`config/schemas/agent_heartbeat.schema.json`)

JSON Schema defining the structure of the heartbeat map:
- `timestamp`: When the map was generated
- `agents`: Map of agent statuses (id, name, status, last_heartbeat, etc.)
- `alerts`: Array of active alerts for offline agents
- `summary`: Statistics (total, online, offline, unknown agents)

### 3. GitHub Workflow (`.github/workflows/agent-heartbeat.yml`)

Automated workflow that:
- Runs every 5 minutes via cron schedule
- Can be triggered manually via `workflow_dispatch`
- Can be triggered via `repository_dispatch` with type `agent:heartbeat`
- Validates heartbeat map against schema
- Uploads artifacts and generates job summary

## Configuration

### Environment Variables

```bash
# Redis connection
LUKA_REDIS_URL=redis://127.0.0.1:6379

# Telegram notifications
TELEGRAM_BOT_TOKEN=your_bot_token_here
TELEGRAM_CHAT_ID=your_chat_id_here
```

### Agent Configuration

Agents are defined in `hub/agent_heartbeat.mjs`:

```javascript
agents: [
  { id: 'mary', name: 'Mary', channel: 'agents:heartbeat:mary' },
  { id: 'lisa', name: 'Lisa', channel: 'agents:heartbeat:lisa' },
  { id: 'paula', name: 'Paula', channel: 'agents:heartbeat:paula' },
  { id: 'hybrid', name: 'Hybrid', channel: 'agents:heartbeat:hybrid' },
]
```

### Thresholds

- **Offline Threshold**: 300 seconds (5 minutes)
- **Check Interval**: 60 seconds (1 minute)
- **Alert Cooldown**: 30 minutes (prevents spam)

## Usage

### Running Locally

```bash
# Install dependencies
npm install redis

# Set environment variables
export LUKA_REDIS_URL="redis://127.0.0.1:6379"
export TELEGRAM_BOT_TOKEN="your_token"
export TELEGRAM_CHAT_ID="your_chat_id"

# Run the monitor
node hub/agent_heartbeat.mjs
```

### Sending Agent Heartbeats

Agents should publish heartbeats to their respective Redis channels:

```bash
# Example: Mary sends heartbeat
redis-cli PUBLISH "agents:heartbeat:mary" '{"status":"ok","timestamp":"2025-11-08T09:00:00Z"}'

# Example: Paula sends heartbeat with metadata
redis-cli PUBLISH "agents:heartbeat:paula" '{"status":"ok","signals_sent":42,"last_trade":"BTC/USDT"}'
```

### GitHub Actions Dispatch

```bash
# Trigger via repository_dispatch
curl -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  https://api.github.com/repos/OWNER/REPO/dispatches \
  -d '{"event_type":"agent:heartbeat"}'

# Manual workflow dispatch
gh workflow run agent-heartbeat.yml

# With custom duration
gh workflow run agent-heartbeat.yml -f duration=600

# Send test alert
gh workflow run agent-heartbeat.yml -f send_test_alert=true
```

## Output Format

### `hub/agent_heartbeat.json`

```json
{
  "timestamp": "2025-11-08T09:00:00.000Z",
  "agents": {
    "mary": {
      "id": "mary",
      "name": "Mary",
      "status": "online",
      "last_heartbeat": "2025-11-08T08:59:30.000Z",
      "seconds_since_heartbeat": 30,
      "channel": "agents:heartbeat:mary",
      "metadata": {}
    },
    "paula": {
      "id": "paula",
      "name": "Paula",
      "status": "offline",
      "last_heartbeat": "2025-11-08T08:45:00.000Z",
      "seconds_since_heartbeat": 900,
      "channel": "agents:heartbeat:paula",
      "metadata": {
        "signals_sent": 42
      }
    }
  },
  "alerts": [
    {
      "agent_id": "paula",
      "agent_name": "Paula",
      "seconds_offline": 900,
      "alert_time": "2025-11-08T09:00:00.000Z",
      "message": "Agent Paula offline for 900s"
    }
  ],
  "summary": {
    "total_agents": 4,
    "online_agents": 2,
    "offline_agents": 1,
    "unknown_agents": 1
  }
}
```

### Telegram Alert Format

```
🔴 *Agent Alert*

*Agent*: Paula (paula)
*Status*: Offline
*Last Heartbeat*: 2025-11-08T08:45:00.000Z
*Time Offline*: 900s (threshold: 300s)
*Time*: 2025-11-08T09:00:00.000Z
```

## Integration with Existing Infrastructure

### Redis Channels

The heartbeat system follows the existing Redis pub/sub patterns used by:
- `ci:events` (CI event coordinator)
- `gg:agent_router`, `gg:nlp_router` (agent routing)
- `kim:agent`, `telegram:agent` (agent messaging)

### Telegram Integration

Uses the same Telegram bot configuration as:
- Alertmanager (`config/alertmanager/alertmanager.yml`)
- Kim Telegram Bot (`agents/kim_bot/kim_telegram_bot.py`)

### Similar Monitoring

Follows patterns from:
- `run/ops_atomic_monitor.cjs` - 5-minute ops monitoring
- `tools/services/ops_health_watcher.cjs` - Health endpoint probing
- `g/metrics/cls_agent_heartbeat.json` - CLS agent heartbeat tracking

## Troubleshooting

### Redis Connection Issues

```bash
# Test Redis connectivity
redis-cli -h 127.0.0.1 -p 6379 ping

# Check if Redis is accepting connections
netstat -an | grep 6379
```

### No Heartbeats Received

```bash
# Monitor Redis channel
redis-cli SUBSCRIBE "agents:heartbeat:mary"

# Check if agents are publishing
redis-cli PUBSUB CHANNELS "agents:heartbeat:*"
```

### Telegram Alerts Not Sending

```bash
# Test Telegram bot
curl -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
  -d "chat_id=${TELEGRAM_CHAT_ID}" \
  -d "text=Test message"

# Check bot token is valid
curl "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getMe"
```

## Future Enhancements

- [ ] Web dashboard for real-time agent status
- [ ] Historical heartbeat data (time-series database)
- [ ] Multiple notification channels (Discord, Slack, Email)
- [ ] Agent performance metrics (response time, error rates)
- [ ] Auto-recovery actions for offline agents
- [ ] Heartbeat anomaly detection (ML-based)

## Related Files

- `config/schemas/agent_heartbeat.schema.json` - JSON Schema
- `.github/workflows/agent-heartbeat.yml` - GitHub Actions workflow
- `tools/ci/ci_coordinator.cjs` - CI event coordinator (reference)
- `run/ops_atomic_monitor.cjs` - Ops monitoring (reference)
- `config/alertmanager/alertmanager.yml` - Alertmanager config

## License

Part of the 02luka infrastructure - internal use only.
