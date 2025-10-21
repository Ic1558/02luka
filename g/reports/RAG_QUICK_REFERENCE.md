# RAG System - Quick Reference

**02luka Retrieval-Augmented Generation Cheatsheet**

---

## One-Line Summary

**Three-path knowledge retrieval:** Hybrid Embeddings (7ms, **PRIMARY**) + TF-IDF vectors (legacy) + SQLite FTS5 (keyword) → Offline-first, file-backed, semantic understanding

---

## Quick Commands

```bash
# ⭐ HYBRID SEARCH (RECOMMENDED - Phase 7.6+)
node knowledge/index.cjs --hybrid "query"               # Semantic + keyword (7ms)
node knowledge/index.cjs --verify "query"               # With timing breakdown

# Vector search (semantic similarity - Phase 6, legacy)
bash knowledge/cli/recall.sh "token efficiency"

# Full-text search (keyword matching - Phase 7.5)
bash knowledge/cli/search.sh "phase 7 delegation"

# Reindex all documents (after adding new docs)
node knowledge/index.cjs --reindex

# Benchmark performance
node knowledge/index.cjs --bench --iters=30

# Get statistics
bash knowledge/cli/stats.sh

# Full sync (JSON → SQLite)
bash scripts/knowledge_full_sync.sh

# Export to JSON
node knowledge/index.cjs --export
```

---

## Decision Tree: Which Search?

```
Need to find...
│
├─ ⭐ MOST CASES? ─────────────────→ Use HYBRID (--hybrid) ← PRIMARY
│   Best for:
│   • General questions about the system
│   • Concept discovery ("token efficiency" finds "delegation")
│   • Version lookups ("phase 7.2", "v2.0")
│   • Before asking CLC questions (saves tokens!)
│
│   Examples:
│   • "how to reduce costs" → finds delegation docs
│   • "phase 7.2 complete" → finds completion report
│   • "RAG system architecture" → finds RAG docs
│   • "performance optimization" → finds benchmarks
│
│   Performance: 7-8ms avg, 100% docs indexed ✅
│
├─ Exact keywords/phrases only? ───→ Use FTS (--search) - Phase 7.5
│   Examples:
│   • "freeze-proofing"
│   • "OPS_ATOMIC"
│   • Specific function names
│
├─ Agent memory (old memories)? ───→ Use Vector (recall) - Phase 6
│   Examples:
│   • Past agent experiences
│   • Successful plans
│   • Error patterns
│
│   Note: Only 27 memories (legacy system)
│
└─ Not sure? ──────────────────────→ Use HYBRID (default choice)
```

---

## Data Locations

| What | Where | Size | Status |
|------|-------|------|--------|
| **Hybrid DB (Phase 7.6+)** | `knowledge/02luka.db` | **14 MB** | ✅ **PRIMARY** |
| └─ Embeddings | (BLOB in chunks table) | 5.86 MB | 4,002 chunks |
| └─ Text | (TEXT in chunks table) | 1.27 MB | Semantic chunks |
| └─ FTS index | (FTS5 virtual table) | 6.87 MB | Keyword search |
| Vector index (Phase 6) | `g/memory/vector_index.json` | ~100KB | ⚠️ Legacy |
| JSON exports | `knowledge/exports/*.json` | ~200KB | Sync output |
| Telemetry | `g/telemetry/*.log` | varies | Historical |
| Reports | `g/reports/*.md` | varies | Source docs |

---

## Memory Fields

```json
{
  "id": "insight_1760989569686_d6k1ws2",
  "kind": "insight",              // insight|solution|error|plan
  "text": "Full text here",
  "importance": 0.9,              // 0.0-1.0
  "timestamp": "2025-10-20...",
  "lastAccess": "2025-10-21...",
  "queryCount": 5,                // Auto-incremented on recall
  "tokens": ["word1", "word2"],   // Tokenized text
  "vector": {                     // TF-IDF weights
    "word1": 0.384,
    "word2": 0.216
  },
  "meta": {                       // Custom metadata
    "successRate": 0.95
  }
}
```

---

## Performance Targets

| Operation | Target | Actual |
|-----------|--------|--------|
| Vector search | <100ms | 65ms (1K memories) |
| FTS search | <10ms | 5ms (1K docs) |
| Full sync | <500ms | 350ms |
| Export | <200ms | 120ms |

---

## Token Savings

