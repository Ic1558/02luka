# Telegram Command Reference – Kim K2 Profiles

## Commands
- `/use kim_k2_poc`
  - Persistently switch the current chat to the K2 profile.
  - Dispatcher writes the selection to `core/nlp/kim_session_profiles.json` with a
    30-day TTL.
- `/use default`
  - Remove the stored profile entry so the dispatcher falls back to the default.
- `/k2 <question>`
  - Sends a one-off question through the K2 profile without changing persistence.
  - Useful for evaluation before committing the profile.

## Message Format Published to `gg:nlp`
The Telegram bot now publishes a full JSON payload containing the chat context:
```json
{
  "type": "telegram_message",
  "text": "/use kim_k2_poc",
  "message_id": 1234,
  "chat": {"id": 998877, "type": "private"},
  "from": {"id": 5566, "username": "ops"},
  "reply_to": "kim:reply:telegram:998877",
  "published_at": "2025-11-11T07:45:00Z"
}
```
The dispatcher enriches this payload and publishes to `kim:requests` with the selected
profile metadata.

## Operational Tips
1. Run `tools/kim_health_check.zsh` before go-live to verify Redis credentials and
   process status.
2. Use `tools/kim_ab_test.zsh "Explain quantum computing"` to capture differences
   between the default Kim and K2 responses.
3. Logs:
   - Dispatcher: `~/02luka/logs/nlp_dispatcher.log`
   - Telegram bot: `~/02luka/logs/kim_bot.stdout.log`
4. Profile overrides expire automatically after 30 days; re-run `/use` if necessary.
