# RAG System Clarification - 02luka Architecture

**Date:** 2025-10-22 (Updated with Phase 7.6+)
**Status:** ✅ Production Ready
**Phases:** 6, 6.5-A, 6.5-B, 7.5, **7.6 (CURRENT)**

---

## What is RAG in Our System?

**RAG (Retrieval-Augmented Generation)** in the 02luka system is a three-tier knowledge retrieval architecture that combines:

1. **Hybrid Embeddings (all-MiniLM-L6-v2 + FTS5)** (Phase 7.6 - **CURRENT, PRIMARY**)
2. **In-Memory TF-IDF Vector Search** (Phase 6 + 6.5 - Legacy)
3. **SQLite Full-Text Search (FTS5)** (Phase 7.5 - Legacy)

Unlike traditional RAG systems that use external vector databases (Pinecone, Weaviate, etc.), our system is **offline-first, file-backed, and lightweight** - designed for local AI agent operations. Phase 7.6 adds true semantic understanding via transformer-based embeddings while maintaining the offline-first philosophy.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    02luka RAG System                         │
└─────────────────────────────────────────────────────────────┘

┌──────────────────────┐
│  INPUT SOURCES       │
├──────────────────────┤
│ • User queries       │
│ • Agent tasks        │
│ • Context requests   │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────────────────────────────────────────────┐
│              RETRIEVAL LAYER (Dual-Path)                     │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  PATH 1: Vector Search (memory/index.cjs)                   │
│  ┌────────────────────────────────────────────────────┐     │
│  │ 1. Query → Tokenize → TF-IDF Vector                │     │
│  │ 2. Load: g/memory/vector_index.json                │     │
│  │ 3. Cosine Similarity (All Memories)                │     │
│  │ 4. Rank & Return Top-K (default: 5)                │     │
│  │ Speed: <100ms | Precision: High                     │     │
│  └────────────────────────────────────────────────────┘     │
│                                                               │
│  PATH 2: Full-Text Search (knowledge/index.cjs)             │
│  ┌────────────────────────────────────────────────────┐     │
│  │ 1. Query → SQLite FTS5 Index                       │     │
│  │ 2. Load: knowledge/02luka.db                       │     │
│  │ 3. Search: memories_fts, reports_fts                │     │
│  │ 4. Snippet Highlighting & Return                    │     │
│  │ Speed: <10ms | Breadth: Entire Corpus               │     │
│  └────────────────────────────────────────────────────┘     │
│                                                               │
└──────────────────────┬───────────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────────────┐
│              AUGMENTATION LAYER                              │
├──────────────────────────────────────────────────────────────┤
│ • Combine Vector + FTS Results                               │
│ • Deduplicate by memory ID                                   │
│ • Re-rank by relevance + importance + freshness             │
│ • Format context for AI prompt                               │
└──────────────────────┬───────────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────────────┐
│              GENERATION LAYER                                │
├──────────────────────────────────────────────────────────────┤
│ • CLC (Claude Code) receives augmented context               │
│ • Generates response using retrieved knowledge               │
│ • Updates memory access stats (lastAccess, queryCount)      │
└──────────────────────────────────────────────────────────────┘
```

---

## Component Breakdown

### 1. Vector Search (Phase 6 + 6.5)

**File:** `memory/index.cjs`
**Algorithm:** TF-IDF + Cosine Similarity
**Storage:** `g/memory/vector_index.json`

#### How It Works

**Step 1: Vectorization (TF-IDF)**
```javascript
// Example memory text
text = "Phase 7.2 delegation complete: 89% token savings"

// Tokenization
tokens = ["phase", "delegation", "complete", "89", "token", "savings"]

// Term Frequency (TF)
tf = {
  "phase": 0.167,
  "delegation": 0.167,
  "complete": 0.167,
  "token": 0.167,
  "savings": 0.167
}

// Inverse Document Frequency (IDF) - calculated across all memories
idf = {
  "phase": 0.82,       // Common word
  "delegation": 2.30,   // Rare word
  "complete": 1.15,
  "token": 1.89,
  "savings": 2.10
}

