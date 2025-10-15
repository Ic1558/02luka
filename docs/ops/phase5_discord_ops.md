# Phase 5 – Discord Ops Integration

Phase 5 extends the ops atomic flow with Discord notifications. When `./run/ops_atomic.sh` completes it now delivers a Discord summary alongside the existing test → verify → notify → report pipeline, and a daily scheduler can push the same digest at 08:00 ICT.

## 1. Environment Configuration

Add the following variables to your `.env` (or shell profile):

```bash
# Discord (required for notifications)
DISCORD_WEBHOOK_DEFAULT="https://discord.com/api/webhooks/..."
# Optional multi-channel map (JSON)
DISCORD_WEBHOOK_MAP='{"alerts":"https://discord.com/api/webhooks/...","ops":"...","reports":"..."}'

# Where ops/report notifications should land
REPORT_CHANNEL=reports
```

Reload your shell or export the variables before running any ops scripts. The webhook values must stay private – avoid committing them or echoing them to logs.

## 2. Manual Verification Checklist

1. **Prep** – ensure the API bridge (`boss-api/server.cjs`) is running locally.
2. **Run smoke** – `SMOKE_SKIP_DISCORD_NOTIFY=0 ./run/smoke_api_ui.sh` should display `Discord Notify... PASS ...`. Without configuration it prints `Discord Notify... SKIP (...)`.
3. **Run ops atomic** – `./run/ops_atomic.sh` executes all five phases and posts a summary (PASS/WARN/FAIL counts + latest report link) to the configured Discord channel.
4. **Daily payload** – `node agents/reportbot/index.cjs --text` prints the aggregate summary, while `node agents/reportbot/index.cjs --write` refreshes `g/reports/OPS_SUMMARY.json` for downstream tooling.

If Discord is unreachable the scripts log a WARN state but still exit successfully so that CI pipelines do not hard-fail.

## 3. Scheduling @ 08:00 ICT

### Linux / Server (cron)

Set the timezone to UTC+7 (Asia/Bangkok) and schedule the atomic run:

```cron
# Run every day 08:00 Asia/Bangkok (UTC+7)
0 1 * * * cd /path/to/02luka-repo && ./run/ops_atomic.sh >/tmp/ops_atomic.log 2>&1
```

Check `/tmp/ops_atomic.log` for phase output and confirm the Discord message appears once per day.

### macOS (launchd)

Create `~/Library/LaunchAgents/com.02luka.ops_atomic.plist` with the following content:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>com.02luka.ops_atomic</string>
    <key>ProgramArguments</key>
    <array>
      <string>/bin/bash</string>
      <string>-lc</string>
      <string>cd /path/to/02luka-repo && ./run/ops_atomic.sh &gt;/tmp/ops_atomic.log 2&gt;&amp;1</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
      <key>Hour</key>
      <integer>8</integer>
      <key>Minute</key>
      <integer>0</integer>
    </dict>
    <key>StandardOutPath</key>
    <string>/tmp/ops_atomic.launchd.out</string>
    <key>StandardErrorPath</key>
    <string>/tmp/ops_atomic.launchd.err</string>
    <key>EnvironmentVariables</key>
    <dict>
      <key>DISCORD_WEBHOOK_DEFAULT</key>
      <string>https://discord.com/api/webhooks/.../...</string>
      <key>REPORT_CHANNEL</key>
      <string>reports</string>
    </dict>
  </dict>
</plist>
```

Load the job with:

```bash
launchctl load ~/Library/LaunchAgents/com.02luka.ops_atomic.plist
```

Remove it with:

```bash
launchctl unload ~/Library/LaunchAgents/com.02luka.ops_atomic.plist
rm ~/Library/LaunchAgents/com.02luka.ops_atomic.plist
```

## 4. Troubleshooting & Rollback

- **Webhook missing** – Phase 5 prints `SKIP` when `DISCORD_WEBHOOK_*` variables are absent; set the env or ignore if Discord is optional.
- **Discord downtime** – the notifier retries once, logs a WARN, and the overall ops run still ends successfully.
- **Regeneration** – delete `agents/reportbot/`, `scripts/discord_ops_notify.sh`, and remove the Phase 5 block from `run/ops_atomic.sh` to revert.
- **Smoke skip** – set `SMOKE_SKIP_DISCORD_NOTIFY=1` to avoid double posting during pipelines.

## 5. Quick Commands

```bash
# Generate daily summary JSON (updates g/reports/OPS_SUMMARY.json)
node agents/reportbot/index.cjs --write

# Send a one-off notification (honours REPORT_CHANNEL and webhook map)
scripts/discord_ops_notify.sh --status pass --summary "PASS=4 WARN=0 FAIL=0" \
  --details "• Smoke – PASS\n• API – WARN (offline dev)" --link "https://example.com/report"
```

Keep Discord secrets out of logs. The notifier never prints webhook URLs and truncates overly long messages to stay within Discord limits.
