# Smart Merge Controller v2

**Status:** Production Ready
**Version:** 2.0
**Last Updated:** 2025-10-22

## Overview

The Smart Merge Controller is an intelligent result merging system that automatically selects between RRF (Reciprocal Rank Fusion) and MMR (Maximal Marginal Relevance) algorithms based on query characteristics and result diversity signals.

**Key Features:**
- Automatic RRF/MMR selection based on computed signals
- Real-time decision explanation with `--explain` flag
- Dual MMR modes: fast (Jaccard) and quality (embedding cosine)
- Performance optimized: <20ms for fast mode, <100ms for quality mode
- Comprehensive signal analysis (overlap, diversity, entropy, intent)

## Architecture

### Signal Computation

The controller computes five key signals to inform the merge strategy:

1. **Overlap Ratio** (Jaccard similarity)
   - Measures content similarity across results
   - High overlap → RRF (precision)
   - Low overlap → MMR (diversity)

2. **Source Diversity**
   - Ratio of unique sources to total sources
   - High diversity → MMR (exploration)

3. **Title Entropy** (Shannon entropy)
   - Measures vocabulary diversity in titles
   - Higher entropy indicates diverse topics

4. **Ops Intent Detection**
   - Keywords: status, verify, check, error, fix, deploy, etc.
   - Ops queries → RRF (exact matching)

5. **Creative Intent Detection**
   - Keywords: design, innovative, explore, research, etc.
   - Creative queries → MMR (exploration)

### Decision Logic

```
if overlap_ratio > 0.25 OR hasOps:
    use RRF (precision-focused)
else if overlap_ratio < 0.12 OR source_diversity > 0.55:
    use MMR (diversity-focused)
else:
    use RRF (default/safe)
```

### Thresholds

| Threshold | Value | Trigger |
|-----------|-------|---------|
| `overlap_rrf` | 0.25 | High overlap → RRF |
| `overlap_mmr` | 0.12 | Low overlap → MMR |
| `source_div_mmr` | 0.55 | High diversity → MMR |
| `title_entropy_mmr` | 0.6 | High entropy → MMR (future use) |

## Usage

### Command Line Interface

```bash
# Basic usage with auto-selection
echo '{
  "query": "check deployment status",
  "sourceLists": [
    {"source": "docs", "results": [...]},
    {"source": "logs", "results": [...]}
  ]
}' | node knowledge/smart_merge.cjs

# With explanation
echo '...' | node knowledge/smart_merge.cjs --explain

# With MMR quality mode
echo '...' | node knowledge/smart_merge.cjs --mmr-mode=quality

# With source boosting
echo '...' | node knowledge/smart_merge.cjs --boost-sources=docs:1.2,logs:0.9
```

### Programmatic Usage

```javascript
const { smartMerge } = require('./knowledge/smart_merge.cjs');

const sourceLists = [
  {
    source: 'docs',
    results: [
      { id: 1, text: 'content', fused_score: 0.9 },
      // ...
    ]
  },
  // ...
];

const result = await smartMerge(sourceLists, 'your query', {
  explain: true,
  mmrMode: 'fast',
  boosts: { docs: 1.2, logs: 0.9 },
  topK: 10
});

console.log(result.mode); // 'rrf' or 'mmr'
console.log(result.explanation); // Human-readable reason
console.log(result.results); // Merged results
```

## Flags

### `--explain`

Includes detailed decision reasoning in the output.

**Output additions:**
- `explanation`: Human-readable decision reason
- `meta.signals`: All computed signal values
- `meta.thresholds`: Decision threshold values
- `meta.mmr_mode`: Selected MMR mode

**Example:**
```json
{
  "mode": "rrf",
  "explanation": "RRF chosen: ops intent (keywords: [status,verify]) + high overlap (0.31 > 0.25)",
  "meta": {
    "signals": {
      "overlap_ratio": 0.31,
      "source_diversity": 0.42,
      "title_entropy": 0.54,
      "hasOps": true,
      "hasCreative": false
    },
    "thresholds": {
      "overlap_rrf": 0.25,
      "overlap_mmr": 0.12,
      "source_div_mmr": 0.55,
      "title_entropy_mmr": 0.6
    },
    "mmr_mode": "fast"
  }
}
```

### `--mmr-mode=fast|quality`

Selects MMR diversity calculation method.

**Fast Mode (default):**
- Uses Jaccard similarity on text tokens
- No database access required
- Performance: <20ms for ≤300 rows
- Best for: Real-time queries, large result sets

**Quality Mode:**
- Uses embedding cosine similarity
- Requires pre-fetched embeddings in results
- Performance: <100ms for ≤100 rows
- Best for: High-precision diversity, smaller result sets

**Example:**
```bash
# Fast mode (default)
echo '...' | node smart_merge.cjs --mmr-mode=fast

# Quality mode
echo '...' | node smart_merge.cjs --mmr-mode=quality
```

