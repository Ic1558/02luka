# RRF Merger v2 - Source-Level Boosting

**Implementation:** WO-251022-GG-MERGE-RERANK-V2
**Status:** ✅ COMPLETE
**Date:** 2025-10-22

---

## Overview

RRF (Reciprocal Rank Fusion) merger with source-level weighting for combining search results from multiple knowledge sources (docs, reports, memory).

### Key Features

- ✅ **RRF Algorithm**: Reciprocal Rank Fusion for fair score aggregation
- ✅ **Source Boosting**: Multiply fused scores by source-specific weights
- ✅ **Deduplication**: Automatically merges duplicate documents across sources
- ✅ **High Performance**: <0.4ms for 200 rows (13x better than 5ms target)
- ✅ **CLI Ready**: Simple flag-based configuration

---

## Usage

### Basic Merge (No Boost)

```bash
node knowledge/merge.cjs < input.json
```

### With Source Boosting

```bash
# Boost docs by 1.2x, reduce memory by 0.8x
node knowledge/merge.cjs --boost-sources=docs:1.2,memory:0.8 < input.json

# Multiple sources with different weights
node knowledge/merge.cjs --boost-sources=docs:1.2,reports:1.1,memory:0.9 < input.json
```

---

## Input Format

JSON array of source lists, each with a `source` name and `results` array:

```json
[
  {
    "source": "docs",
    "results": [
      {
        "id": "doc1",
        "doc_path": "docs/PHASE7.md",
        "text": "Phase 7 delegation guide",
        "score": 0.95
      }
    ]
  },
  {
    "source": "memory",
    "results": [
      {
        "id": "mem1",
        "doc_path": "memory/clc/session.md",
        "text": "CLC session notes",
        "score": 0.88
      }
    ]
  }
]
```

---

## Output Format

```json
{
  "merged_results": [
    {
      "id": "doc1",
      "doc_path": "docs/PHASE7.md",
      "text": "Phase 7 delegation guide",
      "score": 0.95,
      "source": "docs",
      "fused_score": 0.0328,
      "boosted_score": 0.0394,
      "sources": [
        {"source": "docs", "rank": 0, "rrfScore": 0.0167},
        {"source": "memory", "rank": 2, "rrfScore": 0.0161}
      ]
    }
  ],
  "count": 7,
  "boosts": {"docs": 1.2, "memory": 0.8},
  "timing_ms": 0.317
}
```

### Fields

- **fused_score**: Raw RRF score (sum of 1/(k+rank) across all sources)
- **boosted_score**: `fused_score * boost[source]` (used for final ranking)
- **sources**: List of sources containing this document with their ranks
- **timing_ms**: Merge operation runtime

---

## Algorithm

### RRF Formula

```
fused_score = Σ (1 / (k + rank_i))
```

where:
- `k = 60` (RRF constant, prevents division by zero)
- `rank_i` = position in source list (0 = top)

### Source Boosting

```
boosted_score = fused_score × boost[source]
```

Default boost = 1.0 (no change)

### Final Ranking

Results sorted by `boosted_score` (descending), then top K returned.

---

## Performance

| Rows | Avg Time | Target | Status |
|------|----------|--------|--------|
| 7    | 0.14ms   | 5ms    | ✓ PASS |
| 201  | 0.32ms   | 5ms    | ✓ PASS |

**Performance Factor:** 13-16x better than target

---

## Testing

### Run Test Suite

```bash
bash knowledge/test/test_merge.sh
```

### Test Cases

1. **Basic RRF Merge** - No boost, verify deduplication
2. **Boost Effect** - Verify docs > memory when boosted
3. **Tied Items** - Verify boost breaks ties correctly
4. **Performance** - 201 rows in <5ms
5. **Deduplication** - Same doc in multiple sources

### Manual Testing

```bash
# Test with sample data
node knowledge/merge.cjs < knowledge/test/test_merge_data.json

# Test with boost
node knowledge/merge.cjs --boost-sources=docs:1.2,memory:0.8 \
  < knowledge/test/test_merge_data.json
```

---

## Integration

### Module Usage

```javascript
const { rrfMerge, parseBoosts } = require('./knowledge/merge.cjs');

const sourceLists = [
  { source: 'docs', results: [...] },
  { source: 'memory', results: [...] }
];

const boosts = { docs: 1.2, memory: 0.8 };
const merged = rrfMerge(sourceLists, { boosts, topK: 10 });
```

### Pipeline Integration

```bash
# Combine with hybrid search
node knowledge/index.cjs --hybrid "query" --json | \
  node knowledge/merge.cjs --boost-sources=docs:1.2
```

---

## Acceptance Criteria

✅ **Flag Parsing**: `--boost-sources=docs:1.2,memory:0.8` correctly parsed
✅ **Boost Effect**: Docs ranked higher than memory when otherwise tied
✅ **Performance**: <5ms for ≤200 rows (actual: 0.32ms avg)
✅ **Schema**: Dedup and result format unchanged
✅ **Testing**: Comprehensive test suite passes

---

## Files

- `knowledge/merge.cjs` - Main implementation (150 lines)
- `knowledge/test/test_merge.sh` - Test suite
- `knowledge/test/test_merge_data.json` - Sample data (7 items)
- `knowledge/test/test_merge_tied.json` - Tied items test
- `knowledge/test/test_merge_large.json` - Performance test (201 items)

---

## Future Enhancements

- [ ] Adaptive boost learning from user feedback
- [ ] Time-decay for stale results
- [ ] Category-specific boosts (API docs vs guides)
- [ ] A/B testing framework for boost optimization
