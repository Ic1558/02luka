# RAG System - Quick Reference

**02luka Retrieval-Augmented Generation Cheatsheet**

---

## One-Line Summary

**Dual-path knowledge retrieval:** TF-IDF vectors (semantic) + SQLite FTS5 (keyword) → Offline-first, file-backed, <100ms queries

---

## Quick Commands

```bash
# Vector search (semantic similarity)
bash knowledge/cli/recall.sh "token efficiency"

# Full-text search (keyword matching)
bash knowledge/cli/search.sh "phase 7 delegation"

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
├─ Exact keywords/phrases? ────────→ Use FTS (search)
│   Examples:
│   • "phase 7"
│   • "freeze-proofing"
│   • "OPS_ATOMIC"
│
├─ Similar concepts/meanings? ─────→ Use Vector (recall)
│   Examples:
│   • "token efficiency" (finds "token savings")
│   • "performance improvements" (finds optimizations)
│   • "error handling" (finds error patterns)
│
└─ Not sure? ──────────────────────→ Use BOTH, combine results
```

---

## Data Locations

| What | Where | Size |
|------|-------|------|
| Vector index | `g/memory/vector_index.json` | ~100KB |
| SQLite DB | `knowledge/02luka.db` | ~1.5MB |
| JSON exports | `knowledge/exports/*.json` | ~200KB |
| Telemetry | `g/telemetry/*.log` | varies |
| Reports | `g/reports/*.md` | varies |

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

- Full Specification: `g/reports/251022_RAG_SYSTEM_CLARIFICATION.md`
- Phase 7.5 Docs: `docs/PHASE7_5_KNOWLEDGE.md`
- Memory System: `docs/CONTEXT_ENGINEERING.md`
- Phase 7.2 Delegation: `docs/PHASE7_2_DELEGATION.md`

---

**Last Updated:** 2025-10-22
**Status:** ✅ Production Ready