// TF-IDF Vector
vector = {
  "phase": 0.137,
  "delegation": 0.384,  // High weight (rare + present)
  "complete": 0.192,
  "token": 0.316,
  "savings": 0.351
}
```

**Step 2: Query Processing**
```javascript
// User query
query = "token efficiency"

// Create query vector (same TF-IDF process)
queryVector = {
  "token": 0.500,
  "efficiency": 0.500
}
```

**Step 3: Similarity Calculation**
```javascript
// Cosine similarity with all memory vectors
scores = memories.map(mem => ({
  id: mem.id,
  score: cosineSimilarity(queryVector, mem.vector),
  text: mem.text
}))

// Sort by score descending
ranked = scores.sort((a, b) => b.score - a.score)

// Return top-K (default: 5)
results = ranked.slice(0, 5)
```

#### Performance Characteristics

- **Speed:** <100ms for 1,000 memories
- **Precision:** High (semantic understanding)
- **Recall:** Good (finds similar concepts even with different words)
- **Scalability:** Linear O(n) - acceptable for <10K memories

#### Example Usage

```bash
# Via CLI
bash knowledge/cli/recall.sh "token savings"

# Via Node
node memory/index.cjs recall "delegation efficiency" --topK 3
```

**Output:**
```json
{
  "results": [
    {
      "id": "insight_1760989569686_d6k1ws2",
      "kind": "insight",
      "text": "Phase 7.2 delegation complete: 89% token savings (6500→700)",
      "score": 0.382,
      "importance": 0.9
    },
    {
      "id": "solution_1760986453199_pny5l76",
      "kind": "solution",
      "text": "Local orchestrator handles execution, CLC writes specs only",
      "score": 0.289,
      "importance": 0.85
    }
  ]
}
```

---

### 2. Full-Text Search (Phase 7.5)

**File:** `knowledge/index.cjs`
**Engine:** SQLite FTS5 (Full-Text Search)
**Storage:** `knowledge/02luka.db`

#### How It Works

**Step 1: Index Building**
```sql
-- FTS5 virtual table for memories
CREATE VIRTUAL TABLE memories_fts USING fts5(
  id,
  kind,
  text,
  content=memories,
  content_rowid=rowid
);

-- Auto-populated from memories table
INSERT INTO memories_fts(rowid, id, kind, text)
SELECT rowid, id, kind, text FROM memories;
```

**Step 2: Query Execution**
```sql
-- User searches "phase 7"
SELECT
  id,
  kind,
  snippet(memories_fts, 2, '[', ']', '...', 30) as snippet
FROM memories_fts
WHERE memories_fts MATCH 'phase 7'
ORDER BY rank
LIMIT 10;
```

**Output:**
```json
[
  {
    "id": "solution_1760986453199_pny5l76",
    "kind": "solution",
    "snippet": "...[Phase] [7].2 smoke test passed - delegation stack operational..."
  },
  {
    "id": "insight_1760989569686_d6k1ws2",
    "kind": "insight",
    "snippet": "...[Phase] [7].2 delegation complete: CLC writes specs..."
  }
]
```

#### Performance Characteristics

- **Speed:** <10ms for typical queries
- **Precision:** Exact keyword matching
- **Recall:** Excellent (finds all occurrences)
- **Scalability:** O(log n) - scales to millions of documents

#### Example Usage

```bash
# Via CLI
bash knowledge/cli/search.sh "phase 7 delegation"

