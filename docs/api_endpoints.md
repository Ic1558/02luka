# 02LUKA API Endpoints

Base URL: `http://127.0.0.1:4000`

> **Phase 4 Status (2025-10-15):** MCP verification and Linear-lite UI endpoints are fully promoted. Use the new
> verification + sync routes to keep Luka dashboards aligned with MCP health.

## Health & Monitoring

### GET /healthz

Basic health check endpoint.

**Response:**
```json
{
  "ok": true,
  "status": "ready",
  "ts": "2025-10-11T18:53:00.000Z"
}
```

**Example:**
```bash
curl http://127.0.0.1:4000/healthz
```

---

### GET /api/smoke

Comprehensive system health check with service status.

**Response:**
```json
{
  "status": "healthy",
  "services": {
    "api": true,
    "ui": true,
    "mcp": true,
    "ollama": true
  },
  "timestamp": "2025-10-11T18:53:16.591Z"
}
```

**Example:**
```bash
curl http://127.0.0.1:4000/api/smoke
```

**Status Values:**
- `healthy` - All critical services (API + UI) are operational
- `degraded` - Critical services down (API or UI unavailable)

---

### GET /api/capabilities

Returns available features, connectors, and mailboxes.

**Response:**
```json
{
  "ui": {
    "inbox": true,
    "preview": true,
    "prompt_composer": true,
    "connectors": true
  },
  "features": {
    "goal": true,
    "optimize_prompt": true,
    "chat": true,
    "rag": true,
    "sql": true,
    "ocr": true,
    "nlu": false
  },
  "engines": { ... },
  "connectors": { ... }
}
```

**Example:**
```bash
curl http://127.0.0.1:4000/api/capabilities | jq .
```

---

## Agent Endpoints

### POST /api/plan

Execute the planning agent to generate implementation plan.

**Request Body:**
```json
{
  "prompt": "Create a user authentication system",
  "files": ["src/auth.js", "src/users.js"],
  "context": "Using Express.js and JWT",
  "metadata": {
    "project": "myapp",
    "priority": "high"
  }
}
```

**Required Fields:**
- `prompt` (string) - Task description or goal

**Optional Fields:**
- `files` (array) - File paths to include in context
- `context` (string) - Additional context for the plan
- `metadata` (object) - Custom metadata
- `runId` (string) - Unique run identifier (auto-generated if omitted)

**Response (Success):**
```json
{
  "ok": true,
  "runId": "uuid-here",
  "status": {
    "exitCode": 0,
    "signal": null,
    "timedOut": false,
    "durationMs": 1234,
    "scriptPath": "/path/to/plan.cjs"
  },
  "plan": {
    "tasks": [...],
    "dependencies": [...]
  },
  "statusLogs": [...]
}
```

**Response (Error):**
```json
{
  "error": "prompt is required"
}
```

**Example:**
```bash
curl -X POST http://127.0.0.1:4000/api/plan \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "Add dark mode toggle to settings page",
    "files": ["src/components/Settings.jsx"]
  }'
```

**Agent Requirements:**
Place a `plan.cjs` script in `agents/lukacode/` directory. The script receives:
- `runId` - Unique identifier
- `prompt` - User's task description
- `context` - Additional context
- `files` - Array of file paths
- `metadata` - Custom metadata object

---

### GET /api/mcp/verify/status

Return aggregated health + verification status for all MCP backends.

**Response:**
```json
{
  "ok": true,
  "phase": "phase4",
  "fs": {
    "status": "ready",
    "lastVerified": "2025-10-15T04:31:22.090Z",
    "latencyMs": 214
  },
  "docker": {
    "status": "ready",
    "lastVerified": "2025-10-15T04:29:03.441Z"
  },
  "pending": []
}
```

**Example:**
```bash
curl http://127.0.0.1:4000/api/mcp/verify/status | jq .
```

**Status Values:**
- `ready` – Verification completed in the last 15 minutes.
- `stale` – Verification older than 15 minutes; rerun required.
- `error` – Last verification attempt failed.

---

### POST /api/mcp/verify

Schedule a verification run across MCP providers (FS, Docker, Remote).

**Request Body:**
```json
{
  "providers": ["fs", "docker"],
  "force": false,
  "notes": "Nightly validation"
}
```

**Required Fields:**
- `providers` (array) – Target provider ids. Supported: `fs`, `docker`, `remote`.

**Optional Fields:**
- `force` (boolean) – Ignore freshness window and force new run.
- `notes` (string) – Free-form audit text appended to reports.
- `runId` (string) – Custom run identifier.

**Response (Accepted):**
```json
{
  "ok": true,
  "runId": "verify-20251015-0431",
  "queued": ["fs", "docker"],
  "estimatedCompletionMs": 45000
}
```

**Example:**
```bash
curl -X POST http://127.0.0.1:4000/api/mcp/verify \
  -H "Content-Type: application/json" \
  -d '{"providers":["fs","remote"],"force":true}'
```

**Agent Requirements:**
- `agents/lukacode/verify_mcp.cjs` must exist and emit structured verification logs under `g/reports/mcp_verify/`.

---

### GET /api/linear-lite/cards

Fetch the current Linear-lite card summaries powering the dashboard UI panel.

**Query Params:**
- `state` (string, optional) – Filter by state (`triage`, `active`, `done`).
- `limit` (number, optional, default `25`) – Maximum cards to return.

**Response:**
```json
{
  "ok": true,
  "source": "linear-lite",
  "cards": [
    {
      "id": "LITE-204",
      "title": "Refresh MCP verification metrics",
      "state": "active",
      "assignee": "boss",
      "updatedAt": "2025-10-15T03:55:44.200Z"
    }
  ]
}
```

**Example:**
```bash
curl "http://127.0.0.1:4000/api/linear-lite/cards?state=active&limit=10" | jq .
```