| Scenario | Before | After | Savings |
|----------|--------|-------|---------|
| Knowledge query | 62,000 | 1,450 | 97.7% |
| Task delegation | 6,500 | 700 | 89.2% |
| **Combined** | **68,500** | **2,150** | **96.9%** |

---

## API Examples

### Store Memory

```javascript
const { remember } = require('./memory/index.cjs');

await remember({
  kind: 'insight',
  text: 'Phase 7.2 complete: 89% token savings',
  meta: { successRate: 0.95 },
  importance: 0.9
});
```

### Vector Search

```javascript
const { recall } = require('./memory/index.cjs');

const results = await recall({
  query: 'token efficiency',
  kind: 'insight',
  topK: 5
});

console.log(results);
// [{ id, kind, text, score: 0.382, importance: 0.9 }, ...]
```

### FTS Search

```bash
# Via CLI
node knowledge/index.cjs --search "phase 7 delegation"

# Output:
# {
#   "query": "phase 7 delegation",
#   "results": [
#     {
#       "id": "solution_...",
#       "kind": "solution",
#       "snippet": "...[Phase] [7] [delegation] complete..."
#     }
#   ]
# }
```

---

## Sync Workflow

```
Source Files                Sync Process              Target DB
─────────────              ──────────────            ─────────

vector_index.json    ──┐
telemetry/*.log      ──┼──> knowledge/sync.cjs ──> 02luka.db
reports/*.md         ──┘         (runs every           ├─ memories
                                  hour or on           ├─ memories_fts
                                  demand)              ├─ telemetry
                                                       ├─ reports
                                                       └─ reports_fts
```

---

## Phase 7.6+: Hybrid Embeddings (NEW)

**Status:** ✅ PRODUCTION READY (2025-10-22)

### How It Works

**3-Stage Pipeline:**
1. **FTS Pre-filter** (4ms): SQLite FTS5 finds top 50 keyword matches
2. **Embedding Rerank** (3ms): all-MiniLM-L6-v2 computes semantic similarity
3. **Hybrid Scoring** (0.1ms): Combines (0.3 × FTS + 0.7 × Semantic)

### Key Features

- ✅ **100% Documentation Coverage**: 4,002 chunks from 258 documents
- 🚀 **7-8ms Queries**: 12x better than 100ms target
- 🧠 **Semantic Understanding**: Finds "token savings" when you search "cost reduction"
- ⚡ **Offline-First**: all-MiniLM-L6-v2 (384 dims, 80MB, no APIs)
- 🔄 **Backward Compatible**: Old commands still work

### Example Query

```bash
$ node knowledge/index.cjs --hybrid "token efficiency improvements"

{
  "query": "token efficiency improvements",
  "results": [
    {
      "doc_path": "g/reports/RAG_QUICK_REFERENCE.md",
      "snippet": "...89% token savings through delegation...",
      "scores": {
        "fts": 0.85,
        "semantic": 0.72,
        "final": 0.759
      }
    }
  ],
  "count": 10
}
```

### Why Hybrid?

**FTS (Keyword):** Fast, precise for exact matches → Pre-filter
**Embeddings (Semantic):** Slow, understands concepts → Rerank
**Hybrid:** Best of both → Fast + accurate ✅

### Coverage Comparison

| System | Docs | Reports | Memories | Total |
|--------|------|---------|----------|-------|
| Phase 6 (TF-IDF) | 0% | N/A | 27 | 27 |
| Phase 7.5 (FTS) | 0% | 68% | N/A | 125 |
| **Phase 7.6 (Hybrid)** | **100%** ✅ | **100%** ✅ | **100%** ✅ | **4,002** ✅ |

### Documentation

- **User Guide**: `knowledge/README.md`
- **Implementation**: `g/reports/251022_HYBRID_VECTOR_DB_IMPLEMENTATION.md`
- **Verification**: `g/reports/251022_HYBRID_VDB_VERIFICATION.md`
- **Phase Docs**: `docs/PHASE7_6_HYBRID_EMBEDDINGS.md`

---

## TF-IDF Explained (Simple)

**TF (Term Frequency):** How often a word appears in THIS document
**IDF (Inverse Document Frequency):** How rare the word is ACROSS ALL documents

**Formula:** `TF-IDF = TF × IDF`