# Via Node
node knowledge/index.cjs --search "token savings"
```

---

### 3. Memory Storage Schema

#### In-Memory Structure (vector_index.json)

```json
{
  "memories": [
    {
      "id": "insight_1760989569686_d6k1ws2",
      "kind": "insight",
      "text": "Phase 7.2 delegation complete: 89% token savings",
      "importance": 0.9,
      "timestamp": "2025-10-20T03:32:49.686Z",
      "lastAccess": "2025-10-21T12:30:15.123Z",
      "queryCount": 5,
      "tokens": ["phase", "delegation", "complete", "89", "token", "savings"],
      "vector": {
        "phase": 0.137,
        "delegation": 0.384,
        "complete": 0.192,
        "token": 0.316,
        "savings": 0.351
      },
      "meta": {
        "successRate": 0.95,
        "reuseCount": 12
      }
    }
  ]
}
```

#### SQLite Schema (02luka.db)

```sql
-- Main memories table
CREATE TABLE memories (
  id TEXT PRIMARY KEY,
  kind TEXT,
  text TEXT,
  importance REAL,
  timestamp TEXT,
  lastAccess TEXT,
  queryCount INTEGER,
  meta TEXT,         -- JSON
  tokens TEXT,       -- JSON array
  vector TEXT        -- JSON object (TF-IDF)
);

-- FTS5 index
CREATE VIRTUAL TABLE memories_fts USING fts5(
  id, kind, text,
  content=memories,
  content_rowid=rowid
);

-- Reports table
CREATE TABLE reports (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  filename TEXT,
  type TEXT,
  generated TEXT,
  content TEXT,
  metadata TEXT
);

-- FTS5 index for reports
CREATE VIRTUAL TABLE reports_fts USING fts5(
  filename, type, content,
  content=reports,
  content_rowid=id
);

-- Telemetry table
CREATE TABLE telemetry (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  ts TEXT,
  task TEXT,
  pass INTEGER,
  warn INTEGER,
  fail INTEGER,
  duration_ms INTEGER,
  meta TEXT
);
```

---

## Dual-Path Retrieval Strategy

### When to Use Vector Search (recall)

✅ **Use for:**
- Semantic queries ("how did we improve performance?")
- Concept matching ("find similar solutions")
- Fuzzy matching (different words, same meaning)
- Importance-weighted results

**Example:**
```bash
node memory/index.cjs recall "token efficiency improvements"
# Finds: "89% token savings", "delegation reduces tokens", etc.
```

### When to Use Full-Text Search (FTS)

✅ **Use for:**
- Keyword queries ("phase 7")
- Exact phrase matching ("freeze-proofing")
- Fast scanning of entire corpus
- Report content search

**Example:**
```bash
node knowledge/index.cjs --search "phase 7 delegation"
# Finds: All mentions of "phase 7" AND "delegation"
```

### Hybrid Strategy (Best Practice)

```javascript
// Combine both methods
async function hybridSearch(query) {
  // 1. Vector search for semantic matches
  const vectorResults = await recall({ query, topK: 5 });

  // 2. FTS for keyword matches
  const ftsResults = await ftsSearch(query, { limit: 5 });

  // 3. Deduplicate by ID
  const seen = new Set();
  const combined = [];

  for (const result of [...vectorResults, ...ftsResults]) {
    if (!seen.has(result.id)) {
      seen.add(result.id);
      combined.push(result);
    }
  }

  // 4. Re-rank by composite score
  return combined
    .map(r => ({
      ...r,
      compositeScore: (r.score || 0.5) * r.importance * freshnessBoost(r.timestamp)
    }))
    .sort((a, b) => b.compositeScore - a.compositeScore)
    .slice(0, 10);
}
```

---

## Memory Lifecycle

### 1. Creation (remember)

```javascript
await remember({
  kind: 'insight',
  text: 'Phase 7.2 delegation complete: 89% token savings',
  meta: { successRate: 0.95 },
  importance: 0.9
});
```

**Process:**
1. Generate unique ID
2. Tokenize text
3. Calculate TF-IDF vector (using corpus IDF)
4. Set timestamp, lastAccess, queryCount
5. Write to `g/memory/vector_index.json`
6. Sync to SQLite (async background job)

### 2. Retrieval (recall)

```javascript
const results = await recall({
  query: 'token efficiency',
  kind: 'insight',  // optional filter
  topK: 5
});
```

**Process:**
1. Load vector_index.json
2. Create query vector
3. Calculate cosine similarity for all memories
4. Filter by kind (if specified)
5. Sort by score descending
6. **Update lastAccess + increment queryCount**
7. Return top-K results

### 3. Decay (automatic)

**Time-based importance decay:**
```javascript
// Half-life formula
const daysSinceAccess = (now - lastAccess) / (1000 * 60 * 60 * 24);
const decayFactor = Math.pow(0.5, daysSinceAccess / halfLifeDays);
newImportance = oldImportance * decayFactor;
```

**Query frequency boost:**
```javascript
if (queryCount > 10) {
  importanceBoost = Math.min(0.15, queryCount * 0.01);
  newImportance = Math.min(1.0, oldImportance + importanceBoost);
}
```

### 4. Cleanup (manual)

```javascript
await cleanup({
  maxAgeDays: 90,      // Remove memories older than 90 days
  minImportance: 0.3   // Remove memories with importance < 0.3
});
```

**Analytics output:**
```json
{
  "removed": 15,
  "kept": 42,
  "reasons": {
    "too_old": 8,
    "low_importance": 5,
    "combined": 2
  }
}
```

---

## Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    WRITE PATH                                │
└─────────────────────────────────────────────────────────────┘

User/Agent
    │
    ▼
remember({kind, text, meta, importance})
    │
    ├─→ Generate ID (timestamp + random)
    ├─→ Tokenize text
    ├─→ Calculate TF-IDF vector
    ├─→ Set timestamp, lastAccess, queryCount
    │
    ▼
g/memory/vector_index.json (write)
    │
    ▼
[Background Sync - knowledge/sync.cjs]
    │
    ▼
knowledge/02luka.db (SQLite)
    │
    ├─→ INSERT INTO memories
    └─→ UPDATE memories_fts


┌─────────────────────────────────────────────────────────────┐
│                    READ PATH                                 │
└─────────────────────────────────────────────────────────────┘

User Query
    │
    ├──────────────────────┬──────────────────────┐
    ▼                      ▼                      ▼
Vector Search         FTS Search           Combined
(memory/index.cjs)   (knowledge/index.cjs)
    │                      │                      │
    ├─→ Load JSON          ├─→ Query SQLite       ├─→ Merge results
    ├─→ TF-IDF Vector      ├─→ FTS5 MATCH        ├─→ Deduplicate
    ├─→ Cosine Sim         ├─→ Rank by BM25      ├─→ Re-rank
    ├─→ Update stats       └─→ Snippet           └─→ Return top-K
    └─→ Return top-K            extraction
         │                      │                      │
         └──────────────────────┴──────────────────────┘
                                │
                                ▼
                        Augmented Context
                                │
                                ▼
                        CLC Generation
```

