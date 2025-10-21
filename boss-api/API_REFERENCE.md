# boss-api v2.0 - API Reference

**Base URL:** `https://boss-api.ittipong-c.workers.dev`
**Version:** 2.0
**Status:** ✅ Production Ready

---

## Quick Reference

### V1 Endpoints (Backward Compatible)

```bash
# Health check
GET /healthz

# API capabilities
GET /api/capabilities

# Discord notification
POST /api/discord/notify
{
  "content": "Message",
  "level": "info|warn|error",
  "channel": "default"
}

# Reports summary
GET /api/reports/summary

# Latest report
GET /api/reports/latest

# List reports
GET /api/reports/list
```

### V2 Endpoints (New)

```bash
# List runs
GET /api/v2/runs?limit=20&agent=gc

# Get specific run
GET /api/v2/runs/:runId

# List memory entries
GET /api/v2/memory?agent=gc&limit=20

# Get specific memory entry
GET /api/v2/memory/:memoryId?agent=gc

# Get telemetry
GET /api/v2/telemetry?source=system_health

# Get approvals (stub)
GET /api/v2/approvals
```

---

## Detailed Endpoint Documentation

### GET /healthz

Health check endpoint.

**Response:**
```json
{
  "status": "ok",
  "version": "2.0",
  "timestamp": "2025-10-21T17:51:00.000Z",
  "worker": "boss-api-cloudflare"
}
```

---

### GET /api/capabilities

Returns API capabilities and available endpoints.

**Response:**
```json
{
  "ui": {
    "inbox": false,
    "preview": false,
    "prompt_composer": false,
    "connectors": false
  },
  "features": {
    "discord": true,
    "reports": true,
    "github": true,
    "memory": true,
    "telemetry": true
  },
  "endpoints": {
    "v1": {
      "healthz": true,
      "discord_notify": true,
      "reports_summary": true,
      "reports_latest": true,
      "reports_list": true
    },
    "v2": {
      "runs": true,
      "runs_detail": true,
      "memory": true,
      "memory_detail": true,
      "telemetry": true,
      "approvals": true
    }
  }
}
```

---

### POST /api/discord/notify

Send a Discord notification.

**Request:**
```json
{
  "content": "Your message here",
  "level": "info",
  "channel": "default"
}
```

**Levels:** `info`, `warn`, `error`

**Response:**
```json
{
  "ok": true
}
```

---

### GET /api/reports/summary

Get OPS summary from GitHub.

**Response:**
```json
{
  "status": "operational",
  "last_update": "2025-10-21T17:00:00Z",
  ...
}
```

---

### GET /api/reports/list

List available reports.

**Response:**
```json
{
  "files": [
    "OPS_ATOMIC_251019_193856.md",
    "OPS_ATOMIC_251019_120000.md",
    ...
  ]
}
```

---

### GET /api/reports/latest

Get the latest report in markdown format.

**Response:** (text/markdown)
```markdown
# OPS Atomic Run – 2025-10-19T19:38:56Z
...
```

---

### GET /api/v2/runs

List run reports from `g/reports/`.

**Query Parameters:**
- `limit` (default: 20) - Max number of results
- `agent` (optional) - Filter by agent

**Response:**
```json
{
  "runs": [
    {
      "id": "OPS_ATOMIC_251019_193856",
      "filename": "OPS_ATOMIC_251019_193856.md",
      "url": "https://github.com/Ic1558/02luka/blob/main/g/reports/...",
      "size": 12345,
      "sha": "abc123..."
    }
  ],
  "count": 1
}
```

**Example:**
```bash
curl "https://boss-api.ittipong-c.workers.dev/api/v2/runs?limit=5"
```

---

### GET /api/v2/runs/:runId

Get specific run report by ID.

**Parameters:**
- `runId` - Report ID (e.g., `OPS_ATOMIC_251019_193856`)

**Response:**
```json
{
  "id": "OPS_ATOMIC_251019_193856",
  "filename": "OPS_ATOMIC_251019_193856.md",
  "content": "# Full report content...",
  "url": "https://github.com/...",
  "size": 12345,
  "sha": "abc123..."
}
```

