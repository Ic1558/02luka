# Discord Integration

Lightweight webhook-based Discord notifications for 02LUKA.

## Features

✅ **Zero dependencies** - Uses Node.js native `https` module  
✅ **Multi-channel support** - Route notifications by channel name  
✅ **Level-based formatting** - Auto-emoji for info/warn/error  
✅ **Graceful degradation** - Optional service (won't break if unconfigured)

## Quick Start

### 1. Create Discord Webhook

1. Open your Discord server
2. Go to **Server Settings** → **Integrations** → **Webhooks**
3. Click **New Webhook**
4. Choose channel and copy webhook URL

### 2. Configure Environment Variables

**Option A: Single default webhook**
```bash
# .env
DISCORD_WEBHOOK_DEFAULT=https://discord.com/api/webhooks/123456789/abcdef...
```

**Option B: Multi-channel mapping**
```bash
# .env
DISCORD_WEBHOOK_DEFAULT=https://discord.com/api/webhooks/.../default
DISCORD_WEBHOOK_MAP={"alerts":"https://discord.com/api/webhooks/.../alerts","ops":"https://discord.com/api/webhooks/.../ops"}
```

### 3. Start API Server

```bash
cd boss-api
node server.cjs
```

### 4. Test Notification

```bash
curl -X POST http://127.0.0.1:4000/api/discord/notify \
  -H "Content-Type: application/json" \
  -d '{"content":"Test message","level":"info","channel":"default"}'
```

## API Reference

### POST /api/discord/notify

Send a notification to Discord.

**Request Body:**
```json
{
  "content": "Your message here",
  "level": "info",           // Optional: "info" | "warn" | "error" (default: "info")
  "channel": "default"       // Optional: channel name (default: "default")
}
```

**Response:**
- `200` - Message sent successfully
- `400` - Invalid request (missing `content`)
- `502` - Discord webhook delivery failed
- `503` - Webhook not configured

**Level Emojis:**
- `info` → ℹ️
- `warn` → ⚠️
- `error` → 🚨

### Channel Resolution

The API resolves webhook URLs in this order:

1. **Exact match** - `discordWebhookMap[channel]`
2. **Default fallback** - `discordWebhookMap.default`
3. **Global default** - `DISCORD_WEBHOOK_DEFAULT`

Example:
```javascript
// Request: {"channel": "alerts"}
// Tries: webhookMap["alerts"] → webhookMap["default"] → DISCORD_WEBHOOK_DEFAULT
```

## Programmatic Usage

### From Node.js

```javascript
const { postDiscordWebhook } = require('./agents/discord/webhook_relay.cjs');

const webhookUrl = 'https://discord.com/api/webhooks/...';
const payload = {
  content: 'Build completed successfully',
  allowed_mentions: { parse: [] }
};

try {
  await postDiscordWebhook(webhookUrl, payload);
  console.log('✅ Notification sent');
} catch (error) {
  console.error('❌ Failed:', error.message);
  if (error.statusCode) {
    console.error('Status:', error.statusCode);
  }
}
```

### From Shell Scripts

```bash
#!/bin/bash
WEBHOOK="$DISCORD_WEBHOOK_DEFAULT"
PAYLOAD='{"content":"Deployment complete","level":"info","channel":"ops"}'

curl -s -X POST http://127.0.0.1:4000/api/discord/notify \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" || echo "⚠️  Notification failed (non-blocking)"
```

## Smoke Test

The smoke test (`run/smoke_api_ui.sh`) includes an optional Discord check:

```bash
=== Discord Integration (Optional) ===
Discord Notify... ✅ PASS (200)
# OR
Discord Notify... SKIP (webhook not configured)
```

**Note:** Discord tests only run if `DISCORD_WEBHOOK_DEFAULT` is set.

## Troubleshooting

### "Discord webhook is not configured" (503)

**Cause:** Neither `DISCORD_WEBHOOK_DEFAULT` nor `DISCORD_WEBHOOK_MAP` is set.

**Fix:** Set at least one environment variable:
```bash
export DISCORD_WEBHOOK_DEFAULT="https://discord.com/api/webhooks/..."
```

### "Failed to send Discord notification" (502)

**Causes:**
- Invalid webhook URL (deleted or expired)
- Network connectivity issues
- Discord API rate limits

**Debug:**
```bash
# Check webhook health
curl -X POST "$DISCORD_WEBHOOK_DEFAULT" \
  -H "Content-Type: application/json" \
  -d '{"content":"Health check"}'

# Expected: 204 No Content (success)
```

### Webhook Rate Limits

Discord webhooks have rate limits:
- **5 requests per 2 seconds** per webhook
- **30 requests per 60 seconds** per webhook

**Mitigation:** Use multiple webhooks for high-volume notifications.

### Invalid JSON in DISCORD_WEBHOOK_MAP

**Error:** `DISCORD_WEBHOOK_MAP is not valid JSON and will be ignored.`

**Fix:** Ensure proper JSON escaping:
```bash
# ✅ Correct
DISCORD_WEBHOOK_MAP='{"alerts":"https://...","ops":"https://..."}'

# ❌ Wrong (unescaped quotes)
DISCORD_WEBHOOK_MAP={"alerts":"https://..."}
```

## Security Best Practices

1. **Never commit webhooks to git**
   - Use `.env` (already in `.gitignore`)
   - Store in CI secrets for GitHub Actions

2. **Rotate webhooks periodically**
   - Delete old webhooks from Discord settings
   - Update environment variables

3. **Disable `@everyone` mentions**
   - Already configured: `allowed_mentions: { parse: [] }`
   - Prevents accidental mass pings

4. **Use separate webhooks per environment**
   ```bash
   # Production
   DISCORD_WEBHOOK_DEFAULT=https://discord.com/api/webhooks/.../prod
   
   # Staging
   DISCORD_WEBHOOK_DEFAULT=https://discord.com/api/webhooks/.../staging
   ```

## Architecture

```
┌─────────────────┐
│  Shell Scripts  │
│   Node.js Code  │
└────────┬────────┘
         │ HTTP POST /api/discord/notify
         ▼
┌─────────────────────────────────────┐
│  boss-api/server.cjs                │
│  - Normalize level (info/warn/err) │
│  - Resolve channel → webhook URL    │
│  - Format payload with emoji        │
└────────┬────────────────────────────┘
         │ postDiscordWebhook(url, payload)
         ▼
┌─────────────────────────────────────┐
│  agents/discord/webhook_relay.cjs   │
│  - Native Node.js https request     │
│  - Timeout: 10s                     │
│  - User-Agent: 02luka-webhook-relay │
└────────┬────────────────────────────┘
         │ HTTPS POST
         ▼
┌─────────────────┐
│  Discord API    │
│  (Webhook)      │
└─────────────────┘
```

## Example Use Cases

### CI/CD Pipeline Notifications

```yaml
# .github/workflows/deploy.yml
- name: Notify Discord on success
  if: success()
  run: |
    curl -X POST http://127.0.0.1:4000/api/discord/notify \
      -H "Content-Type: application/json" \
      -d '{"content":"✅ Deploy successful (commit ${{ github.sha }})","level":"info","channel":"ops"}'
```

### Error Monitoring

```javascript
process.on('uncaughtException', async (error) => {
  const payload = {
    content: `🚨 Uncaught exception: ${error.message}`,
    level: 'error',
    channel: 'alerts'
  };
  
  try {
    await fetch('http://127.0.0.1:4000/api/discord/notify', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });
  } catch (e) {
    console.error('Failed to send alert:', e);
  }
  
  process.exit(1);
});
```

### Daily Report Summary

```bash
#!/bin/bash
# run/daily_report.sh

SUMMARY=$(cat g/reports/OPS_SUMMARY.json | jq -r '.summary')

curl -X POST http://127.0.0.1:4000/api/discord/notify \
  -H "Content-Type: application/json" \
  -d "{\"content\":\"📊 Daily Report:\\n$SUMMARY\",\"level\":\"info\",\"channel\":\"ops\"}"
```

## Migration from Other Solutions

### From `discord.js` bot

**Before:**
- Heavy dependency (~10MB)
- Requires bot token + OAuth
- Complex permission setup

**After:**
- Zero dependencies
- Just webhook URL
- No server-side state

### From `axios` + webhook

**Change:**
```diff
- const axios = require('axios');
- await axios.post(webhookUrl, payload);
+ const { postDiscordWebhook } = require('./agents/discord/webhook_relay.cjs');
+ await postDiscordWebhook(webhookUrl, payload);
```

## Limitations

1. **Webhooks only** - No rich embeds, reactions, or message editing
2. **No rate limit queuing** - Caller must handle rate limits
3. **Fire-and-forget** - No message ID returned (Discord limitation)

For advanced features (embeds, buttons), consider using the full Discord API with `discord.js`.

## Further Reading

- [Discord Webhook Guide](https://support.discord.com/hc/en-us/articles/228383668-Intro-to-Webhooks)
- [Discord API Rate Limits](https://discord.com/developers/docs/topics/rate-limits)
- [02LUKA API Endpoints](../api_endpoints.md)