---

## Token Savings Analysis

### Before RAG (Direct File Reading)

**Scenario:** User asks "What did we do for token savings?"

```
1. Read g/memory/vector_index.json (5KB)       → 1,500 tokens
2. Read g/reports/*.md (50 files, 200KB)      → 50,000 tokens
3. CLC analyzes all content                    → 10,000 tokens (context)
4. CLC generates response                      → 500 tokens
──────────────────────────────────────────────────────────────
Total: ~62,000 tokens
```

### After RAG (Vector + FTS Retrieval)

**Scenario:** Same query with RAG

```
1. recall("token savings")                     → 200 tokens (5 results)
2. ftsSearch("token savings")                  → 150 tokens (5 results)
3. Deduplicate + re-rank                       → 100 tokens
4. CLC receives augmented context              → 500 tokens
5. CLC generates response                      → 500 tokens
──────────────────────────────────────────────────────────────
Total: ~1,450 tokens

Savings: 97.7% reduction (62,000 → 1,450)
```

---

## Phase 7.6: Hybrid Embeddings System ⭐ (CURRENT)

**Status:** ✅ PRODUCTION READY (2025-10-22)
**File:** `knowledge/search.cjs`, `knowledge/embedder.cjs`, `knowledge/chunker.cjs`
**Model:** all-MiniLM-L6-v2 (384 dimensions, 80MB, ONNX runtime)
**Database:** `knowledge/02luka.db` (14 MB, 4,002 semantic chunks)

