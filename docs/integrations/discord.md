# Discord Integration

02LUKA can deliver notifications to Discord using a lightweight webhook relay.
This document explains how to create a Discord webhook, configure the server, and
validate the integration.

## 1. Create a Discord Webhook

1. Open your Discord server and choose the channel that should receive updates.
2. Click **Edit Channel → Integrations → Webhooks → New Webhook**.
3. Give the webhook a descriptive name (for example `02LUKA Alerts`).
4. Copy the webhook URL. It looks like `https://discord.com/api/webhooks/<id>/<token>`.

> Keep the webhook URL private. Anyone with the URL can post messages into your channel.

## 2. Configure Environment Variables

The API server reads two environment variables when it starts:

- `DISCORD_WEBHOOK_DEFAULT` – required for most setups. When set, `/api/discord/notify`
  will send messages to this webhook whenever the request does not specify a channel
  or the requested channel is not mapped.
- `DISCORD_WEBHOOK_MAP` – optional JSON object that maps logical channel names to
  webhook URLs. This allows routing different notification types to different
  Discord channels without changing application code.

Example `.env` snippet:

```bash
DISCORD_WEBHOOK_DEFAULT="https://discord.com/api/webhooks/1234567890/ABCDEF"
DISCORD_WEBHOOK_MAP='{"alerts":"https://discord.com/api/webhooks/0987654321/QWERTY","default":"https://discord.com/api/webhooks/1234567890/ABCDEF"}'
```

Notes:

- The JSON string **must** be valid; malformed JSON is ignored at runtime.
- Only `https://` URLs are accepted.
- When `DISCORD_WEBHOOK_DEFAULT` is not defined, requests must target a channel
  present in `DISCORD_WEBHOOK_MAP`.

Restart `boss-api/server.cjs` after updating the environment so the new values are
picked up.

## 3. Send a Test Notification

With the server running (`node boss-api/server.cjs`), execute the helper script:

```bash
bash run/discord_notify_example.sh
```

The script sends a few sample payloads to `POST /api/discord/notify`. When the
webhook is configured correctly, you should see messages in Discord that include
emoji prefixes for the `info`, `warn`, and `error` levels.

You can also exercise the endpoint manually:

```bash
curl -X POST "http://127.0.0.1:4000/api/discord/notify" \
  -H "Content-Type: application/json" \
  -d '{"content":"02LUKA is online","level":"info","channel":"default"}'
```

## 4. Smoke Test Integration

The `run/smoke_api_ui.sh` script now contains an optional Discord check. When
`DISCORD_WEBHOOK_DEFAULT` is set, the smoke test sends a lightweight notification
and reports `Discord Notify... ✅ PASS`. When no webhook is configured it reports
`Discord Notify... SKIP` and continues.

## 5. Troubleshooting

| Symptom | Likely Cause | Resolution |
| --- | --- | --- |
| `503 Discord webhook is not configured` | Environment variables are missing or misspelled | Export `DISCORD_WEBHOOK_DEFAULT` or add a `default` entry to `DISCORD_WEBHOOK_MAP` |
| `502 Failed to send Discord notification` | Discord rejected the request or there was a network error | Confirm the webhook URL is valid and has not been revoked; retry after checking Discord status |
| No message appears in Discord, but API returns `{ "ok": true }` | Wrong Discord channel or filtered content | Verify the webhook target channel and ensure the message content is not filtered by channel permissions |
| `DISCORD_WEBHOOK_MAP is not valid JSON and will be ignored.` in logs | Invalid JSON passed in environment | Quote the JSON string and escape quotes properly |

For additional observability, monitor the API server logs. Only sanitized error
messages are emitted, and secrets such as webhook URLs are never printed.
