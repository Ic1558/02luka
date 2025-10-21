# Phase 7.6+: Hybrid Vector Database (Embeddings)

**Status:** ✅ PRODUCTION READY
**Date:** 2025-10-22
**Previous:** Phase 7.5 (SQLite FTS), Phase 6 (TF-IDF Memory)

---

## Overview

Hybrid semantic search system combining **embeddings + full-text search** for 100% documentation coverage with human-like understanding.

**Key Achievement:** Eliminated "waste paper" problem - 100% of docs/, reports/, and memory/ files now indexed and searchable.

### Features
- ✅ **Semantic Search**: all-MiniLM-L6-v2 embeddings (384 dims)
- ✅ **Hybrid Scoring**: FTS pre-filter + embedding rerank (30/70 split)
- ✅ **100% Coverage**: 4,002 chunks from 258 documents
- ✅ **Exceptional Performance**: 7-8ms avg query time (12x better than target)
- ✅ **Offline-First**: No external APIs, runs on CPU
- ✅ **Backward Compatible**: Old commands (--search, --recall) still work

---

## Quick Start

### Search Commands

```bash
# Hybrid search (semantic + keyword)
node knowledge/index.cjs --hybrid "token efficiency improvements"

# With timing breakdown
node knowledge/index.cjs --verify "phase 7 delegation"

# Benchmark performance
node knowledge/index.cjs --bench --iters=30

# Reindex all documents
node knowledge/index.cjs --reindex

# Legacy commands (still supported)
node knowledge/index.cjs --search "keyword"     # FTS only
node knowledge/index.cjs --recall "query"       # TF-IDF only
node knowledge/index.cjs --stats                # Statistics
```

### Example Query

```bash
$ node knowledge/index.cjs --hybrid "how to reduce costs"

{
  "query": "how to reduce costs",
  "results": [
    {
      "doc_path": "docs/PHASE7_2_DELEGATION.md",
      "snippet": "...89% [token] savings through delegation...",
      "scores": {
        "fts": 0.85,
        "semantic": 0.72,
        "final": 0.759
      }
    },
    // ... 9 more results
  ],
  "count": 10
}
```

---

## Architecture

### 3-Stage Hybrid Pipeline

```
┌─────────────────────────────────────────────────────────────┐
│ Stage 1: FTS Pre-filter (Fast)                              │
│ SQLite FTS5 → Top 50 candidates                             │
│ Performance: ~4ms                                            │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ Stage 2: Embedding Rerank (Precise)                         │
│ all-MiniLM-L6-v2 → Cosine similarity                        │
│ Performance: ~4ms                                            │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ Stage 3: Hybrid Scoring                                     │
│ Final = (0.3 × FTS) + (0.7 × Semantic)                      │
│ Performance: ~0.1ms                                          │
└─────────────────────────────────────────────────────────────┘
```

### Technology Stack

- **Embeddings**: @xenova/transformers (ONNX runtime, CPU-only)
- **Model**: all-MiniLM-L6-v2 (384 dimensions, 80MB)
- **Database**: SQLite with FTS5 (knowledge/02luka.db, 14 MB)
- **Chunks**: 4,002 semantic chunks (split by markdown headers)
- **Storage**: 5.86 MB embeddings + 1.27 MB text + 6.87 MB overhead

---

## Database Schema

### document_chunks Table

```sql
CREATE TABLE document_chunks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  doc_path TEXT NOT NULL,              -- Relative path from repo root
  chunk_index INTEGER NOT NULL,         -- Position in document
  text TEXT NOT NULL,                   -- Chunk content with hierarchy
  embedding BLOB,                       -- 384 floats (1,536 bytes)
  metadata TEXT,                        -- JSON: hierarchy, tags, importance
  indexed_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- FTS5 for keyword search
CREATE VIRTUAL TABLE document_chunks_fts
USING fts5(text, content='document_chunks', content_rowid='id');

-- Index for fast doc_path lookups
CREATE INDEX idx_doc_path ON document_chunks(doc_path);
```

### Metadata Structure