### What Changed from Phase 7.5?

Phase 7.6 introduces **true semantic understanding** via transformer-based embeddings, combined with FTS5 pre-filtering for speed. This eliminates the "waste paper" problem where 40% of documentation was unindexed.

**Key Improvements:**
- ✅ **100% Documentation Coverage**: 4,002 chunks from 258 documents (vs 125 reports in Phase 7.5)
- 🚀 **Exceptional Performance**: 7-8ms average query time (vs ~10ms FTS-only)
- 🧠 **Semantic Understanding**: Finds "token savings" when searching "cost reduction"
- ⚡ **Hybrid Architecture**: FTS pre-filter + embedding rerank (best of both worlds)

### Architecture: 3-Stage Hybrid Pipeline

```
┌─────────────────────────────────────────────────────────────┐
│ Stage 1: FTS Pre-filter (Fast, 4ms)                        │
│ • SQLite FTS5 keyword search                                │
│ • Returns top 50 candidates                                 │
│ • Handles special characters ("phase 7.2", "v2.0")         │
└────────────────────────────┬────────────────────────────────┘
                             ↓
┌─────────────────────────────────────────────────────────────┐
│ Stage 2: Embedding Rerank (Precise, 3ms)                   │
│ • Load query embedding: all-MiniLM-L6-v2                   │
│ • Compute cosine similarity with 50 candidates              │
│ • ONNX runtime, CPU-only, no GPU needed                    │
└────────────────────────────┬────────────────────────────────┘
                             ↓
┌─────────────────────────────────────────────────────────────┐
│ Stage 3: Hybrid Scoring (Balanced, 0.1ms)                  │
│ • Final = (0.3 × FTS_score) + (0.7 × Semantic_score)       │
│ • Sort by final score descending                            │
│ • Return top 10 results                                     │
└─────────────────────────────────────────────────────────────┘
```

### How It Works

**Step 1: Document Chunking (Semantic)**
```javascript
// chunker.cjs - Splits by markdown headers, preserves hierarchy
const chunks = semanticChunk(content, { filepath });

// Example chunk
{
  doc_path: "docs/PHASE7_2_DELEGATION.md",
  chunk_index: 3,
  text: "# Phase 7.2: Delegation\n\n## Architecture\n\n...",
  hierarchy: ["Phase 7.2: Delegation"],
  tags: ["success", "phase-doc", "delegation"],
  importance: 0.65
}
```

**Step 2: Embedding Generation (all-MiniLM-L6-v2)**
```javascript
// embedder.cjs - Generate 384-dimensional embeddings
const embedding = await getEmbedding(chunk.text);
// Returns: Float32Array(384) [0.023, -0.145, 0.091, ...]
```

**Step 3: Hybrid Search (3-stage pipeline)**
```javascript
// search.cjs - Hybrid retrieval
const results = await hybridSearch(db, query);

// 1. FTS pre-filter → 50 candidates (4ms)
// 2. Embedding rerank → semantic scores (3ms)
// 3. Hybrid scoring → final results (0.1ms)
```

### Performance Characteristics

| Metric | Phase 6 (TF-IDF) | Phase 7.5 (FTS) | **Phase 7.6 (Hybrid)** |
|--------|------------------|-----------------|------------------------|
| **Coverage** | 27 memories | 125 reports (68%) | **258 docs (100%)** ✅ |
| **Chunks** | 27 | N/A | **4,002** ✅ |
| **Query Time** | ~65ms | ~10ms | **7-8ms** 🚀 |
| **Semantic** | ❌ Keyword-like | ❌ Keyword only | ✅ **Full semantic** |
| **Special Chars** | N/A | ⚠️ Errors | ✅ **Fixed** |
| **Docs Indexed** | 0% | 0% | **100%** ✅ |
| **Reports Indexed** | N/A | 68% | **100%** ✅ |

### Example Usage

