# WO: RRF Merger v2 — add --boost-sources
- **ID:** WO-251022-GG-MERGE-RERANK-V2
- **Goal:** Allow source-level weighting in RRF fusion.

## Patch (knowledge/merge.cjs)
- New flag `--boost-sources=docs:1.2,reports:1.1,memory:0.9`
- After computing `fused_score`, multiply by `boost[source]` (default 1.0).
- Keep dedup & schema unchanged.

## Acceptance
- Passing `--boost-sources=docs:1.2,memory:0.8` pushes docs above memory when otherwise tied.
- Runtime still <5ms for ≤200 rows.

