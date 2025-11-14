# WO: Smart Merge Controller v2 — --explain + --mmr-mode
- **ID:** WO-251022-GG-SMART-MERGE-CONTROLLER-v2
- **Goal:** Add `--explain` output and `--mmr-mode=fast|quality` to `knowledge/smart_merge.cjs`.

## Patches
1) CLI flags:
   - `--explain` → include `"explanation"` string and `"thresholds"` in `meta`.
   - `--mmr-mode=fast|quality` (default `fast`):
     - `fast` = diversity via snippet-token Jaccard (no DB hit).
     - `quality` = fetch embeddings per item (join on id) and use cosine.

2) Decision output shape:
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
    "thresholds": { "overlap_rrf": 0.25, "overlap_mmr": 0.12, "source_div_mmr": 0.55, "title_entropy_mmr": 0.6 },
    "mmr_mode": "fast"
  },
  "results": [ ... ]
}
```

3) Docs update `docs/SMART_MERGE_CONTROLLER.md` with flags and examples.

## Acceptance
- With `--explain`, JSON includes human-readable reason and thresholds.
- `--mmr-mode=fast` runs <20ms @ ≤300 rows; quality still acceptable on ≤100 rows.
- Controller picks MMR/RRF per rules and passes tests.