```json
{
  "hierarchy": ["Phase 7.2: Local Orchestrator & Delegation"],
  "section": "Architecture",
  "tags": ["success", "phase-doc", "api"],
  "importance": 0.65,
  "level": 2,
  "wordCount": 245,
  "hasCode": true,
  "hasList": false
}
```

---

## Components

### Core Files

| File | Lines | Purpose |
|------|-------|---------|
| `embedder.cjs` | 76 | all-MiniLM-L6-v2 wrapper (lazy-loaded singleton) |
| `chunker.cjs` | 202 | Semantic document splitting by headers |
| `search.cjs` | 179 | 3-stage hybrid search pipeline |
| `reindex-all.cjs` | 188 | Batch indexing (31.2 chunks/sec) |
| `index.cjs` | 95+ | CLI interface with all commands |
| `util/timer.cjs` | 74 | High-precision timing (hrtime) |
| `util/benchmark.cjs` | 169 | Performance benchmarking |
| `bench_queries.txt` | 39 | Test queries for benchmarking |

### Legacy Files (Phase 7.5)

| File | Status | Purpose |
|------|--------|---------|
| `schema.sql` | ✅ Used | Schema for memories, telemetry, reports tables |
| `sync.cjs` | ✅ Active | Syncs JSON → SQLite (backward compatible) |
| `init.cjs` | ⚠️ Deprecated | Use reindex-all.cjs instead |

---

## Performance Metrics

### Benchmark Results (30 iterations)

| Metric | Value | Target | Status |
|--------|-------|--------|--------|
| Mean | 7.04ms | <100ms | 🚀 14x better |
| Median | 6.62ms | <100ms | 🚀 15x better |
| P95 | 17.47ms | <100ms | 🚀 5.7x better |
| Max | 20.16ms | <100ms | ✅ 5x better |

### Stage Breakdown (Mean)
- **FTS Pre-filter**: 4.37ms (62%)
- **Embedding**: 2.55ms (36%)
- **Rerank**: 0.11ms (2%)

### Indexing Performance
- **Rate**: 31.2 chunks/second
- **Total Time**: 128.3 seconds for 258 files
- **Chunks Created**: 4,002 semantic chunks

---

## Coverage Statistics

### Before (Phase 6 - TF-IDF Only)
- Memory chunks: 27
- Docs indexed: 0/41 (0%)
- Reports indexed: 125/185 (68%)
- **Waste paper**: ~30,000 words unindexed

### After (Phase 7.6+ - Hybrid)
- Document chunks: 4,002
- Docs indexed: 41/41 (100%) ✅
- Reports indexed: 185+/185 (100%) ✅
- **Waste paper**: 0 words ✅

### Improvement
- Coverage: +14,700% chunks
- Docs: +100% coverage
- Reports: +32% coverage
- Zero documentation waste ✅

---

## Usage Examples

### 1. Find Token Savings Information

```bash
$ node knowledge/index.cjs --hybrid "token efficiency improvements"
```

**Top Results:**
- RAG_QUICK_REFERENCE.md (score: 0.651)
- 251022_RAG_SYSTEM_CLARIFICATION.md (score: 0.513)
- PHASE7_2_7_5_COMPLETION_REPORT.md (score: 0.370)

### 2. Search for Phase 7.2 Documentation

```bash
$ node knowledge/index.cjs --verify "phase 7.2 complete"
```

**Results:**
- PHASE7_2_7_5_COMPLETION_REPORT.md (score: 0.721)
- Timing: 15ms FTS, 278ms embedding, 293ms total

### 3. Benchmark Performance

```bash
$ node knowledge/index.cjs --bench --iters=10
```

**Output:**
```
BENCHMARK RESULTS
═════════════════════════════════════════════
Iterations: 10
Queries: 39 unique

TOTAL TIME
  Min      3.28 ms
  Mean     8.03 ms
  Median   7.83 ms
  P95     13.07 ms
  Max     13.07 ms

ASSESSMENT: 🚀 Excellent performance (<50ms avg)
```

---

## Semantic Understanding Examples

The hybrid system understands concepts, not just keywords:

| Query | Finds Documents About |
|-------|----------------------|
| "token efficiency" | Token savings, optimization, delegation |
| "reducing costs" | Efficiency, delegation, resource optimization |
| "how to improve performance" | Performance metrics, benchmarks, optimizations |
| "phase 7 delegation" | Phase 7.2 docs, delegation architecture |
| "version 2.0" | v2.0 deployments (handles periods correctly) |

