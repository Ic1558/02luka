# Kim K2 Integration – Finalization Notes

## Overview
The Kim Telegram bot now supports selectable runtime profiles, allowing production
operators to route individual chats through the new **Kimi K2 Thinking** provider on
OpenRouter.  A dedicated dispatcher process listens on `gg:nlp`, parses chat commands,
and publishes enriched requests to `kim:requests` for downstream processing.

This document summarizes the key artifacts and operational checklist required to keep
the integration live.

## Runtime Components
- `core/nlp/nlp_command_dispatcher.py` – Redis subscriber that interprets `/use` and
  `/k2` commands, maintains per-chat profile state, and publishes structured requests.
- `core/nlp/profile_store.py` – JSON-backed store with 30-day TTL for chat preferences.
- `core/nlp/start_dispatcher.sh` – Launch helper invoked by LaunchAgent.
- `tools/kim_nlp_publish.py` – Auth-aware CLI publisher for manual testing.
- `tools/kim_ab_test.zsh` – Sends A/B queries against default and K2 profiles.
- `tools/kim_health_check.zsh` – Performs Redis, dispatcher, and LaunchAgent checks.

## Configuration
- `agents/kim_bot/providers/k2_thinking.yaml` defines the OpenRouter transport for
  the K2 Thinking model.
- `config/kim_agent_profiles/kim_k2_poc.yaml` registers the parallel K2 profile used by
  `/use kim_k2_poc` and `/k2` commands.
- `LaunchAgents/com.02luka.nlp-dispatcher.plist` installs the dispatcher as a macOS
  LaunchAgent with persistent restart semantics.

## Telegram UX
- `/use kim_k2_poc` – Persist the chat on the K2 profile (30-day TTL).
- `/k2 <question>` – One-off query through K2 without switching the stored profile.
- `/use default` – Revert back to the legacy Kim routing path.

## Monitoring & Verification
1. `~/02luka/tools/kim_health_check.zsh`
2. `tail -f ~/02luka/logs/nlp_dispatcher.log`
3. Redis telemetry on `kim:dispatcher:events`
4. Optional A/B sweeps via `tools/kim_ab_test.zsh "<prompt>"`

Keep the dispatcher running alongside the existing Telegram bot to allow operators to
move between profiles without service disruption.
