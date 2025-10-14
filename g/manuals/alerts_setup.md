---
project: ops-automation
updated: 2025-10-07
status: draft
---

# Ops Alerting Setup

This guide explains how to enable Slack or Telegram notifications for the Ops Summary report bot.

## Environment Variables

Configure the following environment variables for the runtime that executes `agents/reportbot/index.js`.

| Channel   | Required Keys                          | Notes |
|-----------|----------------------------------------|-------|
| Slack     | `SLACK_WEBHOOK`                        | Incoming webhook URL generated from Slack. |
| Telegram  | `TG_BOT_TOKEN`, `TG_CHAT_ID`           | Bot token from [@BotFather](https://core.telegram.org/bots) and destination chat ID. |

> **Security:** Never commit secrets to the repository. Store them in your shell environment, `.env` files excluded by `.gitignore`, CI secrets, or secret managers.

## Examples

### Slack

```bash
export SLACK_WEBHOOK="https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX"
node agents/reportbot/index.js run/status/ops_summary.json
```

### Telegram

```bash
export TG_BOT_TOKEN="1234567:ABCDEF"  # provided by @BotFather
export TG_CHAT_ID="-1001234567890"    # channel or chat ID
node agents/reportbot/index.js run/status/ops_summary.json
```

If both Slack and Telegram variables are present, notifications are sent to both services.

## Testing Alerts Locally

1. Create a temporary summary file:
   ```bash
   cat > /tmp/ops_summary.json <<'JSON'
   {
     "title": "Ops Summary",
     "warns": ["Backups delayed"],
     "fails": ["Daily proof missing"]
   }
   JSON
   ```
2. Export the desired environment variables.
3. Run the report bot and confirm that notifications arrive:
   ```bash
   node agents/reportbot/index.js /tmp/ops_summary.json
   ```

## Troubleshooting

- **No notification sent:** Verify that at least one channel is configured and that the summary contains `warns` or `fails` entries.
- **Telegram chat ID unknown:** Send a message to your bot and call `https://api.telegram.org/bot$TG_BOT_TOKEN/getUpdates` to inspect the ID.
- **Slack webhook revoked:** Create a new incoming webhook URL and update `SLACK_WEBHOOK`.
