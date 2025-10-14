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
- `POST /api/plan`
- `POST /api/patch`
- `POST /api/smoke`
- `POST /api/optimize_prompt`
- `POST /api/chat`
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

## OpenAI Responses APIs

The boss API integrates OpenAI's Responses API for prompt optimization and direct chat when `OPENAI_API_KEY` is configured.

### `GET /api/connectors/status`

Returns readiness information for Anthropic, OpenAI, and local heuristic services.

```json
{
  "anthropic": { "ready": false, "reason": "ANTHROPIC_API_KEY not configured." },
  "openai": { "ready": true, "model": "o4-mini" },
  "local": { "ready": true, "optimize": { "source": "heuristic", "variants": 3 } }
}
```

### `POST /api/optimize_prompt`

Rewrites prompts using `o4-mini` (overridable via `OPENAI_OPTIMIZE_MODEL`). When an OpenAI key is absent or the Responses API call fails, the server automatically falls back to a rule-based heuristic engine that produces three ranked variants.

**Request JSON**
```json
{
  "prompt": "Draft a release announcement for version 1.2.",
  "system": "You are a precise product marketer.",
  "context": "Highlight the new automations tab.",
  "model": "o4-mini"
}
```

**Response JSON**
```json
{
  "ok": true,
  "prompt": "Announcement plan...",
  "variants": [
    {
      "id": "openai:o4-mini",
      "title": "OpenAI o4-mini",
      "score": 0.92,
      "source": "openai",
      "prompt": "Announcement plan...",
      "rationale": "Validated release notes before rewriting."
    },
    {
      "id": "structured_blueprint",
      "title": "Structured Execution Blueprint",
      "score": 0.74,
      "source": "heuristic",
      "prompt": "# Role...",
      "rationale": "Organizes the request into..."
    }
  ],
  "best": "openai:o4-mini",
  "engine": "openai:o4-mini",
  "reasoning": "Validated release notes before rewriting.",
  "usage": { "input_tokens": 280, "output_tokens": 160 },
  "warnings": ["OpenAI request failed"],
  "meta": {
    "provider": "openai",
    "model": "o4-mini",
    "endpoint": "responses",
    "status": "completed",
    "response_id": "resp_abc123"
  }
}
```

When the heuristic engine is used exclusively the response mirrors the same shape but `engine` is set to `heuristic:rule_based`, `meta.provider` is `heuristic`, and `warnings` remains absent.

### `POST /api/chat`

Direct chat completion with optional system prompt. Uses `OPENAI_CHAT_MODEL` or falls back to `OPENAI_MODEL`.

**Request JSON**
```json
{
  "message": "Summarize today's incident report",
  "system": "You are an SRE assistant",
  "model": "o4-mini"
}
```

**Response JSON**
```json
{
  "ok": true,
  "response": "Incident resolved after...",
  "engine": "openai:o4-mini",
  "reasoning": "Checked the postmortem summary.",
  "usage": { "input_tokens": 210, "output_tokens": 120 },
  "meta": {
    "provider": "openai",
    "model": "o4-mini",
    "endpoint": "responses",
    "response_id": "resp_def456"
  }
}
```

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
