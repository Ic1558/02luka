# Agent Integration: Hybrid Search Engine

**Status:** Phase 7.2+ Complete
**Deliverable:** WO-251022-GG-VDB-AGENT-INTEGRATION-v2
**Owner:** CLC

## Overview

The hybrid search engine is now integrated for use by all agents through multiple access methods:
- **MCP tools** (primary, requires MCP server setup)
- **Shell wrappers** (fallback, direct CLI access)
- **Redis pubsub** (future, task bus integration)

This document describes how agents can query the knowledge base using the hybrid search system.

---

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                    Agent Layer                      │
│  (CLC, Boss, Codex, Core, R&D, etc.)               │
└────────────────┬────────────────────────────────────┘
                 │
         ┌───────┴────────┐
         │                │
    ┌────▼─────┐    ┌────▼─────┐
    │   MCP    │    │  Shell   │
    │  Tools   │    │ Wrapper  │
    └────┬─────┘    └────┬─────┘
         │                │
         └────────┬───────┘
                  │
         ┌────────▼────────┐
         │  knowledge/     │
         │  index.cjs      │
         │  (Query Layer)  │
         └────────┬────────┘
                  │
         ┌────────▼────────┐
         │  Hybrid Search  │
         │  (FTS + Vector) │
         └────────┬────────┘
                  │
         ┌────────▼────────┐
         │  02luka.db      │
         │  (SQLite+FTS5)  │
         └─────────────────┘
```

---

## Access Methods

### 1. MCP Tool (Recommended)

**Tool:** `knowledge.hybrid_search`

**Parameters:**
- `query` (string, required): Search query (max 2000 chars)
- `top_k` (int, default: 8): Number of results to return
- `mode` (string, default: "hybrid"): Search mode
  - `"hybrid"`: FTS pre-filter + semantic rerank
  - `"verify"`: Hybrid + detailed timing breakdown
  - `"fts"`: FTS-only keyword search
- `print_snippet` (bool, default: false): Include text snippets

**Example:**
```json
{
  "tool": "knowledge.hybrid_search",
  "params": {
    "query": "phase 7.2 deployment",
    "top_k": 5,
    "mode": "hybrid"
  }
}
```

**Response Schema:**
```json
{
  "query": "phase 7.2 deployment",
  "results": [
    {
      "doc_path": "g/reports/251021_phase7_2_complete.md",
      "chunk_index": 2,
      "snippet": "Phase 7.2 [deployment] completed...",
      "scores": {
        "fts": 0.95,
        "semantic": 0.87,
        "final": 0.896
      }
    }
  ],
  "count": 5,
  "timings": {
    "fts_ms": 12.3,
    "embed_ms": 45.6,
    "rerank_ms": 8.2,
    "total_ms": 66.1
  }
}
```

---

### 2. Shell Wrapper (Fallback)

**Script:** `tools/hybrid_search.sh`

**Usage:**
```bash
tools/hybrid_search.sh "query string" [top_k] [mode] [print_snippet]
```

**Examples:**
```bash
# Basic hybrid search
tools/hybrid_search.sh "token savings" 8 hybrid

# With timing verification
tools/hybrid_search.sh "deployment schema" 10 verify

# FTS-only search
tools/hybrid_search.sh "error logs" 20 fts
```

**Safety Features:**
- Automatic quote escaping
- 2000 character length cap
- Input validation
- Error handling

---

### 3. Direct CLI (Advanced)

**Binary:** `node knowledge/index.cjs`

**Modes:**
```bash
# Hybrid search (FTS + embeddings)
node knowledge/index.cjs --hybrid "query" --k=10

# Hybrid search with timing
node knowledge/index.cjs --verify "query" --k=5

# FTS-only keyword search
node knowledge/index.cjs --search "query"

# TF-IDF vector search
node knowledge/index.cjs --recall "query"

# Database statistics
node knowledge/index.cjs --stats

# Run benchmark
node knowledge/index.cjs --bench --iters=30
```

---

## Performance Logging

All `--verify` mode queries automatically log performance metrics to:
```
g/reports/query_perf.jsonl
```

**Log Format:**
```json
{
  "ts": "2025-10-22T04:35:00.123Z",
  "query": "phase 7.2",
  "mode": "verify",
  "timings": {
    "fts_ms": 12.3,
    "embed_ms": 45.6,
    "rerank_ms": 8.2,
    "total_ms": 66.1
  },
  "resultCount": 5
}
```

**Use Cases:**
- Performance monitoring
- Query optimization
- Bottleneck identification
- Usage analytics

---

## Integration Testing

**Test Script:** `knowledge/test/integration_test.sh`

**Run Tests:**
```bash
cd /path/to/02luka-repo
bash knowledge/test/integration_test.sh
```

**Test Coverage:**
1. CLI `--verify` mode with perf logging
2. Shell wrapper with quote safety
3. MCP tool request format validation
4. Performance log creation and content

**Expected Output:**
```
Running integration tests...
[1/3] Testing --verify mode...
  ✓ --verify mode works, perf log created