**Command:**
```bash
node knowledge/index.cjs --hybrid "token efficiency improvements"
```

**Output:**
```json
{
  "query": "token efficiency improvements",
  "results": [
    {
      "doc_path": "g/reports/RAG_QUICK_REFERENCE.md",
      "chunk_index": 5,
      "snippet": "...Phase 7.2 delegation: 89% token savings (6500→700)...",
      "scores": {
        "fts": 0.85,
        "semantic": 0.72,
        "final": 0.759
      }
    }
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

### Semantic Understanding Examples

| Query | Finds (Semantic Match) | Why |
|-------|------------------------|-----|
| "token efficiency" | "89% token savings", "delegation reduces costs" | Understands "efficiency" = "savings" |
| "reducing costs" | "delegation architecture", "token optimization" | Understands "cost" = "resource usage" |
| "phase 7.2 complete" | "Phase 7.2 Completion Report" | Handles decimals correctly |
| "version 2.0" | "boss-api v2.0 deployment" | Handles version numbers |

### When to Use Phase 7.6 Hybrid Search

✅ **Use as PRIMARY search method for:**
- General questions about the system
- Concept discovery ("token efficiency" finds "delegation")
- Version/phase lookups ("phase 7.2", "v2.0")
- Before asking CLC questions (saves tokens!)
- Finding related documentation across multiple files

**Performance:** 7-8ms avg, 100% docs indexed ✅

### Comparison with Previous Phases

**Phase 6 (TF-IDF) - Legacy:**
- Use for: Agent memory (past experiences, successful plans)
- Coverage: 27 memories only
- Semantic: Keyword-like (limited)

**Phase 7.5 (FTS) - Legacy:**
- Use for: Exact keyword/phrase matching
- Coverage: 125 reports (68%)
- Semantic: None (keyword only)

**Phase 7.6 (Hybrid) - CURRENT:**
- Use for: **Everything** (primary search method)
- Coverage: 258 documents (100%), 4,002 chunks
- Semantic: Full transformer-based understanding ✅

### Technical Details

**Embedding Model:** all-MiniLM-L6-v2
- **Dimensions:** 384
- **Size:** 80MB (cached locally)
- **Runtime:** ONNX (CPU-only, no GPU needed)
- **Speed:** ~3ms per query embedding
- **Quality:** Industry-standard sentence-transformers model

**Database Schema:**
```sql
CREATE TABLE document_chunks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  doc_path TEXT NOT NULL,
  chunk_index INTEGER NOT NULL,
  text TEXT NOT NULL,
  embedding BLOB,                    -- 384 floats = 1,536 bytes
  metadata TEXT,                     -- JSON
  indexed_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- FTS5 for keyword pre-filter
CREATE VIRTUAL TABLE document_chunks_fts
USING fts5(text, content='document_chunks', content_rowid='id');
```

**Storage Breakdown (14 MB total):**
- Embeddings (BLOB): 5.86 MB (4,002 × 1,536 bytes)
- Text content: 1.27 MB
- FTS5 index: 6.87 MB

### Commands

```bash
# Hybrid search (RECOMMENDED)
node knowledge/index.cjs --hybrid "query"

# With timing breakdown
node knowledge/index.cjs --verify "query"

# Benchmark performance
node knowledge/index.cjs --bench --iters=30

