# 02LUKA API Endpoints

Base URL: `http://127.0.0.1:4000`

> **Phase 4 Status (2025-10-15):** MCP verification and Linear-lite UI endpoints are still in development. The
> roadmap section below captures the planned routes and will be replaced with full documentation once the backend
> handlers and supporting agents ship.

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

### Phase 4 roadmap endpoints

The Phase 4 MCP verification and Linear-lite endpoints are still under
development and **are not part of the current Luka release**. The final
specifications may change before launch, so the detailed request/response
schemas are intentionally omitted until implementation work lands in the
repository.

Planned additions include:

- `GET /api/mcp/verify/status`
- `POST /api/mcp/verify`
- `GET /api/linear-lite/cards`
- `POST /api/linear-lite/sync`

We will update this document with full reference material once the server
handlers and supporting agents (for example,
`agents/lukacode/verify_mcp.cjs` and `agents/lukacode/linear_lite_sync.cjs`)
are implemented.

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
