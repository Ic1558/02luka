# Kim K2 Deployment – Production Checklist

## 1. Infrastructure
- **Redis Integration**
  - Dispatcher subscribes to `gg:nlp` and publishes to `kim:requests`.
  - Authentication supported via `REDIS_PASSWORD` for both Telegram bot and tools.
- **Profile Persistence**
  - `core/nlp/profile_store.py` manages per-chat selection with 30-day TTL.
  - File stored at `~/02luka/core/nlp/kim_session_profiles.json` (ignored by git).
- **LaunchAgent**
  - `LaunchAgents/com.02luka.nlp-dispatcher.plist` keeps the dispatcher online.
  - Logs in `~/02luka/logs/nlp_dispatcher.log` and `.err`.
- **Provider Configuration**
  - `agents/kim_bot/providers/k2_thinking.yaml` defines OpenRouter access for K2.
  - `config/kim_agent_profiles/kim_k2_poc.yaml` registers the selectable profile.

## 2. Telegram Integration
- Bot publishes structured payloads with chat and sender metadata.
- Dispatcher recognises `/use` and `/k2` commands and emits telemetry events on
  `kim:dispatcher:events`.
- `/use default` removes stored preference; otherwise the profile sticks for 30 days.

## 3. Tooling
- `tools/kim_nlp_publish.py` – Send authenticated test messages.
- `tools/kim_ab_test.zsh` – A/B harness for side-by-side comparison.
- `tools/kim_health_check.zsh` – Health monitoring script.
- `core/nlp/start_dispatcher.sh` – Entry point used by LaunchAgent.

## 4. Testing
- `tests/test_kim_profile_router.py` validates profile TTLs, command parsing, and
  dispatch semantics.
- Ensure `pytest tests/test_kim_profile_router.py` passes after environment updates.

## 5. Operations
1. Copy LaunchAgent to `~/Library/LaunchAgents` and run `launchctl load`.
2. Validate connectivity using `tools/kim_health_check.zsh`.
3. Run `tools/kim_ab_test.zsh "Explain vector databases"` to confirm both profiles
   dispatch successfully.
4. Monitor `kim:dispatcher:events` for `kim.dispatch.sent` and `kim.dispatch.profile_set`
   events to confirm activity.

## 6. Documentation
- Quick start: `~/02luka/QUICKSTART_KIM_K2.md`
- Telegram command guide: `~/02luka/reports/system/kim_k2_tgcmds_README.md`
- Integration summary: `~/02luka/reports/system/kim_k2_finalize_README.md`

All system components are now aligned for production evaluation of the Kimi K2
Thinking model alongside the default Kim pipeline.
