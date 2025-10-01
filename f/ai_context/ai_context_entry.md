# AI Context Entry
> **Generated:** 2025-09-30T22:24:57Z

## Quick Navigation
- Human Inbox → `human:inbox`
- Work Orders → `boss/work-orders/` (if present)
- Luka UI → `luka.html`
- Codex Template System → `.codex/templates/master_prompt.md`

## Today's Focus
1. Confirm `.codex/templates/master_prompt.md` is the starting point for Codex tasks (`GOAL:` first, fill remainder before execution).
2. Ensure `luka.html` prompt library can load the master template via local HTTP server (serve repo root before use).
3. Promote `g/tools/install_master_prompt.sh` as the supported installation/refresh path; avoid manual edits in other directories.

## Status Signals
- `f/ai_context/mapping.json` at v2.1 exposes `codex:*` routes.
- Hidden tier list now includes `.codex` to keep template internals out of routine scans.

## Reminders
- Run `verify_system.sh` before deployments to surface missing gateways or template drift.
- Record any new prompt variants under `.codex/templates/` so they enter the discovery pipeline.

