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
    "optimize_prompt_sources": ["heuristic", "openai"],
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

### GET /api/connectors/status

Returns readiness details for Anthropic, OpenAI, and local heuristic services powering the optimizer.

**Example:**
```bash
curl http://127.0.0.1:4000/api/connectors/status | jq .
```

**Response:**
```json
{
  "anthropic": { "ready": false, "reason": "ANTHROPIC_API_KEY not configured." },
  "openai": { "ready": true, "model": "o4-mini", "endpoint": "https://api.openai.com/v1/responses" },
  "local": { "ready": true, "optimize": { "source": "heuristic", "variants": 3 } }
}
```

---

### POST /api/optimize_prompt

Leverages the OpenAI Responses API (o4-mini by default) to rewrite prompts with structured, execution-ready guidance. When no OpenAI key is configured the endpoint automatically falls back to a rule-based heuristic engine that still returns three ranked variants.

**Request Body:**
```json
{
  "prompt": "Write an email reminding the team about the release.",
  "system": "You are a meticulous project coordinator.",
  "context": "Ship date is Friday; include testing status.",
  "model": "o4-mini"
}
```

**Response:**
```json
{
  "ok": true,
  "prompt": "System reminder for the release...",
  "variants": [
    {
      "id": "openai:o4-mini",
      "title": "OpenAI o4-mini",
      "score": 0.92,
      "source": "openai",
      "prompt": "System reminder for the release...",
      "rationale": "Validated requirements before rewriting."
    },
    {
      "id": "structured_blueprint",
      "title": "Structured Execution Blueprint",
      "score": 0.74,
      "source": "heuristic",
      "prompt": "# Role...",
      "rationale": "Organizes the request into role, context, deliverables, and QA gates."
    }
  ],
  "best": "openai:o4-mini",
  "engine": "openai:o4-mini",
  "reasoning": "Validated requirements before rewriting.",
  "usage": {
    "input_tokens": 312,
    "output_tokens": 181
  },
  "meta": {
    "provider": "openai",
    "model": "o4-mini",
    "endpoint": "responses",
    "status": "completed",
    "response_id": "resp_123"
  }
}
```

---

### POST /api/chat

Direct chat access to the OpenAI Responses API with reasoning support. Uses `OPENAI_CHAT_MODEL` if provided; otherwise falls back to `OPENAI_MODEL`.

**Request Body:**
```json
{
  "message": "Summarize the current deployment status.",
  "system": "You are an operations assistant.",
  "model": "o4-mini"
}
```

**Response:**
```json
{
  "ok": true,
  "response": "Deployment is on schedule...",
  "engine": "openai:o4-mini",
  "reasoning": "Reviewed runbook entries to confirm schedule.",
  "usage": {
    "input_tokens": 145,
    "output_tokens": 102
  },
  "meta": {
    "provider": "openai",
    "model": "o4-mini",
    "response_id": "resp_456"
  }
}
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