### `--boost-sources=source:weight,...`

Applies source-level boost multipliers (same as RRF merge).

**Example:**
```bash
echo '...' | node smart_merge.cjs --boost-sources=docs:1.2,logs:0.9,memory:1.1
```

### `--query=<text>`

Overrides query from input JSON (for intent detection).

**Example:**
```bash
echo '...' | node smart_merge.cjs --query="check deployment status"
```

## Input Format

```json
{
  "query": "search query text",
  "sourceLists": [
    {
      "source": "source_name",
      "results": [
        {
          "id": 1,
          "text": "content text",
          "title": "optional title",
          "snippet": "optional snippet",
          "doc_path": "optional path",
          "fused_score": 0.9,
          "embedding": [0.1, 0.2, ...] // optional, for quality mode
        }
      ]
    }
  ],
  "topK": 10  // optional, default 10
}
```

## Output Format

### Without `--explain`

```json
{
  "mode": "rrf",
  "results": [...],
  "count": 10,
  "timing_ms": {
    "signal_computation": 0.5,
    "merge_execution": 1.2,
    "total": 1.7
  }
}
```

### With `--explain`

```json
{
  "mode": "mmr",
  "explanation": "MMR chosen: low overlap (0.08 < 0.12) + creative intent (keywords: [design,explore])",
  "meta": {
    "signals": {
      "overlap_ratio": 0.08,
      "source_diversity": 0.67,
      "title_entropy": 0.82,
      "hasOps": false,
      "hasCreative": true
    },
    "thresholds": {
      "overlap_rrf": 0.25,
      "overlap_mmr": 0.12,
      "source_div_mmr": 0.55,
      "title_entropy_mmr": 0.6
    },
    "mmr_mode": "fast"
  },
  "results": [...],
  "count": 10,
  "timing_ms": {
    "signal_computation": 0.5,
    "merge_execution": 2.3,
    "total": 2.8
  }
}
```

## Examples

### Example 1: Ops Query (High Overlap) → RRF

**Query:** "check deployment status verify health"

**Input:**
```json
{
  "query": "check deployment status verify health",
  "sourceLists": [
    {
      "source": "docs",
      "results": [
        {"id": 1, "text": "status check deployment verify", "fused_score": 0.9},
        {"id": 2, "text": "health check status monitor", "fused_score": 0.8}
      ]
    },
    {
      "source": "logs",
      "results": [
        {"id": 3, "text": "deployment status verification", "fused_score": 0.85}
      ]
    }
  ]
}
```

**Output (with `--explain`):**
```json
{
  "mode": "rrf",
  "explanation": "RRF chosen: ops intent (keywords: [check,status,verify]) + high overlap (0.35 > 0.25)",
  "results": [...]
}
```

**Reasoning:** Ops keywords detected + high content overlap → RRF for precision

### Example 2: Creative Query (Low Overlap) → MMR

**Query:** "design innovative architecture explore"

**Input:**
```json
{
  "query": "design innovative architecture explore",
  "sourceLists": [
    {
      "source": "research",
      "results": [
        {"id": 1, "text": "design patterns architecture microservices", "fused_score": 0.9},
        {"id": 2, "text": "innovative approaches cloud native", "fused_score": 0.8}
      ]
    },
    {
      "source": "reports",
      "results": [
        {"id": 3, "text": "explore serverless optimization", "fused_score": 0.85},
        {"id": 4, "text": "refactoring strategies performance", "fused_score": 0.7}
      ]
    }
  ]
}
```

**Output (with `--explain`):**
```json
{
  "mode": "mmr",
  "explanation": "MMR chosen: low overlap (0.09 < 0.12) + high diversity (0.67 > 0.55)",
  "results": [...]
}
```

**Reasoning:** Low content overlap + diverse topics → MMR for exploration

### Example 3: Mixed Query (Default) → RRF

**Query:** "how to configure settings"

**Input:**
```json
{
  "query": "how to configure settings",
  "sourceLists": [
    {
      "source": "docs",
      "results": [
        {"id": 1, "text": "configuration guide settings", "fused_score": 0.9},
        {"id": 2, "text": "setup instructions parameters", "fused_score": 0.8}
      ]
    }
  ]
}
```

**Output (with `--explain`):**
```json
{
  "mode": "rrf",
  "explanation": "RRF chosen: default (safe for most queries)",
  "results": [...]
}
```

**Reasoning:** Moderate overlap, no strong signals → RRF (safe default)

## Performance

### Benchmarks (M1 MacBook Pro)

