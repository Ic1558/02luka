# Phase 14.4 – RAG-Driven Contextual Response (Plan)

**Classification:** Strategic Integration Patch (SIP)  
**Deployed by:** CLS (Cognitive Local System Orchestrator)  
**Maintainer:** GG Core (02LUKA Automation)  
**Version:** v1.4-rag-context  
**Revision:** r1  
**Phase:** 14.4 – RAG-Driven Contextual Response  
**Timestamp:** 2025-11-07T00:50:00+07:00  
**WO-ID:** WO-251107-PHASE-14-RAG-UNIFICATION  
**Verified by:** CDC / CLC / GG SOT Audit Layer  
**Status:** Planned  
**Evidence Hash:** __TBD_AFTER_EXECUTION__

---

## Summary

Phase 14.4 enables RAG-driven contextual response for all agents (GG, CDC, CLS). Implements query/rerank pipeline with telemetry tagging (`rag.ctx.hit`/`rag.ctx.miss`) for traceability.

## Dependencies

✅ **Phase 14.1:** RAG Memory Index Federation (unified.jsonl)  
✅ **Phase 14.2:** Unified SOT Telemetry Schema  
✅ **Phase 14.3:** Knowledge ↔ MCP Bridge (ingest pipeline)

## Objectives

1. **Query Pipeline:** Implement RAG query interface with embedding + reranking
2. **Agent Binding:** Enable contextual retrieval for GG, CDC, CLS agents
3. **Telemetry Integration:** Tag queries with `rag.ctx.hit`/`rag.ctx.miss` in Phase 14.2 format
4. **Performance:** Target <50ms query latency (95th percentile)

## Deliverables

### 1. Configuration
- **File:** `config/rag_context.yaml`
- **Purpose:** Query pipeline settings (embedding model, reranker, top_k, filters)
- **Key settings:**
  - Embedding: `text-embedding-3-large`
  - Reranker: `bge-reranker-v2-m3`
  - Top-K: 5 (initial), 20 (rerank)
  - Filters: source, phase, tags

### 2. Query Tool
- **File:** `tools/rag_context_query.zsh`
- **Features:**
  - Query → embedding → search → rerank → results
  - Agent-specific filters (GG/CDC/CLS)
  - Telemetry emission (`rag.ctx.hit`/`rag.ctx.miss`)
  - Performance metrics (latency_ms)

### 3. Agent Integration
- **Files:** `tools/rag_context_agent.zsh`
- **Purpose:** Wrapper for agent-specific queries
- **Usage:**
  ```bash
  ./tools/rag_context_agent.zsh --agent CLS --query "telemetry schema"
  ```

### 4. Verification Report
- **File:** `g/reports/PHASE_14_4_RAG_CONTEXT.md`
- **Contents:**
  - Query examples (3 agents)
  - Performance metrics (latency, hit rate)
  - Telemetry validation
  - Acceptance criteria results

## Implementation Plan

### Step 1: Query Pipeline (Core)
```bash
# 1. Create config
cat > config/rag_context.yaml <<EOF
query:
  embedding_model: text-embedding-3-large
  reranker_model: bge-reranker-v2-m3
  top_k_initial: 20
  top_k_final: 5
  filters:
    source: [unified_memory, docs, reports]
    phase: [14.1, 14.2, 14.3, 14.4]
telemetry:
  schema: config/telemetry_unified.yaml
  events:
    - rag.ctx.hit
    - rag.ctx.miss
    - rag.ctx.query
EOF

# 2. Create query tool
./tools/rag_context_query.zsh \
  --config config/rag_context.yaml \
  --query "telemetry schema" \
  --agent CLS \
  --top-k 5
```

### Step 2: Agent Binding
```bash
# 3. Create agent wrapper
./tools/rag_context_agent.zsh \
  --agent GG \
  --query "RAG federation" \
  --verbose
```

### Step 3: Telemetry Integration
```bash
# 4. Query with telemetry
./tools/rag_context_query.zsh \
  --query "knowledge bridge" \
  --emit-telemetry \
  --agent CDC

# 5. Merge telemetry
./tools/telemetry_sync.zsh --source g/bridge/*.log --append
```

## Acceptance Criteria

- [ ] **Query Performance:** <50ms latency (95th percentile)
- [ ] **Hit Rate:** ≥95% for sample queries (100 items)
- [ ] **Telemetry:** All queries tagged with `rag.ctx.hit`/`rag.ctx.miss`
- [ ] **Agent Binding:** GG, CDC, CLS can query unified index
- [ ] **Idempotency:** Rerun queries return consistent results

## Testing Strategy

### Unit Tests
- Query tool: Test embedding + rerank pipeline
- Agent wrapper: Test agent-specific filters
- Telemetry: Test event emission format

### Integration Tests
- End-to-end: Query → Results → Telemetry
- Performance: Latency benchmarks (100 queries)
- Hit Rate: Sample queries (100 items)

### Validation
- Query results match expected sources
- Telemetry events in Phase 14.2 format
- Agent filters work correctly

## Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Query Latency | <50ms (p95) | `latency_ms` in telemetry |
| Hit Rate | ≥95% | `rag.ctx.hit` / total queries |
| Telemetry Coverage | 100% | All queries emit events |
| Agent Compatibility | 100% | All 3 agents can query |

## Rollback Plan

1. **Disable query pipeline:** Comment out agent bindings
2. **Restore config:** Use previous `rag_unification.yaml`
3. **Clear telemetry:** Remove `rag.ctx.*` events from unified.jsonl

## Next Steps

- Phase 15 – Autonomous Knowledge Routing (AKR)
- Advanced filtering (time-based, relevance threshold)
- Multi-agent query coordination

---

_Plan created per Rule 93 (Evidence-Based Operations)._

