# Phase 7.6: Hybrid Embeddings System

**Status:** ✅ PRODUCTION READY
**Date:** 2025-10-22
**Previous:** Phase 7.5 (SQLite FTS), Phase 6 (TF-IDF Memory)
**Implementation:** 251022_HYBRID_VECTOR_DB_IMPLEMENTATION.md
**Verification:** 251022_HYBRID_VDB_VERIFICATION.md

---

## Executive Summary

Phase 7.6 introduces a **hybrid vector database** combining semantic embeddings (all-MiniLM-L6-v2) with full-text search (SQLite FTS5) for intelligent documentation retrieval. This eliminates the "waste paper" problem where 40% of critical documentation was unindexed and unsearchable.

### Key Achievements

- ✅ **100% Documentation Coverage**: 4,002 chunks from 258 documents (zero waste paper)
- 🚀 **Exceptional Performance**: 7-8ms average query time (12x better than <100ms target)
- 🧠 **Semantic Understanding**: Finds "token savings" when searching "cost reduction"
- ⚡ **Offline-First**: No external APIs, runs on CPU using ONNX runtime
- 🔄 **Backward Compatible**: Old commands (--search, --recall) still work

### Why Phase 7.6?

**Before (Phase 6 + 7.5):**
- 27 memories indexed (TF-IDF)
- 0/41 docs/*.md files indexed (0%)
- 125/185 g/reports/*.md files indexed (68%)
- ~30,000 words of critical documentation unsearchable
- Keyword-only matching (no semantic understanding)

**After (Phase 7.6):**
- 4,002 semantic chunks indexed
- 41/41 docs/*.md files indexed (100%) ✅
- 185+/185 g/reports/*.md files indexed (100%) ✅
- Zero waste paper ✅
- Full semantic understanding ✅

---

## Architecture

### 3-Stage Hybrid Pipeline

```
┌─────────────────────────────────────────────────────────────┐
│ Stage 1: FTS Pre-filter (Fast)                              │
│                                                              │
│ Input: User query "token efficiency improvements"           │
│ Process: SQLite FTS5 full-text search                       │
│ Output: Top 50 candidates from FTS ranking                  │
│ Performance: ~4ms (62% of total time)                       │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ Stage 2: Embedding Rerank (Precise)                         │
│                                                              │
│ Input: 50 FTS candidates                                    │
│ Process: Generate query embedding, compute cosine similarity│
│ Model: all-MiniLM-L6-v2 (384 dimensions)                   │
│ Output: Semantic similarity scores for each candidate       │
│ Performance: ~3ms (36% of total time)                       │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ Stage 3: Hybrid Scoring (Balanced)                          │
│                                                              │
│ Formula: Final = (0.3 × FTS_score) + (0.7 × Semantic_score)│
│ Rationale: Prioritize semantic match, use FTS as filter     │
│ Output: Top 10 results sorted by final score                │
│ Performance: ~0.1ms (2% of total time)                      │
└─────────────────────────────────────────────────────────────┘
```

### Technology Stack

| Component | Technology | Details |
|-----------|------------|---------|
| **Embeddings** | @xenova/transformers | ONNX runtime, CPU-only, no GPU needed |
| **Model** | all-MiniLM-L6-v2 | 384 dimensions, 80MB, sentence-transformers |
| **Database** | SQLite 3 | knowledge/02luka.db (14 MB) |
| **FTS Engine** | SQLite FTS5 | Virtual table for full-text search |
| **Chunking** | Markdown headers | Semantic sections with hierarchy |
| **Storage** | BLOB (Float32Array) | 1,536 bytes per embedding (384 × 4) |

### Why all-MiniLM-L6-v2?

**Selection Criteria:**
1. **Size**: 80MB (fits in memory, fast loading)
2. **Quality**: 384 dimensions (good semantic representation)
3. **Speed**: Optimized for CPU inference (ONNX runtime)
4. **Offline**: No API keys, no external dependencies
5. **Proven**: Industry-standard sentence-transformers model

**Alternatives Considered:**
- ❌ OpenAI text-embedding-3-small: Requires API key, costs money, network latency
- ❌ BERT-base: 110M parameters, too slow for CPU
- ❌ USE (Universal Sentence Encoder): TensorFlow dependency, larger model

---

## Database Schema

### document_chunks Table

```sql
CREATE TABLE document_chunks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  doc_path TEXT NOT NULL,              -- Relative path from repo root
  chunk_index INTEGER NOT NULL,         -- Position in document (0-based)
  text TEXT NOT NULL,                   -- Chunk content with hierarchy
  embedding BLOB,                       -- 384 floats = 1,536 bytes
  metadata TEXT,                        -- JSON: hierarchy, tags, importance
  indexed_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for performance
CREATE INDEX idx_doc_path ON document_chunks(doc_path);
```

### document_chunks_fts Virtual Table

```sql
-- FTS5 for keyword search
CREATE VIRTUAL TABLE document_chunks_fts
USING fts5(
  text,
  content='document_chunks',
  content_rowid='id'
);
```

### Example Data

```json
{
  "id": 1423,
  "doc_path": "docs/PHASE7_2_DELEGATION.md",
  "chunk_index": 3,
  "text": "# Phase 7.2: Local Orchestrator & Delegation\n\n## Architecture\n\nThe delegation system reduces token costs by 89%...",
  "embedding": "<1536 bytes binary>",
  "metadata": {
    "hierarchy": ["Phase 7.2: Local Orchestrator & Delegation"],
    "section": "Architecture",
    "tags": ["success", "phase-doc", "delegation"],
    "importance": 0.65,
    "level": 2,
    "wordCount": 245,
    "hasCode": true,
    "hasList": false
  },
  "indexed_at": "2025-10-22 02:15:34"
}
```

---

## Commands

### Basic Usage

```bash
# Hybrid search (best for most queries)
node knowledge/index.cjs --hybrid "query"

# With timing breakdown
node knowledge/index.cjs --verify "query"

# Benchmark performance
node knowledge/index.cjs --bench --iters=30

# Reindex all documents
node knowledge/index.cjs --reindex

# Database statistics
node knowledge/index.cjs --stats
```

### Example Queries

**Semantic Search:**
```bash
# Finds documents about token efficiency, cost reduction, optimization
node knowledge/index.cjs --hybrid "token efficiency improvements"

# Finds delegation docs, architecture, Phase 7.2 completion report
node knowledge/index.cjs --hybrid "how to reduce costs"

# Finds performance benchmarks, optimization guides
node knowledge/index.cjs --hybrid "performance optimization strategies"
```

**Version/Phase Searches:**
```bash
# Handles periods correctly (phase 7.2, not "phase 7" and "2")
node knowledge/index.cjs --hybrid "phase 7.2 delegation"

# Handles version numbers
node knowledge/index.cjs --hybrid "version 2.0 deployment"

# Handles hyphens in identifiers
node knowledge/index.cjs --hybrid "boss-api v2.0"
```

**Concept Discovery:**
```bash
# Finds related concepts: RAG, embeddings, vector search
node knowledge/index.cjs --hybrid "RAG system architecture"

# Finds: mcp_verify/, MCP Docker, verification reports
node knowledge/index.cjs --hybrid "MCP verification status"
```

### Output Format

```json
{
  "query": "token efficiency improvements",
  "results": [
    {
      "doc_path": "g/reports/RAG_QUICK_REFERENCE.md",
      "chunk_index": 2,
      "snippet": "...Token Efficiency: 89% savings through delegation...",
      "scores": {
        "fts": 0.85,        // FTS5 rank score (normalized)
        "semantic": 0.72,   // Cosine similarity
        "final": 0.759      // (0.3 × 0.85) + (0.7 × 0.72)
      }
    },
    // ... 9 more results
  ],
  "count": 10,
  "timings": {
    "fts_ms": 4.37,
    "embedding_ms": 2.55,
    "rerank_ms": 0.11,
    "total_ms": 7.03
  }
}
```

---

## Performance Metrics

### Benchmark Results (30 iterations, 39 unique queries)

| Metric | Value | Target | Status |
|--------|-------|--------|--------|
| **Mean** | 7.04ms | <100ms | 🚀 14x better |
| **Median** | 6.62ms | <100ms | 🚀 15x better |
| **P95** | 17.47ms | <100ms | 🚀 5.7x better |
| **P99** | 19.83ms | <100ms | 🚀 5x better |
| **Max** | 20.16ms | <100ms | ✅ 5x better |

### Stage Breakdown (Mean)

| Stage | Time (ms) | Percentage |
|-------|-----------|------------|
| FTS Pre-filter | 4.37 | 62% |
| Embedding | 2.55 | 36% |
| Rerank | 0.11 | 2% |
| **Total** | **7.03** | **100%** |

### Indexing Performance

- **Rate**: 31.2 chunks/second
- **Total Time**: 128.3 seconds for 258 files
- **Chunks Created**: 4,002 semantic chunks
- **Database Size**: 14 MB (5.86 MB embeddings + 1.27 MB text + 6.87 MB overhead)

---

## Comparison with Previous Phases

### Phase 6: TF-IDF Vector Memory

**Technology:**
- TF-IDF vectorization (statistical)
- g/memory/vector_index.json (file-backed)
- memory/index.cjs (--remember, --recall)

**Coverage:**
- 27 memories only
- Manual storage required
- No automatic document indexing

**Use Case:**
- Agent memory of past experiences
- Successful plans, solutions, errors

**Still Available:** Yes (--recall command)

### Phase 7.5: SQLite FTS

**Technology:**
- SQLite FTS5 (full-text search)
- knowledge/02luka.db
- knowledge/sync.cjs (JSON → SQLite)

**Coverage:**
- 125/185 reports (68%)
- 0/41 docs (0%)
- Keyword matching only

**Use Case:**
- Fast keyword search
- Exact term matching

**Still Available:** Yes (--search command)

### Phase 7.6: Hybrid Embeddings (Current)

**Technology:**
- all-MiniLM-L6-v2 embeddings (semantic)
- SQLite FTS5 (keyword pre-filter)
- Hybrid scoring (30% FTS + 70% semantic)

**Coverage:**
- 258 documents (100%)
- 4,002 semantic chunks
- Full semantic understanding

**Use Case:**
- **Primary search method**
- Concept discovery
- Related document finding
- Before asking CLC questions

### Comparison Table

| Feature | Phase 6 (TF-IDF) | Phase 7.5 (FTS) | Phase 7.6 (Hybrid) |
|---------|------------------|-----------------|-------------------|
| **Coverage** | 27 memories | 125 reports (68%) | 258 docs (100%) ✅ |
| **Chunks** | 27 | N/A | 4,002 ✅ |
| **Docs Indexed** | 0% | 0% | 100% ✅ |
| **Reports Indexed** | N/A | 68% | 100% ✅ |
| **Query Speed** | N/A | ~10ms | 7-8ms ✅ |
| **Semantic** | ❌ | ❌ | ✅ |
| **Storage** | 100 KB | 7 MB | 14 MB |
| **Special Chars** | N/A | ⚠️ | ✅ Fixed |
| **Use Case** | Agent memory | Keyword search | **Primary search** ✅ |

---

## Implementation Details

### Component Files

| File | Lines | Purpose |
|------|-------|---------|
| **embedder.cjs** | 76 | all-MiniLM-L6-v2 wrapper (lazy-loaded singleton) |
| **chunker.cjs** | 202 | Semantic document splitting by headers |
| **search.cjs** | 179 | 3-stage hybrid search pipeline |
| **reindex-all.cjs** | 188 | Batch indexing (31.2 chunks/sec) |
| **index.cjs** | 95+ | CLI interface with all commands |
| **util/timer.cjs** | 74 | High-precision timing (hrtime) |
| **util/benchmark.cjs** | 169 | Performance benchmarking |
| **bench_queries.txt** | 39 | Test queries for benchmarking |

### Key Algorithms

**1. Semantic Chunking (chunker.cjs)**
```javascript
function semanticChunk(content, metadata = {}) {
  // Split by markdown headers (preserves hierarchy)
  const sections = parseMarkdownSections(content);

  // For each section, create chunk with context
  for (let i = 0; i < sections.length; i++) {
    const hierarchy = buildHierarchy(sections, i);
    const chunkText = formatChunkWithContext(filename, hierarchy, section);
    const tags = extractTags(section.content);
    const importance = calculateImportance(filepath, section, tags);

    chunks.push({ doc_path, chunk_index: i, text: chunkText, ... });
  }
  return chunks;
}
```

**2. FTS Pre-filter (search.cjs)**
```javascript
async function ftsPrefilter(db, query, limit) {
  // Tokenize and handle special characters
  const ftsQuery = query
    .split(/\s+/)
    .filter(Boolean)
    .map(term => `"${term.replace(/"/g, '""')}"`)
    .join(' OR ');

  // Query FTS5 virtual table
  const sql = `
    SELECT id, doc_path, chunk_index, text, rank
    FROM document_chunks_fts
    WHERE document_chunks_fts MATCH ?
    ORDER BY rank
    LIMIT ?
  `;
  return await db.all(sql, [ftsQuery, limit]);
}
```

**3. Hybrid Scoring (search.cjs)**
```javascript
async function hybridSearch(db, query, limit = 10) {
  // Stage 1: FTS pre-filter
  const candidates = await ftsPrefilter(db, query, 50);

  // Stage 2: Embedding rerank
  const queryEmbedding = await getEmbedding(query);
  const scored = candidates.map(c => ({
    ...c,
    fts_score: normalizeFtsScore(c.rank),
    semantic_score: cosineSimilarity(queryEmbedding, c.embedding)
  }));

  // Stage 3: Hybrid scoring
  const final = scored.map(c => ({
    ...c,
    final_score: (0.3 * c.fts_score) + (0.7 * c.semantic_score)
  })).sort((a, b) => b.final_score - a.final_score);

  return final.slice(0, limit);
}
```

---

## Use Cases

### 1. Finding Documentation Before Asking Questions

**Scenario:** You want to know how Phase 7.2 delegation works.

**Old Way (Expensive):**
```
Ask CLC: "How does Phase 7.2 delegation work?"
→ 500+ tokens used
→ 10-20 second response time
→ May not cite specific docs
```

**New Way (Zero Cost):**
```bash
node knowledge/index.cjs --hybrid "phase 7.2 delegation architecture"
→ 0 tokens used
→ 7ms response time
→ Returns: PHASE7_2_DELEGATION.md (score: 0.85)
→ Read the doc directly
```

**Token Savings:** 500+ tokens per query

### 2. Concept Discovery

**Scenario:** You want to understand token efficiency strategies.

```bash
node knowledge/index.cjs --hybrid "token efficiency improvements"
```

**Returns:**
- RAG_QUICK_REFERENCE.md (delegation, 89% savings)
- 251022_RAG_SYSTEM_CLARIFICATION.md (TF-IDF vs embeddings)
- PHASE7_2_7_5_COMPLETION_REPORT.md (Phase 7 achievements)

**Value:** Discovers related concepts across multiple documents

### 3. Version/Feature Lookups

**Scenario:** You want to find boss-api v2.0 deployment docs.

```bash
node knowledge/index.cjs --hybrid "boss-api v2.0 deployment"
```

**Returns:**
- 251021_boss_api_v2_deployment.md (score: 0.78)
- Handles special characters correctly (hyphens, periods)

### 4. Performance Debugging

**Scenario:** System is slow, need to find optimization guides.

```bash
node knowledge/index.cjs --hybrid "performance optimization strategies"
```

**Returns:**
- Performance benchmark reports
- Optimization guides
- Past solutions to similar issues

---

## Maintenance

### Reindexing

**When to Reindex:**
- After adding many new documents
- After changing chunking logic
- To fix index corruption
- Database performance degraded

**Command:**
```bash
node knowledge/index.cjs --reindex
# Or directly:
node knowledge/reindex-all.cjs
```

**Performance:** ~2 minutes for 258 files (31.2 chunks/sec)

### Storage Management

**Database File:** `knowledge/02luka.db` (14 MB)

**Check Size:**
```bash
du -h knowledge/02luka.db
```

**Optimize Database:**
```bash
sqlite3 knowledge/02luka.db "VACUUM; REINDEX;"
```

**Full Rebuild:**
```bash
rm knowledge/02luka.db
node knowledge/reindex-all.cjs
```

### Model Updates

The embedding model (all-MiniLM-L6-v2) is cached locally after first download (80MB). Stored in:
- `~/.cache/huggingface/` (Linux/macOS)
- `%USERPROFILE%\.cache\huggingface\` (Windows)

No updates needed unless you want to change models.

---

## Troubleshooting

### Issue: No Results for Query

**Cause:** Query may be too specific or use unsupported syntax

**Solution:** Simplify query, use common terms
```bash
# Instead of: "how do I optimize the performance of queries"
node knowledge/index.cjs --hybrid "query performance optimization"
```

### Issue: Slow First Query (~500ms)

**Cause:** First query loads embedding model (80MB)

**Solution:** This is expected behavior. Subsequent queries are fast (<10ms).

**Explanation:**
- Model is lazy-loaded on first use
- Subsequent queries reuse cached model
- First query includes model download + initialization

### Issue: Database Locked

**Cause:** Another process has the database open

**Solution:** Check for other processes
```bash
lsof knowledge/02luka.db
```

### Issue: FTS Syntax Error (Should Be Fixed)

**Cause:** Special characters in query (should be handled automatically)

**Solution:** The system now handles special chars automatically. If errors persist:
1. Check search.cjs line 73-80 (tokenization logic)
2. Report issue with specific query
3. Fallback to simpler query

---

## Integration Opportunities

### 1. CLC Integration

**Use hybrid search in knowledge queries:**
```javascript
const { hybridSearch } = require('./knowledge/search.cjs');
const results = await hybridSearch(db, userQuery);
// Present results to user
```

### 2. Boss API Endpoint

**Expose search via HTTP:**
```javascript
app.get('/api/v2/search', async (req, res) => {
  const { q } = req.query;
  const results = await hybridSearch(db, q);
  res.json(results);
});
```

### 3. Memory System Integration

**Auto-index agent memories:**
```javascript
// After agent creates memory
const memory = { kind: 'solution', text: '...' };
await remember(memory);
// Trigger reindex
await reindexAll();
```

### 4. Web UI

**Create search interface:**
- Input: Search box
- Output: Results with snippets, scores, doc links
- Features: Filters (by doc path, date), sort by score

---

## Future Enhancements

### Planned (Optional)

1. **LRU Cache**: Query embedding cache (95% speedup for repeated queries)
2. **Context Expansion**: Fetch neighboring chunks for better context
3. **Auto-Reindex**: Watch files and reindex on changes (chokidar + LaunchAgent)
4. **Multi-Vector Search**: Query + negative examples
5. **Temporal Decay**: Boost recent documents in scoring

### Integration Ideas

1. **Luka UI**: Search interface in dashboard
2. **Boss API**: /api/v2/search endpoint
3. **AI Agents**: Auto-search before answering questions
4. **MCP Integration**: Expose search via MCP protocol

---

## Related Documentation

### Implementation Reports
- **Implementation**: `g/reports/251022_HYBRID_VECTOR_DB_IMPLEMENTATION.md`
- **Verification**: `g/reports/251022_HYBRID_VDB_VERIFICATION.md`
- **RAG System**: `g/reports/251022_RAG_SYSTEM_CLARIFICATION.md`
- **Quick Reference**: `g/reports/RAG_QUICK_REFERENCE.md`

### Phase Documentation
- **Phase 7 Overview**: `docs/PHASE7_COGNITIVE_LAYER.md`
- **Phase 7.2 Delegation**: `docs/PHASE7_2_DELEGATION.md`
- **Phase 7.5 Knowledge**: `docs/PHASE7_5_KNOWLEDGE.md`
- **Context Engineering**: `docs/CONTEXT_ENGINEERING.md`

### System Overview
- **02luka.md**: Main system documentation (Phase 7.6+ section)
- **knowledge/README.md**: User guide with quick start

### AI Context
- **f/ai_context/ai_context_entry.md**: AI agent entry point
- **~/.claude/CLAUDE.md**: Global AI instructions

---

## FAQ

**Q: How does this differ from traditional RAG?**
A: We use local embeddings (not OpenAI API), hybrid FTS+embeddings (not pure vector), and file-backed SQLite (not cloud DBs like Pinecone).

**Q: Can I use a different embedding model?**
A: Yes, but you'll need to modify `embedder.cjs` and update the model name. all-MiniLM-L6-v2 is optimized for speed/quality balance.

**Q: What happens if I delete the database?**
A: Just reindex: `node knowledge/index.cjs --reindex`. All source files are unchanged.

**Q: Is this GPU-accelerated?**
A: No, runs on CPU using ONNX runtime. Fast enough for <5K chunks.

**Q: How do I add more documents?**
A: Just add markdown files to docs/, g/reports/, or memory/ folders and reindex.

**Q: Can I search other file types (PDF, code)?**
A: Currently markdown only. PDF/code support would require additional parsers in chunker.cjs.

**Q: What's the maximum query length?**
A: No hard limit, but queries >100 words may be slower. Embeddings work best with 10-50 word queries.

---

**Last Updated:** 2025-10-22
**Status:** ✅ Production Ready
**Maintained By:** CLC (Implementation)
**Tag:** `v251022_phase7.6-hybrid-vector-db`
