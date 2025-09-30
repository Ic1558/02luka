# 02luka – System Overview (TL;DR)

## Layers
- **Human layer**: `boss/` — dropbox, inbox, sent, deliverables, drafts, documents.
- **System layer**: `g/` (tools/agents), `f/` (ai_context, bridge), `gateway/`, `run/`, `logs/`, `output/`, `launchd/`, `services/`, `docs/`.

## Core flows
- Human drops files → `boss/dropbox/` → Router decides route.
- Ambiguity → create `boss/inbox/query_*.md` → human replies via `boss/sent/` → Orchestrator resumes → final to `boss/deliverables/`.

## Single Source of Truth
- `f/ai_context/mapping.json` — all path keys.
- `g/tools/path_resolver.sh` — translate logical keys to real paths.
- `g/tools/mapping_drift_guard.sh` — validates mapping structure.

## Key services/scripts
- `g/tools/boss_router.sh`, `g/tools/ticket_orchestrator.sh`
- `g/tools/launchagent_manager.sh`
- `gateway/health_proxy.js` (rate-limit, X-Request-ID, /boss/health)

See `docs/system_map.md` for the latest generated topology.