**Example:**
```
Document: "Phase 7 delegation saves tokens"

TF scores:
- "phase": 1/5 = 0.20
- "delegation": 1/5 = 0.20
- "saves": 1/5 = 0.20

IDF scores (across corpus):
- "phase": 0.82 (common)
- "delegation": 2.30 (rare!)
- "saves": 1.15 (medium)

TF-IDF weights:
- "phase": 0.20 × 0.82 = 0.164
- "delegation": 0.20 × 2.30 = 0.460  ← High weight!
- "saves": 0.20 × 1.15 = 0.230
```

**Result:** "delegation" gets highest weight → better matching for queries about delegation

---

## Cosine Similarity Explained (Simple)

**Question:** How similar are two vectors?

**Answer:** Angle between them (0° = identical, 90° = unrelated)

```
Vector A: [0.3, 0.8, 0.1]  ← "delegation token savings"
Vector B: [0.4, 0.7, 0.2]  ← "delegation efficiency"

Dot Product: (0.3×0.4) + (0.8×0.7) + (0.1×0.2) = 0.70
Magnitude A: √(0.3² + 0.8² + 0.1²) = 0.86
Magnitude B: √(0.4² + 0.7² + 0.2²) = 0.83

Cosine Similarity: 0.70 / (0.86 × 0.83) = 0.98

Result: 98% similar! ✅
```

---

## Troubleshooting

### Problem: Vector search returns no results

**Solutions:**
1. Check if vector_index.json has memories
2. Verify query has meaningful words (>2 chars)
3. Try broader query terms
4. Check if IDF calculated correctly (needs >1 memory)

### Problem: FTS search returns no results

**Solutions:**
1. Verify 02luka.db exists: `ls -lh knowledge/02luka.db`
2. Run full sync: `bash scripts/knowledge_full_sync.sh`
3. Check FTS index: `sqlite3 knowledge/02luka.db "SELECT * FROM memories_fts LIMIT 1"`
4. Try simpler query (single word)

### Problem: Slow queries

**Solutions:**
1. Vector search slow (>500ms): Too many memories, run cleanup
2. FTS search slow (>50ms): Rebuild index: `VACUUM; REINDEX;`
3. Check memory count: `bash knowledge/cli/stats.sh`

---

## Integration with CLC

**How CLC uses RAG:**

1. **User asks question** → CLC detects knowledge query
2. **CLC calls recall()** → Gets top 5 semantic matches
3. **CLC formats context** → Includes retrieved text in prompt
4. **CLC generates answer** → Uses augmented context
5. **Memory stats updated** → lastAccess, queryCount incremented

**Example:**
```
User: "How did we improve token efficiency?"

CLC: (internal)
  → recall("token efficiency improvements")
  → Results: ["Phase 7.2: 89% savings", "Delegation reduces 6500→700", ...]
  → Format context
  → Generate response using retrieved knowledge

CLC: "We improved token efficiency through Phase 7.2 delegation,
      reducing 6500 tokens to 700 (89% savings)..."
```

---

## Architecture Comparison

| 02luka RAG | Traditional RAG |
|------------|-----------------|
| TF-IDF | OpenAI Embeddings |
| SQLite FTS5 | Pinecone/Weaviate |
| File-backed | Cloud-hosted |
| Offline | Online only |
| Free | $0.0001/query |
| <100ms | 200-500ms |
| <10K docs | Millions |

**Choose 02luka RAG when:**
- Privacy matters (no external APIs)
- Offline-first required
- Cost-sensitive project
- <10,000 documents
- Local agent operations

---

## Related Docs

### Phase 7.6+ (Current)
- **Phase Docs**: `docs/PHASE7_6_HYBRID_EMBEDDINGS.md` ⭐
- **Implementation**: `g/reports/251022_HYBRID_VECTOR_DB_IMPLEMENTATION.md`
- **Verification**: `g/reports/251022_HYBRID_VDB_VERIFICATION.md`
- **User Guide**: `knowledge/README.md`

### Previous Phases
- **RAG Specification**: `g/reports/251022_RAG_SYSTEM_CLARIFICATION.md`
- **Phase 7.5**: `docs/PHASE7_5_KNOWLEDGE.md`
- **Phase 7.2 Delegation**: `docs/PHASE7_2_DELEGATION.md`
- **Memory System**: `docs/CONTEXT_ENGINEERING.md`

---

**Last Updated:** 2025-10-22 (Phase 7.6+ added)
**Status:** ✅ Production Ready