---

### POST /api/linear-lite/sync

Trigger a background synchronization between the Linear-lite cache and the upstream workspace.

**Request Body:**
```json
{
  "syncType": "incremental",
  "broadcast": true
}
```

**Optional Fields:**
- `syncType` (string) – `incremental` (default) or `full`.
- `broadcast` (boolean) – Emit SSE update for Luka UI clients.

**Response (Accepted):**
```json
{
  "ok": true,
  "syncId": "linear-lite-20251015-0356",
  "mode": "incremental"
}
```

**Example:**
```bash
curl -X POST http://127.0.0.1:4000/api/linear-lite/sync -H "Content-Type: application/json" -d '{}'
```

**Agent Requirements:**
- `agents/lukacode/linear_lite_sync.cjs` handles the synchronization and writes receipts to `g/reports/linear-lite/`.

---

### POST /api/patch

Execute the patch agent to apply code changes.

**Request Body:**
```json
{
  "patches": [
    {
      "file": "src/auth.js",
      "operation": "update",
      "content": "...",
      "line": 42
    }
  ],
  "dryRun": false,
  "metadata": {
    "author": "claude",
    "timestamp": "2025-10-11T18:00:00Z"
  }
}
```

**Required Fields:**
- `patches` (array) - Non-empty array of patch operations

**Optional Fields:**
- `dryRun` (boolean) - Test mode without applying changes
- `metadata` (object) - Custom metadata
- `runId` (string) - Unique run identifier

**Patch Object:**
- `file` (string) - Target file path
- `operation` (string) - One of: update, create, delete
- `content` (string) - New content (for update/create)
- `line` (number) - Line number (optional, for targeted updates)

**Response (Success):**
```json
{
  "ok": true,
  "runId": "uuid-here",
  "status": {
    "exitCode": 0,
    "durationMs": 567
  },
  "result": {
    "applied": 3,
    "failed": 0
  }
}
```

**Response (Error):**
```json
{
  "error": "patches must be a non-empty array",
  "runId": "uuid-here"
}
```

**Example:**
```bash
curl -X POST http://127.0.0.1:4000/api/patch \
  -H "Content-Type: application/json" \
  -d '{
    "patches": [
      {
        "file": "src/config.js",
        "operation": "update",
        "content": "export const THEME = \"dark\";"
      }
    ],
    "dryRun": true
  }'
```

**Agent Requirements:**
Place a `patch.cjs` script in `agents/lukacode/` directory.

---

## Integrations

### POST /api/discord/notify

Send a notification message to Discord via webhook.

**Request Body:**
```json
{
  "content": "Build completed successfully",
  "level": "info",
  "channel": "default"
}
```

**Required Fields:**
- `content` (string) - Message text to send

**Optional Fields:**
- `level` (string) - Message severity: `info` (default), `warn`, or `error`
- `channel` (string) - Channel name for webhook routing (default: `default`)

**Response (Success):**
```json
{
  "ok": true
}
```

**Response (Error):**
```json
{
  "error": "content is required"
}
```

```json
{
  "error": "Discord webhook is not configured"
}
```

```json
{
  "error": "Failed to send Discord notification"
}
```

**Example:**
```bash
curl -X POST http://127.0.0.1:4000/api/discord/notify \
  -H "Content-Type: application/json" \
  -d '{
    "content": "Deployment complete",
    "level": "info",
    "channel": "ops"
  }'
```

**Configuration:**
- Set `DISCORD_WEBHOOK_DEFAULT` environment variable with webhook URL
- Optionally set `DISCORD_WEBHOOK_MAP` for multi-channel routing (JSON object)

**Level Emojis:**
- `info` → ℹ️
- `warn` → ⚠️
- `error` → 🚨

**See Also:**
- Full documentation: [`docs/integrations/discord.md`](../integrations/discord.md)
- Test script: [`run/discord_notify_example.sh`](../../run/discord_notify_example.sh)
- Implementation: [`agents/discord/webhook_relay.cjs`](../../agents/discord/webhook_relay.cjs)

---

## Error Responses

All endpoints return JSON error responses with appropriate HTTP status codes:

- `400 Bad Request` - Invalid input or missing required fields
- `413 Payload Too Large` - Request body exceeds size limit (512 KB)
- `501 Not Implemented` - Required agent script not found
- `502 Bad Gateway` - Agent execution failed

**Example Error:**
```json
{
  "error": "prompt is required"
}
```

---

## Rate Limits & Constraints

- **Max Payload Size:** 512 KB per request
- **Max Agent Output:** 4 MB
- **Agent Timeout:** 90 seconds (default)
- **Max Patches:** 20 per request

---

## Development Tips

### Testing Endpoints

```bash
# Health check
curl http://127.0.0.1:4000/healthz

# System status
curl http://127.0.0.1:4000/api/smoke | jq .

# MCP verification status (Phase 4)
curl http://127.0.0.1:4000/api/mcp/verify/status | jq .

# Linear-lite active cards
curl "http://127.0.0.1:4000/api/linear-lite/cards?state=active" | jq '.cards | length'

# Quick plan test
curl -X POST http://127.0.0.1:4000/api/plan \
  -H "Content-Type: application/json" \
  -d '{"prompt":"test"}' | jq .

# Discord notification (requires DISCORD_WEBHOOK_DEFAULT)
curl -X POST http://127.0.0.1:4000/api/discord/notify \
  -H "Content-Type: application/json" \
  -d '{"content":"Test notification","level":"info"}' | jq .
```

### Run All Tests

```bash
bash ./run/smoke_api_ui.sh
```

### Check Logs

```bash
tail -f /tmp/boss-api.out  # stdout
tail -f /tmp/boss-api.err  # stderr
```