---

## Special Character Handling

Fixed FTS5 syntax errors with special characters:

✅ **Working Queries:**
- "version 2.0" (periods)
- "boss-api" (hyphens)
- "phase 7.2 complete" (decimals)
- "v2.0 deployment" (versions)

**Solution:** Tokenize query, wrap each term in quotes, join with OR
```javascript
// Input:  "phase 7.2 implementation"
// Output: "phase" OR "7.2" OR "implementation"
```

---

## Backward Compatibility

All Phase 6 and Phase 7.5 commands still work:

```bash
# FTS keyword search (Phase 7.5)
node knowledge/index.cjs --search "delegation"

# TF-IDF vector search (Phase 6)
node knowledge/index.cjs --recall "token efficiency"

# Database statistics
node knowledge/index.cjs --stats

# Export to JSON
node knowledge/index.cjs --export
```

New commands are **additive**, not breaking changes.

---

## Maintenance

### Reindexing

Rebuild the entire index from scratch:

```bash
node knowledge/index.cjs --reindex
# Or directly:
node knowledge/reindex-all.cjs
```

**When to reindex:**
- After adding many new documents
- After changing chunking logic
- To fix index corruption
- Database performance degraded

**Performance:** ~2 minutes for 258 files

### Updating the Model

The embedding model (all-MiniLM-L6-v2) is cached locally after first download (80MB). No updates needed unless you want to change models.

### Storage Management

Database file: `knowledge/02luka.db` (14 MB)

**Cleanup:**
```bash
# Check size
du -h knowledge/02luka.db

# Optimize database
sqlite3 knowledge/02luka.db "VACUUM; REINDEX;"

# Full rebuild (if needed)
rm knowledge/02luka.db
node knowledge/reindex-all.cjs
```

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
- **02luka.md**: Main system documentation (see Phase 7.6+ section)

---

## Troubleshooting

### No Results for Query

**Cause:** Query may be too specific or use unsupported syntax

**Solution:** Simplify query, use common terms
```bash
# Instead of: "how do I optimize the performance of queries"
node knowledge/index.cjs --hybrid "query performance optimization"
```

### Slow Queries (>100ms)

**Cause:** First query loads embedding model (~500ms)

**Solution:** Subsequent queries are fast (<10ms). First query is always slower.

### Database Locked

**Cause:** Another process has the database open

**Solution:** Wait for other process to finish, or check:
```bash
lsof knowledge/02luka.db
```

### FTS Syntax Error

**Cause:** Special characters in query (should be fixed, but if not...)

**Solution:** The system now handles special chars automatically. If errors persist, use simpler queries.

---

## Performance Comparison

| Metric | TF-IDF (Phase 6) | Hybrid (Phase 7.6+) |
|--------|------------------|---------------------|
| Coverage | 27 memories | 4,002 chunks (258 docs) |
| Docs | 0% | 100% ✅ |
| Reports | 68% | 100% ✅ |
| Storage | ~100 KB | 14 MB |
| Query Speed | N/A | 7-8ms |
| Semantic | ❌ Keyword only | ✅ Full semantic |
| Special Chars | N/A | ✅ Fixed |

---

## Future Enhancements

### Planned (Optional)
1. **LRU Cache**: Query embedding cache (95% speedup for repeated queries)
2. **Context Expansion**: Fetch neighboring chunks for better context
3. **Auto-Reindex**: Watch files and reindex on changes (chokidar + LaunchAgent)
4. **Multi-Vector Search**: Query + negative examples
5. **Temporal Decay**: Boost recent documents in scoring

### Integration Opportunities
1. **CLC Integration**: Use hybrid search in knowledge queries
2. **Boss API**: Expose `/api/v2/search` endpoint
3. **Memory System**: Auto-index agent memories
4. **Web UI**: Search interface for dashboard

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

---

**Last Updated:** 2025-10-22
**Status:** ✅ Production Ready
**Maintained By:** CLC (Implementation)
**Tag:** `v251022_phase7.6-hybrid-vector-db`