**Example:**
```bash
curl "https://boss-api.ittipong-c.workers.dev/api/v2/runs/OPS_ATOMIC_251019_193856"
```

---

### GET /api/v2/memory

List memory entries from `memory/<agent>/`.

**Query Parameters:**
- `agent` (default: `gc`) - Agent name
- `limit` (default: 20) - Max number of results

**Response:**
```json
{
  "memories": [
    {
      "id": "session_251021_195714_note",
      "filename": "session_251021_195714_note.md",
      "agent": "gc",
      "url": "https://github.com/...",
      "size": 5678,
      "sha": "def456..."
    }
  ],
  "count": 1,
  "agent": "gc"
}
```

**Example:**
```bash
curl "https://boss-api.ittipong-c.workers.dev/api/v2/memory?agent=gc&limit=10"
```

---

### GET /api/v2/memory/:memoryId

Get specific memory entry.

**Parameters:**
- `memoryId` - Memory ID (e.g., `session_251021_195714_note`)

**Query Parameters:**
- `agent` (default: `gc`) - Agent name

**Response:**
```json
{
  "id": "session_251021_195714_note",
  "filename": "session_251021_195714_note.md",
  "agent": "gc",
  "content": "# Full memory content...",
  "url": "https://github.com/...",
  "size": 5678,
  "sha": "def456..."
}
```

**Example:**
```bash
curl "https://boss-api.ittipong-c.workers.dev/api/v2/memory/session_251021_195714_note?agent=gc"
```

---

### GET /api/v2/telemetry

Get telemetry data from `f/ai_context/`.

**Query Parameters:**
- `source` (default: `system_health`) - Data source
  - `system_health` - System health metrics
  - `current_work` - Current work context
  - `daily` - Daily context snapshot
  - `minimal` - Minimal context

**Response:**
```json
{
  "source": "system_health",
  "data": {
    "cpu": 45.2,
    "memory": 2048,
    ...
  },
  "updated_at": "abc123..."
}
```

**Example:**
```bash
curl "https://boss-api.ittipong-c.workers.dev/api/v2/telemetry?source=current_work"
```

---

### GET /api/v2/approvals

Get approval workflows (stub - not yet implemented).

**Response:**
```json
{
  "approvals": [],
  "count": 0,
  "note": "Approval workflows not yet implemented"
}
```

---

## Rate Limiting

- **Limit:** 100 requests per minute per IP
- **Window:** 60 seconds
- **Status Code:** 429 (Rate limit exceeded)

---

## CORS

All endpoints include CORS headers:
```
Access-Control-Allow-Origin: *
Access-Control-Allow-Methods: GET, POST, OPTIONS
Access-Control-Allow-Headers: Content-Type, Authorization
```

---

## Error Responses

All errors return JSON:

```json
{
  "error": "Error message here"
}
```

**Common Status Codes:**
- `400` - Bad Request
- `404` - Not Found
- `429` - Rate Limit Exceeded
- `500` - Internal Server Error
- `502` - Upstream Service Error
- `503` - Service Unavailable

---

## Testing Commands

```bash
# Test health
curl https://boss-api.ittipong-c.workers.dev/healthz | jq

# Test capabilities
curl https://boss-api.ittipong-c.workers.dev/api/capabilities | jq

# Get latest runs
curl "https://boss-api.ittipong-c.workers.dev/api/v2/runs?limit=5" | jq

# Get specific run
curl "https://boss-api.ittipong-c.workers.dev/api/v2/runs/OPS_ATOMIC_251019_193856" | jq

# Test Discord notification (requires webhook configured)
curl -X POST https://boss-api.ittipong-c.workers.dev/api/discord/notify \
  -H "Content-Type: application/json" \
  -d '{"content":"Test message","level":"info"}'
```

---

**Last Updated:** 2025-10-21
**Version:** 2.0
**Status:** ✅ Production Ready
