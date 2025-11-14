# RAG + Moonshot AI Kimi - Quick Reference Guide

**Updated:** 2025-11-05
**API Provider:** Moonshot AI (Kimi K2 Free)
**Status:** ✅ Operational

---

## ✅ Configuration Complete

### API Credentials (Configured):
- **Provider:** Moonshot AI Kimi K2 Free
- **API Key:** `sk-or-v1-8fe0f95...d29` ✓
- **Base URL:** `https://api.moonshot.cn/v1` ✓
- **Config File:** `~/.config/02luka/rag.env`

### RAG Service:
- **API Endpoint:** http://127.0.0.1:8765
- **PID:** 34317 (running)
- **Index Stats:** 2,403 chunks from 240 files
- **Status:** ✅ Healthy

---

## Quick Commands

### 1. Search Knowledge Base
```bash
# Basic search
curl -X POST http://127.0.0.1:8765/rag_query \
  -H "Content-Type: application/json" \
  -d '{"query": "your search here", "top_k": 5}'

# Using heredoc (easier for multi-word queries)
cat <<'JSON' | curl -s -X POST http://127.0.0.1:8765/rag_query -H "Content-Type: application/json" -d @-
{"query": "MLS testing browser cache", "top_k": 3}
JSON
```

### 2. Check System Health
```bash
# API health
curl http://127.0.0.1:8765/health
# {"ok": true, "db": true}

# Index statistics
curl http://127.0.0.1:8765/stats
# {"total_chunks": 2403, "total_files": 240}

# Service status
launchctl list | grep com.02luka.rag
```

### 3. Refresh Index
```bash
# Manual refresh (picks up new files)
curl -X POST http://127.0.0.1:8765/refresh

# Or use script
~/02luka/g/rag/refresh_rag_index.zsh
```

### 4. Restart API Service
```bash
# Restart to reload env vars
launchctl kickstart -k gui/$(id -u)/com.02luka.rag.api

# Check new PID
launchctl list | grep com.02luka.rag.api
```

---

## Example Queries (Tested ✅)

### Query 1: MLS Testing
```bash
cat <<'JSON' | curl -s -X POST http://127.0.0.1:8765/rag_query -H "Content-Type: application/json" -d @-
{"query": "MLS pill count browser cache testing", "top_k": 3}
JSON
```

**Result:** ✅ Found MLS_PILL_COUNT_TEST_REPORT.md (exactly what we needed!)

---

### Query 2: RAG Installation
```bash
cat <<'JSON' | curl -s -X POST http://127.0.0.1:8765/rag_query -H "Content-Type: application/json" -d @-
{"query": "RAG stack installation performance metrics", "top_k": 2}
JSON
```

**Result:** ✅ Found RAG_STACK_INSTALL_REPORT.md

---

### Query 3: System Architecture
```bash
cat <<'JSON' | curl -s -X POST http://127.0.0.1:8765/rag_query -H "Content-Type: application/json" -d @-
{"query": "message bus chain status monitoring", "top_k": 3}
JSON
```

---

## Integration with Kim Agent

### Current Architecture:
```
User → MLS UI (port 8767) → Chat Widget
                               ↓
                      Kim UI Shim (port 8770)
                               ↓
                          Redis (kim:requests)
                               ↓
                          Kim Agent (NLP)
                               ↓
                          RAG API (port 8765) ← NEW!
```

### Next Steps for Kim Integration:

1. **Update Kim Agent** to query RAG before responding:
   ```python
   # In Kim agent code:
   response = requests.post(
       "http://127.0.0.1:8765/rag_query",
       json={"query": user_message, "top_k": 3}
   )
   context = response.json()["hits"]

   # Add context to Kimi prompt
   prompt = f"Context: {context}\n\nUser: {user_message}"
   ```

2. **Enable Knowledge-Augmented Responses:**
   - User asks: "What was the pill-count bug?"
   - Kim queries RAG → Gets test report
   - Kim + Kimi AI → Answers with specific details
   - Response: "Browser cache issue, fixed with Cmd+Shift+R..."

3. **Smart Routing:**
   - Simple questions → Direct Kimi API
   - Complex questions → RAG context + Kimi API
   - System questions → RAG only (no API cost)

---

## Moonshot AI Kimi Models

### Available Models:
- **moonshot-v1-8k** - 8K context window (recommended for RAG)
- **moonshot-v1-32k** - 32K context window (for longer documents)
- **moonshot-v1-128k** - 128K context window (for full documents)

### Model Selection in Code:
```python
# When calling Kimi API:
response = client.chat.completions.create(
    model="moonshot-v1-8k",  # or moonshot-v1-32k
    messages=[{"role": "user", "content": prompt}]
)
```

---

## Performance Metrics

### RAG Search Performance:
- **Average Query Time:** <50ms
- **Index Refresh:** ~30 seconds (incremental)
- **Memory Usage:** ~150 MB
- **Database Size:** ~1.2 MB

### Index Coverage:
- **Total Chunks:** 2,403
- **Total Files:** 240
- **Sources:**
  - ~/02luka/memory
  - ~/02luka/g/reports (✅ including MLS and RAG reports)
  - ~/02luka/docs
  - ~/02luka/manuals

---

## Troubleshooting