# Reindex all documents
node knowledge/index.cjs --reindex
```

### Documentation

- **Phase Guide**: `docs/PHASE7_6_HYBRID_EMBEDDINGS.md`
- **User Guide**: `knowledge/README.md`
- **Quick Reference**: `g/reports/RAG_QUICK_REFERENCE.md`
- **Implementation**: `g/reports/251022_HYBRID_VECTOR_DB_IMPLEMENTATION.md`
- **Verification**: `g/reports/251022_HYBRID_VDB_VERIFICATION.md`

---

## Comparison with Traditional RAG

| Feature | 02luka RAG | Traditional RAG (e.g., LangChain + Pinecone) |
|---------|------------|----------------------------------------------|
| **Vector DB** | In-memory TF-IDF | External (Pinecone, Weaviate, Chroma) |
| **Embedding Model** | TF-IDF (no API) | OpenAI Embeddings (API cost) |
| **Storage** | File-backed JSON + SQLite | Cloud-hosted vector store |
| **Offline** | ✅ Yes | ❌ No (requires internet) |
| **Cost** | ✅ Free | ❌ $0.0001/query + embedding costs |
| **Speed** | ✅ <100ms | ⚠️ 200-500ms (network latency) |
| **Portability** | ✅ Single file | ❌ Vendor lock-in |
| **Scalability** | ⚠️ Good (<10K docs) | ✅ Excellent (millions) |
| **Precision** | ✅ High | ✅ Very High |

---

## When NOT to Use Our RAG

❌ **Don't use for:**
- >100,000 documents (use proper vector DB)
- Multi-lingual embeddings (use transformers)
- Real-time collaborative search (use cloud RAG)
- Cross-modal search (text + images)

✅ **Perfect for:**
- Local AI agent operations
- Offline-first applications
- Cost-sensitive projects
- Privacy-critical data (no external API calls)
- Rapid prototyping

---

## Files Reference

### Core RAG Components

| File | Lines | Purpose |
|------|-------|---------|
| `memory/index.cjs` | 650 | Vector storage & retrieval (TF-IDF + cosine) |
| `knowledge/sync.cjs` | 180 | Sync JSON → SQLite |
| `knowledge/index.cjs` | 150 | FTS5 search & query API |
| `knowledge/schema.sql` | 80 | SQLite schema definition |
| `g/memory/vector_index.json` | - | In-memory vector storage |
| `knowledge/02luka.db` | - | SQLite database (FTS + analytics) |

### CLI Tools

| Tool | Purpose |
|------|---------|
| `knowledge/cli/recall.sh` | Vector search wrapper |
| `knowledge/cli/search.sh` | FTS search wrapper |
| `knowledge/cli/stats.sh` | Memory statistics |
| `scripts/knowledge_full_sync.sh` | Full sync + export |

---

## Performance Benchmarks

### Vector Search (memory/index.cjs)

| Memory Count | Query Time | Memory Usage |
|--------------|------------|--------------|
| 100 | 8ms | 2MB |
| 1,000 | 65ms | 15MB |
| 10,000 | 850ms | 120MB |

### FTS Search (knowledge/index.cjs)

| Document Count | Query Time | Index Size |
|----------------|------------|------------|
| 100 | 2ms | 50KB |
| 1,000 | 5ms | 400KB |
| 10,000 | 12ms | 3.5MB |
| 100,000 | 35ms | 28MB |

---

## Conclusion

The 02luka RAG system is a **lightweight, offline-first, file-backed** retrieval architecture optimized for local AI agent operations. It has evolved through three major phases:

1. **Phase 6 (Legacy):** TF-IDF vector search for semantic understanding (27 memories)
2. **Phase 7.5 (Legacy):** SQLite FTS5 for fast keyword matching (125 reports, 68% coverage)
3. **Phase 7.6 (CURRENT):** Hybrid embeddings (all-MiniLM-L6-v2 + FTS5) for true semantic search (4,002 chunks, 100% coverage) ⭐

**Key Achievements (Phase 7.6):**
- ✅ **100% Documentation Coverage**: 4,002 chunks from 258 documents (zero waste paper)
- 🚀 **7-8ms Query Latency**: 12x better than 100ms target
- 🧠 **True Semantic Understanding**: Transformer-based embeddings (all-MiniLM-L6-v2)
- ✅ Zero external API dependencies (offline-first)
- ✅ Fully portable (single SQLite file)
- ✅ Privacy-first (no data leaves local machine)
- ✅ 97.7% token reduction for knowledge queries (vs asking CLC directly)

**Status:** ✅ Production Ready (Phase 7.6 Complete)

---

**Last Updated:** 2025-10-22
**Maintained By:** CLC (Implementation) + Boss (Architecture)
**Version:** 1.0.0
