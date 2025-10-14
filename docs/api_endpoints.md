# 02LUKA API Endpoints

Base URL: `http://127.0.0.1:4000`

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
  "goal": "Create a user authentication system",
  "stub": false
}
```

**Required Fields:**
- `goal` (string) - Task description or goal

**Optional Fields:**
- `stub` (boolean) - Return stub response immediately for smoke tests (default: false)

**Stub Mode:**
For health checks and smoke tests, you can enable stub mode via:
- Body parameter: `{"goal": "ping", "stub": true}`
- HTTP header: `X-Smoke: 1`

Stub mode returns immediately without executing the agent:
```json
{
  "plan": "STUB: Plan endpoint operational",
  "goal": "ping",
  "mode": "smoke"
}
```

**Response (Success - Normal Mode):**
```json
{
  "plan": "Step 1: Create auth routes\nStep 2: Add JWT middleware\n..."
}
```

**Response (Error):**
```json
{
  "error": "Goal is required"
}
```

**Examples:**
```bash
# Stub mode (smoke test)
curl -X POST http://127.0.0.1:4000/api/plan \
  -H "Content-Type: application/json" \
  -d '{"goal":"ping","stub":true}'

# Stub mode (via header)
curl -X POST http://127.0.0.1:4000/api/plan \
  -H "Content-Type: application/json" \
  -H "X-Smoke: 1" \
  -d '{"goal":"test"}'

# Normal mode
curl -X POST http://127.0.0.1:4000/api/plan \
  -H "Content-Type: application/json" \
  -d '{"goal":"Add dark mode toggle to settings page"}'
```

**Agent Requirements:**
Place a `plan.cjs` script in `agents/lukacode/` directory that accepts the goal as command line argument.

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

## Reports Endpoints

### GET /api/reports/list

List available atomic operation reports.

**Response:**
```json
{
  "files": [
    "OPS_ATOMIC_251015_021806.md",
    "OPS_ATOMIC_251015_011806.md",
    "OPS_ATOMIC_251014_235700.md"
  ]
}
```

**Example:**
```bash
curl http://127.0.0.1:4000/api/reports/list | jq .
```

**Returns:** Up to 20 most recent atomic operation reports sorted by timestamp (newest first).

---

### GET /api/reports/latest

Retrieve the latest atomic operation report content.

**Response:**
Returns the full markdown content of the most recent `OPS_ATOMIC_*.md` report.

**Content-Type:** `text/markdown; charset=utf-8`

**Example:**
```bash
curl http://127.0.0.1:4000/api/reports/latest
```

**Error Cases:**
- `404` - No reports found or reports directory missing

---

### GET /api/reports/summary

Get the JSON summary of the latest atomic operation.

**Response:**
```json
{
  "timestamp": "2025-10-15T02:18:06Z",
  "phases": {
    "phase1": "✅ PASS",
    "phase2": "✅ PASS",
    "phase3": "✅ PASS",
    "phase4": "✅ PASS"
  },
  "reportbot": {
    "status": "✅ Online",
    "warnings": ["OAuth scope limited"]
  },
  "mcp": {
    "container": "mcp_gateway",
    "uptime": "Up 7 days",
    "tests": {
      "connectivity": "✅ PASS",
      "tools": "✅ PASS"
    }
  }
}
```

**Example:**
```bash
curl http://127.0.0.1:4000/api/reports/summary | jq .
```

**Note:** Summary is generated by `agents/reportbot/index.cjs` and stored in `g/reports/OPS_SUMMARY.json`.

---

## UI Routes (Linear-lite Multipage)

The API server also serves UI pages directly from `boss-ui/apps/`:

### GET /

Landing page with system overview and quick links.

**Returns:** `boss-ui/apps/landing.html`

---

### GET /chat

Interactive chat interface for conversational tasks.

**Returns:** `boss-ui/apps/chat.html`

---

### GET /plan

Planning mode interface for task breakdown and strategy.

**Returns:** `boss-ui/apps/plan.html`

---

### GET /build

Build mode interface for implementation and coding.

**Returns:** `boss-ui/apps/build.html`

---

### GET /ship

Ship mode interface for deployment and release.

**Returns:** `boss-ui/apps/ship.html`

---

### GET /shared/*

Static assets (CSS, JavaScript, components) shared across all pages.

**Examples:**
- `/shared/ui.css` - Common styles
- `/shared/api.js` - API client library
- `/shared/components.js` - Reusable UI components

**Base Path:** `boss-ui/shared/`

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

# System smoke test (from smoke agent)
curl http://127.0.0.1:4000/api/smoke | jq .

# Quick plan test (stub mode)
curl -X POST http://127.0.0.1:4000/api/plan \
  -H "Content-Type: application/json" \
  -d '{"goal":"ping","stub":true}' | jq .

# UI pages
curl http://127.0.0.1:4000/
curl http://127.0.0.1:4000/chat
curl http://127.0.0.1:4000/plan

# Reports
curl http://127.0.0.1:4000/api/reports/summary | jq .
```

### Run All Tests

```bash
# Comprehensive smoke test suite (API + UI + MCP)
bash ./run/smoke_api_ui.sh

# Full atomic operations (all 4 phases)
bash ./run/ops_atomic.sh
```

### Check Logs

```bash
tail -f /tmp/boss-api.out  # stdout
tail -f /tmp/boss-api.err  # stderr
```
