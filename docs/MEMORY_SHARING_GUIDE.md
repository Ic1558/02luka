# 🧠 Memory Sharing Guide: Connecting 02LUKA Memory to External AI

**Date:** 2025-10-20
**Status:** ✅ Operational
**Scope:** Enable Cursor, Codex, Claude Desktop, and other AI tools to access 02LUKA vector memory

---

## Overview

The 02LUKA vector memory system stores semantic memories of past work—plans, solutions, errors, and insights. This guide shows how to make this memory accessible to AI assistants running outside the core 02LUKA system (Cursor, Codex, Claude Desktop, etc.).

## Three Access Methods

### Method 1: Direct File Access (Simplest)

**Use Case:** Local development in Cursor
**Latency:** Zero
**Security:** High (file system only)

AI tools can directly read the memory index file:

**File:** `g/memory/vector_index.json`

**In Cursor/Claude:**
```
@g/memory/vector_index.json
```

**In Chat Prompts:**
"Before suggesting a solution, check if similar work exists in g/memory/vector_index.json"

**Context File:**
Reference `.cursor/memory_context.md` in your Cursor workspace for instructions on how to query memory.

---

### Method 2: HTTP API (Most Flexible)

**Use Case:** Multi-device, remote access, web integrations
**Latency:** <100ms (local), ~200ms (remote)
**Security:** Requires authentication (tokens recommended for production)

#### Local API (Boss API running)

**Base URL:** `http://127.0.0.1:4000`

**Endpoints:**

```bash
# Recall memories (search)
GET /api/memory/recall?q=<query>[&kind=<type>][&topK=<N>]

# Remember new memory (store)
POST /api/memory/remember
Content-Type: application/json
{
  "kind": "solution",
  "text": "Your memory text here",
  "meta": { "commit": "abc123" }  // optional
}

# Get statistics
GET /api/memory/stats
```

**Examples:**

```bash
# Find Discord-related memories
curl 'http://127.0.0.1:4000/api/memory/recall?q=Discord+integration&topK=3'

# Store a new solution
curl -X POST http://127.0.0.1:4000/api/memory/remember \
  -H "Content-Type: application/json" \
  -d '{"kind":"solution","text":"Fixed CORS issue by adding credentials:true to fetch"}'

# Check memory stats
curl http://127.0.0.1:4000/api/memory/stats
```

#### Remote API (Cloudflare Worker)

**Base URL:** `https://boss-api.ittipong-c.workers.dev`

Same endpoints as local, accessible from anywhere. Add authentication if exposing publicly.

---

### Method 3: MCP Provider (Claude Desktop)

**Use Case:** Seamless integration with Claude Desktop
**Latency:** <50ms
**Security:** High (local MCP server)

**Configuration:**

Edit `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "02luka-memory": {
      "command": "node",
      "args": [
        "/path/to/02luka-repo/memory/index.cjs",
        "--mcp-server"
      ],
      "env": {
        "REPO_ROOT": "/path/to/02luka-repo"
      }
    }
  }
}
```

**Note:** MCP server mode is not yet implemented but can be added if needed.

---

## Setup Instructions

### Quick Start

```bash
# 1. Run setup script to verify configuration
cd /path/to/02luka-repo
bash scripts/setup_cursor_memory_bridge.sh

# 2. Ensure boss-api is running (for HTTP API access)
cd boss-api
node server.cjs

# 3. Test API access
curl http://127.0.0.1:4000/api/memory/stats
```

### Cursor/Codex Integration

**Step 1: Add Context File to Workspace**

In Cursor, reference `.cursor/memory_context.md` in your prompts or add to workspace context.

**Step 2: Train Your Workflow**

Example prompt for Cursor:

```
Before implementing this feature, please:
1. Query the memory system: node memory/index.cjs --recall "similar feature name"
2. Review any similar past implementations
3. Apply learned patterns from previous work
4. After successful implementation, record: node memory/index.cjs --remember solution "what was done"
```

**Step 3: Use HTTP API in Cursor Tasks**

```javascript
// Example: Query memory from Cursor terminal
const response = await fetch('http://127.0.0.1:4000/api/memory/recall?q=authentication');
const memories = await response.json();
console.log('Found memories:', memories.results);
```

---

## Integration Patterns

### Pattern 1: Pre-Task Memory Recall

**Before starting any task:**

```bash
# Search for similar past work
node memory/index.cjs --recall "task description here"

# OR via API
curl 'http://127.0.0.1:4000/api/memory/recall?q=task+description'
```

Review results to avoid duplicate effort and learn from past solutions.

### Pattern 2: Post-Success Memory Recording

**After completing a task successfully:**

```bash
# Record the solution
node memory/index.cjs --remember solution "Detailed description of what was done"

# OR via API
curl -X POST http://127.0.0.1:4000/api/memory/remember \
  -H "Content-Type: application/json" \
  -d '{"kind":"solution","text":"What I learned..."}'
```

**Automatic Recording:**
- OPS atomic runs record themselves on success
- Smoke tests record themselves on clean runs
- Manual recording for ad-hoc solutions

### Pattern 3: Error Pattern Learning

**When encountering errors:**

```bash
# Check if error was solved before
node memory/index.cjs --recall-kind error "error message keywords"

# If new, record the solution after fixing
node memory/index.cjs --remember error "Error: X. Solution: Y. Root cause: Z."
```

---

## API Response Format

### Recall Response

```json
{
  "results": [
    {
      "id": "solution_1760905940644_wk9zzyt",
      "kind": "solution",
      "text": "Fixed macOS date command incompatibility...",
      "meta": {},
      "timestamp": "2025-10-19T20:32:20.644Z",
      "similarity": 0.64
    }
  ],
  "count": 1
}
```