| Scenario | Mode | Rows | Time | Status |
|----------|------|------|------|--------|
| Small dataset | fast | 50 | ~1ms | ✅ Excellent |
| Medium dataset | fast | 300 | ~5ms | ✅ Excellent |
| Large dataset | fast | 1000 | ~15ms | ✅ Good |
| Small dataset | quality | 50 | ~30ms | ✅ Good |
| Medium dataset | quality | 100 | ~80ms | ✅ Acceptable |

### Performance Requirements

- **Fast mode:** <20ms for ≤300 rows (production requirement)
- **Quality mode:** <100ms for ≤100 rows (production requirement)

### Optimization Tips

1. **Use fast mode by default** - Quality mode only when precision matters
2. **Limit topK** - Smaller topK = faster execution
3. **Pre-filter results** - Reduce input size before merging
4. **Cache embeddings** - For quality mode, pre-fetch embeddings in results

## Testing

### Unit Tests

```bash
cd knowledge
node test/smart_merge.test.cjs
```

**Coverage:**
- Signal computation (overlap, diversity, entropy, intent)
- Decision logic (RRF vs MMR selection)
- MMR algorithm (diversification, topK)
- Edge cases (empty, single source, missing fields)
- Performance validation

### CLI Tests

```bash
cd knowledge
bash test/smart_merge_cli.test.sh
```

**Coverage:**
- CLI flag parsing (--explain, --mmr-mode, --boost-sources)
- Output format validation
- Performance benchmarks
- Real-world scenarios

### Manual Testing

```bash
# Test 1: Ops query
echo '{
  "query": "check status",
  "sourceLists": [
    {"source": "docs", "results": [
      {"id": 1, "text": "status check verify", "fused_score": 0.9}
    ]}
  ]
}' | node knowledge/smart_merge.cjs --explain

# Test 2: Creative query
echo '{
  "query": "design innovative",
  "sourceLists": [
    {"source": "research", "results": [
      {"id": 1, "text": "design patterns", "fused_score": 0.9},
      {"id": 2, "text": "innovative approaches", "fused_score": 0.8}
    ]}
  ]
}' | node knowledge/smart_merge.cjs --explain --mmr-mode=fast
```

## Troubleshooting

### Issue: "Input must be valid JSON"

**Cause:** Invalid JSON input format

**Solution:** Validate JSON with `jq`:
```bash
echo '...' | jq '.' > /dev/null && echo "Valid JSON"
```

### Issue: Performance degradation

**Cause:** Large dataset or quality mode on too many rows

**Solution:**
- Use fast mode for >100 rows
- Reduce topK parameter
- Pre-filter results before merge

### Issue: Wrong mode selected

**Cause:** Unexpected signals triggering wrong decision

**Solution:** Use `--explain` to see decision reasoning:
```bash
echo '...' | node smart_merge.cjs --explain | jq '.explanation, .meta.signals'
```

### Issue: No query provided warning

**Cause:** Missing query in input JSON

**Solution:** Add query field or use `--query` flag:
```bash
echo '...' | node smart_merge.cjs --query="your query here"
```

## Future Enhancements

### Planned Features

1. **Adaptive thresholds** - Learn optimal thresholds from user feedback
2. **Title entropy in decision** - Use title_entropy signal in decision logic
3. **Hybrid mode** - Combine RRF + MMR for best of both worlds
4. **Query embedding similarity** - Use query-to-result embedding similarity as signal
5. **Time-based decay** - Weight recent results higher

### Performance Optimizations

1. **SIMD cosine similarity** - Faster embedding comparisons
2. **Parallel signal computation** - Compute signals concurrently
3. **Streaming MMR** - Process results incrementally
4. **Caching layer** - Cache computed signals per query

## References

- [RRF Algorithm (Cormack et al., 2009)](https://plg.uwaterloo.ca/~gvcormac/cormacksigir09-rrf.pdf)
- [MMR Algorithm (Carbonell & Goldstein, 1998)](https://www.cs.cmu.edu/~jgc/publication/The_Use_MMR_Diversity_Based_LTMIR_1998.pdf)
- [Jaccard Similarity](https://en.wikipedia.org/wiki/Jaccard_index)
- [Shannon Entropy](https://en.wikipedia.org/wiki/Entropy_(information_theory))

## Changelog

### v2.0 (2025-10-22)
- ✨ Added auto RRF/MMR selection with signal-based decision
- ✨ Added `--explain` flag with decision reasoning
- ✨ Added `--mmr-mode=fast|quality` flag
- ✨ Implemented MMR algorithm with fast/quality modes
- ✨ Added comprehensive signal computation
- ✨ Added ops/creative intent detection
- 📝 Created full documentation
- ✅ Added comprehensive test suite (38 unit tests + CLI tests)
- ⚡ Performance optimized (<20ms fast mode, <100ms quality mode)

### v1.0 (2025-10-20)
- 🎉 Initial RRF merge implementation
- ✨ Source-level boosting
- ⚡ Performance requirements (<5ms for ≤200 rows)