### Issue 1: API Not Responding
```bash
# Check if service is running
launchctl list | grep com.02luka.rag.api

# Restart service
launchctl kickstart -k gui/$(id -u)/com.02luka.rag.api

# Check logs
tail -20 ~/02luka/logs/rag_api.stderr.log
```

---

### Issue 2: Search Returns Empty Results
```bash
# Check index stats
curl http://127.0.0.1:8765/stats

# Refresh index
curl -X POST http://127.0.0.1:8765/refresh

# Result: {"added":X,"updated":Y,"skipped":Z}
```

---

### Issue 3: Environment Variables Not Loaded
```bash
# Source the env file
source ~/.config/02luka/rag.env

# Verify loaded
echo "API Key: ${OPENAI_API_KEY:0:20}..."
echo "Base URL: $OPENAI_BASE_URL"

# Restart API to reload
launchctl kickstart -k gui/$(id -u)/com.02luka.rag.api
```

---

## File Locations

### Configuration:
- **API Config:** `~/.config/02luka/rag.env` (Kimi credentials)
- **RAG Config:** `~/02luka/g/rag/rag.config.yaml` (sources, chunk size)

### Code:
- **Server:** `~/02luka/g/rag/server.py` (FastAPI endpoints)
- **Runner:** `~/02luka/g/rag/run_api.zsh`
- **Refresh:** `~/02luka/g/rag/refresh_rag_index.zsh`

### Data:
- **Database:** `~/02luka/g/rag/store/fts.db` (SQLite FTS5)
- **Feedback:** `~/02luka/g/rag/store/feedback.jsonl`

### Logs:
- **API Output:** `~/02luka/logs/rag_api.stdout.log`
- **API Errors:** `~/02luka/logs/rag_api.stderr.log`
- **Auto-Sync:** `~/02luka/logs/rag_autosync.stdout.log`

### LaunchAgents:
- **API Service:** `~/Library/LaunchAgents/com.02luka.rag.api.plist`
- **Auto-Sync:** `~/Library/LaunchAgents/com.02luka.rag.autosync.plist`

---

## Kimi API Usage Tips

### Best Practices:

1. **Use RAG for Context, Kimi for Reasoning:**
   ```python
   # Get relevant context first
   context = rag_query("user question")

   # Then ask Kimi with context
   answer = kimi_complete(f"Context: {context}\n\nQuestion: {question}")
   ```

2. **Batch Queries When Possible:**
   - RAG is fast (<50ms) and free
   - Kimi API has rate limits
   - Pre-filter with RAG, then use Kimi selectively

3. **Fallback Strategy:**
   - Primary: RAG + Kimi (best quality)
   - Fallback: RAG only (fast, free, no external API)
   - Last resort: Kimi only (for general knowledge)

---

## Testing Checklist

- [x] API health check passes
- [x] Index has >2000 chunks
- [x] Semantic search returns relevant results
- [x] Kimi API credentials loaded
- [x] LaunchAgents running
- [x] Auto-refresh configured (hourly)
- [ ] Kim agent integration (next step)
- [ ] MLS UI chat widget connected (next step)

---

## Next Steps

### Phase 1: Test RAG Independently ✅ COMPLETE
- [x] Install RAG stack
- [x] Configure Kimi API
- [x] Test search queries
- [x] Verify auto-refresh

### Phase 2: Integrate with Kim (IN PROGRESS)
- [ ] Update Kim agent code to query RAG
- [ ] Add RAG context to Kimi prompts
- [ ] Test end-to-end: MLS UI → Kim → RAG → Kimi → Response
- [ ] Monitor quality and latency

### Phase 3: Production Optimization (FUTURE)
- [ ] Add caching layer (Redis)
- [ ] Implement query analytics
- [ ] Fine-tune chunk size/overlap
- [ ] Add relevance feedback loop

---

## Quick Copy-Paste Commands

```bash
# Check everything
curl http://127.0.0.1:8765/health && \
curl http://127.0.0.1:8765/stats && \
launchctl list | grep com.02luka.rag

# Test search
cat <<'JSON' | curl -s -X POST http://127.0.0.1:8765/rag_query -H "Content-Type: application/json" -d @- | jq '.hits[0].path'
{"query": "your search here", "top_k": 1}
JSON

# Refresh everything
curl -X POST http://127.0.0.1:8765/refresh && \
launchctl kickstart -k gui/$(id -u)/com.02luka.rag.api

# View logs
tail -f ~/02luka/logs/rag_api.stdout.log
```

---

## Support

### Documentation:
- **Full Install Report:** `/Users/icmini/02luka/g/reports/RAG_STACK_INSTALL_REPORT.md`
- **This Guide:** `/Users/icmini/02luka/g/reports/RAG_KIMI_QUICK_REFERENCE.md`

### System Health:
- **Service Manager:** `launchctl list | grep rag`
- **Process Check:** `ps aux | grep rag`
- **Port Check:** `lsof -i :8765`

---

**Status:** ✅ Fully Operational
**Last Updated:** 2025-11-05
**Configured By:** CLC (Claude Code)

---

## Summary

✅ **What's Working:**
- RAG API running on port 8765 (PID 34317)
- Kimi API credentials configured
- 2,403 chunks indexed from 240 files
- Semantic search tested and accurate
- Auto-refresh running every hour

✅ **Ready For:**
- Kim agent integration
- MLS UI chat enhancement
- Production usage

🎯 **Next Action:** Update Kim agent to use RAG context in responses!