**Similarity Score:** 0.0 (no match) to 1.0 (perfect match)
**Typical Thresholds:**
- >0.6: Highly relevant
- 0.3-0.6: Potentially useful
- <0.3: Tangentially related

### Remember Response

```json
{
  "ok": true,
  "memory": {
    "id": "insight_1760906946748_miuxyug",
    "kind": "insight",
    "timestamp": "2025-10-19T20:49:06.748Z"
  }
}
```

### Stats Response

```json
{
  "totalMemories": 4,
  "byKind": {
    "plan": 2,
    "solution": 1,
    "insight": 1
  },
  "vocabularySize": 57,
  "indexFile": "/path/to/g/memory/vector_index.json"
}
```

---

## Memory Kinds Reference

| Kind | Purpose | Example |
|------|---------|---------|
| `plan` | Successful task plans and workflows | "Implemented Discord integration with 3 webhook channels" |
| `solution` | Bug fixes and problem resolutions | "Fixed macOS date command with \$(($(date +%s) * 1000))" |
| `error` | Error patterns and their fixes | "Error: EADDRINUSE. Solution: kill -9 $(lsof -ti:4000)" |
| `insight` | Learned patterns, optimizations | "TF-IDF vectors more lightweight than embeddings for this use case" |
| `config` | Configuration patterns that worked | "Discord webhook map as JSON in .env for multi-channel support" |

---

## Best Practices

### ✅ Do's

1. **Be Specific**: Store detailed, actionable information
2. **Use Appropriate Kinds**: Categorize memories correctly
3. **Query Before Acting**: Check memory before solving problems
4. **Record Successes**: Document what worked after completion
5. **Include Context**: Add metadata (commits, files, dates) when relevant

### ❌ Don'ts

1. **Don't Store Secrets**: Never put tokens, passwords, or API keys in memory
2. **Don't Be Vague**: "Fixed bug" is useless; "Fixed CORS by adding headers" is useful
3. **Don't Duplicate**: Check for existing memories before recording
4. **Don't Over-Store**: Record meaningful solutions, not trivial changes

---

## Troubleshooting

### Memory API Not Responding

```bash
# Check if boss-api is running
curl http://127.0.0.1:4000/healthz

# If not, restart
cd boss-api
node server.cjs

# Verify memory endpoints
curl http://127.0.0.1:4000/api/memory/stats
```

### Memory Index Corrupted

```bash
# Backup current index
cp g/memory/vector_index.json g/memory/vector_index.backup.json

# Clear and rebuild (last resort)
node memory/index.cjs --clear

# Restore from backup if needed
cp g/memory/vector_index.backup.json g/memory/vector_index.json
```

### Low Similarity Scores

If recall always returns low similarity:
- Use more specific keywords in queries
- Try different phrasings
- Check vocabulary size (may need more memories)
- Consider the memory might not exist yet

---

## Examples for Cursor Users

### Example 1: Before Implementing Feature

**In Cursor Terminal:**

```bash
# Search for similar features
node memory/index.cjs --recall "authentication OAuth integration"
```

**Review output**, then proceed with implementation using learned patterns.

### Example 2: After Bug Fix

**In Cursor Terminal:**

```bash
# Record the fix
node memory/index.cjs --remember solution \
  "Fixed TypeScript error 'Property X does not exist' by adding type assertion: (obj as CustomType).X"
```

### Example 3: API Integration in Code

**In Cursor Editor:**

```javascript
// Query memory programmatically
async function checkPreviousSolutions(query) {
  const res = await fetch(`http://127.0.0.1:4000/api/memory/recall?q=${encodeURIComponent(query)}`);
  const data = await res.json();

  if (data.results.length > 0) {
    console.log('Found previous solutions:');
    data.results.forEach(m => console.log(`- ${m.text} (${m.similarity.toFixed(2)})`));
  }
}

await checkPreviousSolutions('CORS error');
```

---

## Security Considerations

### Local Development

- Memory stored in `g/memory/vector_index.json` (file system security)
- Boss API binds to `127.0.0.1` (localhost only)
- No authentication required for local access

### Production Deployment

If exposing memory API publicly:

1. **Add Authentication**: Require API keys for remember/recall
2. **Rate Limiting**: Already implemented (100 req/min)
3. **Content Filtering**: Ensure no secrets are stored
4. **Access Control**: Limit who can write vs. read
5. **Audit Logging**: Track who accesses memory

**Example auth middleware** (add to boss-api/server.cjs):

```javascript
function requireAuth(req, res, next) {
  const token = req.headers['authorization'];
  if (token !== process.env.MEMORY_API_TOKEN) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  next();
}

app.post('/api/memory/remember', requireAuth, async (req, res) => {
  // ... existing code
});
```

---

## Related Documentation

- **Core Memory System**: `docs/CONTEXT_ENGINEERING.md` (Vector Memory System section)
- **API Reference**: `memory/index.cjs` (inline documentation)
- **Setup Script**: `scripts/setup_cursor_memory_bridge.sh`
- **Context File**: `.cursor/memory_context.md`

---

## Future Enhancements

Planned improvements:
- [ ] MCP server mode for Claude Desktop
- [ ] Automatic memory cleanup (remove old/irrelevant entries)
- [ ] Importance scoring for memory prioritization
- [ ] Cross-agent memory sharing protocols
- [ ] Memory clustering for pattern discovery
- [ ] Integration with CI/CD for automated learning from failures

---

**Status:** ✅ All three access methods operational
**Last Updated:** 2025-10-20
**Maintained By:** CLC + GG Core Team
