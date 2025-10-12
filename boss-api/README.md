# 02LUKA Boss API

## Overview
- Port: 4000 (overridable via `PORT`)
- Raw Node.js HTTP server (`server.cjs` is canonical entrypoint)
- Integrates Boss workspace access, model routing, and agent orchestration helpers
- Planner/executor endpoints wrap scripts under `agents/lukacode/`

## Setup
1. (Optional) copy `.env.sample` to `.env`
2. `bash ./run/dev_up_simple.sh`

## API Summary
- `GET /api/capabilities`
- `GET /api/connectors/status`
- `GET /config.json`
- `POST /api/plan`
- `POST /api/patch`
- `POST /api/smoke`
- `POST /api/optimize`
- `POST /api/chat-with-nlu-router`
- `GET /api/list/:folder`
- `GET /api/file/:folder/:name`

## Planner & Executor APIs

### `POST /api/plan`
Plans work by delegating to `agents/lukacode/plan.*`.

**Request JSON**
```json
{
  "prompt": "Refine onboarding docs",
  "context": "Any supporting notes (optional)",
  "files": ["docs/handbook.md"],
  "runId": "optional client provided id",
  "metadata": {"source": "dev-up"}
}
```
- `prompt` (string, required)
- `files` (array of repo-relative paths, optional). Paths are sanitized; values outside the repo are rejected.
- `context`, `metadata`, `runId` (optional). Absent `runId` values are auto-generated UUIDs.

**Response JSON**
```json
{
  "ok": true,
  "runId": "1234-health",
  "plan": {"steps": []},
  "status": {
    "exitCode": 0,
    "timedOut": false,
    "durationMs": 523,
    "scriptPath": "agents/lukacode/plan.cjs"
  },
  "statusLogs": ["planner ok"]
}
```
- `plan` contains parsed agent output (if JSON); otherwise `rawOutput` exposes a truncated stdout preview.
- `statusLogs` is the last 100 stderr lines for quick triage.

### `POST /api/patch`
Applies diffs via `agents/lukacode/patch.*`.

**Request JSON**
```json
{
  "summary": "Replace placeholder copy",
  "dryRun": true,
  "patches": [
    {
      "path": "docs/handbook.md",
      "diff": "diff --git a/docs/handbook.md b/docs/handbook.md
..."
    }
  ],
  "runId": "optional",
  "metadata": {"ticket": "OPS-42"}
}
```
- `patches` must be a non-empty array unless the agent exposes a health-check mode.
- Each entry is validated: sanitized repo-relative `path` and UTF-8 `diff` ≤ 512 KB total.
- `dryRun` defaults to `false`; set it to guard against accidental writes when supported by the agent.

**Response JSON** mirrors the plan endpoint (`patch` instead of `plan`). Failed executions return HTTP 502 with `ok: false` and `statusLogs`.

### `POST /api/smoke`
Runs smoke/self-tests through `agents/lukacode/smoke.*`.

**Request JSON**
```json
{
  "mode": "health-check",
  "scope": ["api", "ui"],
  "checks": ["capabilities"],
  "runId": "optional",
  "metadata": {"origin": "smoke_api_ui.sh"}
}
```
- `scope`/`checks` arrays are truncated to 20 items and stringified before dispatch.
- Responses follow the same `{ ok, runId, smoke, status, statusLogs }` shape.

## Workspace File APIs
- `GET /api/list/:folder` – Lists visible files. Allowed folders: `inbox`, `sent`, `deliverables`, `dropbox`, `drafts`, `documents`.
- `GET /api/file/:folder/:name` – Streams text content from the allowed folders.

All mailbox paths are resolved via `g/tools/path_resolver.sh human:<folder>` to honor the single source of truth mapping.

## Security Guardrails
- Planner/patch/smoke payloads are capped at 512 KB and rejected if JSON parsing fails.
- File paths are sanitized to ensure they remain inside the repo; `..`, absolute, or NUL-containing paths are denied.
- Patch batches are limited to 20 entries and 512 KB of diff text to prevent oversized workloads.
- Agent subprocesses inherit the current environment, run from the repo root, and their stderr is logged and truncated before returning to clients.

## Development
- `bash ./run/dev_up_simple.sh` boots the API & static UI and performs health probes (including planner/patch/smoke endpoints).
- `bash ./run/smoke_api_ui.sh` launches a deeper end-to-end smoke.
- Keep `server.cjs` as the authoritative API entrypoint; `server.js` remains legacy.

## Runtime configuration

The API exposes a lightweight `/config.json` endpoint used by the UI to discover service bases and gateway readiness. Populate the following environment variables before launching the server:

| Variable | Purpose |
|----------|---------|
| `API_BASE` | Public URL the UI should use for API calls. Defaults to `http://127.0.0.1:4000`. |
| `AI_GATEWAY_URL` | Base URL for the AI gateway (surfaced in `AI_BASE` and `GATEWAYS.ai.baseUrl`). |
| `AI_GATEWAY_KEY` | Presence marks the AI gateway as configured; the key itself is not returned. |
| `AGENTS_GATEWAY_URL` | Base URL for the agents gateway (`GATEWAYS.agents.baseUrl`). |
| `AGENTS_GATEWAY_KEY` | Presence marks the agents gateway as configured; the key itself is not returned. |