[2/3] Testing shell wrapper...
  ✓ Shell wrapper executes safely
[3/3] Testing MCP tool request format...
  ✓ MCP request format valid
  ✓ Performance log has 2 entries

OK - All integration tests passed
```

---

## Agent Usage Examples

### Example 1: Boss Agent Context Loading
```bash
# Boss loads recent reports for daily summary
tools/hybrid_search.sh "deployment completion" 10 hybrid
```

### Example 2: CLC Query Verification
```bash
# CLC verifies phase 7.2 completion with timing
node knowledge/index.cjs --verify "phase 7.2 deployment" --k=5
```

### Example 3: Codex Reference Lookup
```json
// Codex uses MCP tool for context
{
  "tool": "knowledge.hybrid_search",
  "params": {
    "query": "vector database schema",
    "top_k": 3,
    "mode": "hybrid"
  }
}
```

### Example 4: Core Agent Diagnostics
```bash
# Core searches error patterns
tools/hybrid_search.sh "launchagent failure" 20 fts
```

---

## Configuration

### Database Path
Default: `knowledge/02luka.db`

To change:
```javascript
// knowledge/index.cjs
const DB_PATH = path.join(ROOT, 'knowledge', '02luka.db');
```

### Performance Log Path
Default: `g/reports/query_perf.jsonl`

To change:
```javascript
// knowledge/util/perf_log.cjs
const logPath = path.join(ROOT, 'g', 'reports', 'query_perf.jsonl');
```

### Search Parameters
Default hybrid search settings (in `knowledge/search.cjs`):
```javascript
{
  topK: 10,              // Results to return
  prefilterLimit: 50,    // FTS candidates
  ftsWeight: 0.3,        // FTS score weight
  semanticWeight: 0.7,   // Semantic score weight
  minScore: 0.0          // Minimum score threshold
}
```

---

## Troubleshooting

### Issue: Database not found
**Error:** `Database not found. Run: node knowledge/sync.cjs --full --export`

**Solution:**
```bash
cd knowledge
node sync.cjs --full --export
```

### Issue: No embeddings
**Error:** Semantic scores always 0.0

**Solution:** Re-index documents with embeddings:
```bash
node knowledge/reindex-all.cjs
```

### Issue: Query too slow
**Symptom:** `total_ms > 1000`

**Solutions:**
1. Reduce `prefilterLimit` (default: 50)
2. Lower `topK` results
3. Use FTS-only mode for simple keyword searches
4. Check database file size (should be < 100MB)

### Issue: No results returned
**Cause:** FTS pre-filter eliminated all candidates

**Solutions:**
1. Try simpler search terms
2. Use `--recall` mode (TF-IDF only)
3. Check if documents are indexed: `node knowledge/index.cjs --stats`

---

## Performance Benchmarks

Typical query times (M1 Mac, 14MB database):

| Operation          | Time (ms) | Notes                          |
|--------------------|-----------|--------------------------------|
| FTS pre-filter     | 10-20     | SQLite FTS5 index              |
| Query embedding    | 40-60     | Ollama nomic-embed-text        |
| Semantic rerank    | 5-15      | Cosine similarity (50 chunks)  |
| **Total (hybrid)** | **60-95** | 3-stage pipeline               |
| FTS-only           | 10-20     | Skip embedding steps           |

**Optimization Tips:**
- Use `prefilterLimit=20` for faster queries (default: 50)
- Use FTS-only mode for simple keyword searches
- Cache query embeddings for repeated queries

---

## Maintenance

### Regular Tasks

**1. Export Knowledge Base**
```bash
node knowledge/index.cjs --export
# Creates: knowledge/exports/02luka_YYYYMMDD_HHMMSS.json
```

**2. Re-index After Updates**
```bash
node knowledge/reindex-all.cjs
# Updates: FTS index + embeddings
```

**3. Clean Performance Logs**
```bash
# Archive old logs
mv g/reports/query_perf.jsonl g/reports/query_perf_$(date +%Y%m%d).jsonl
touch g/reports/query_perf.jsonl
```

**4. Run Benchmarks**
```bash
node knowledge/index.cjs --bench --iters=30
# Output: Median, P95, P99 latencies
```

---

## Future Enhancements (Phase 8+)

- [ ] Redis pubsub integration (task bus queries)
- [ ] MCP server deployment (MCP-based agents)
- [ ] Query caching layer (Redis)
- [ ] Batch query API
- [ ] Webhook notifications (query alerts)
- [ ] Multi-language support (non-English queries)
- [ ] Custom embedding models
- [ ] Query suggestion engine

---

## Related Documentation

- `knowledge/README.md` - Vector database architecture
- `docs/RAG_QUICK_REFERENCE.md` - RAG system overview
- `g/reports/251022_HYBRID_VDB_VERIFICATION.md` - Phase 7.2 verification
- `g/reports/251022_HYBRID_VECTOR_DB_IMPLEMENTATION.md` - Implementation details

---

**Last Updated:** 2025-10-22
**Version:** v1.0.0 (WO-251022-GG-VDB-AGENT-INTEGRATION-v2)
