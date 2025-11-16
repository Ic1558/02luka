# Phase 15: Autonomous Knowledge Routing (AKR)

## Overview

Building on Phase 14's unified knowledge infrastructure, Phase 15 implements **Autonomous Knowledge Routing (AKR)** - an intelligent system that automatically routes queries to optimal knowledge sources and generates context-aware responses.

## Phase 14 Foundation (Completed ✅)

Phase 14 established the knowledge infrastructure:

- **Federation**: Unified index with 3,817 chunks from 240 files
- **Telemetry**: Canonical event schema (rag.ctx.*, rag.probe.*, bridge.sync.*)
- **Bridge Sync**: MCP Memory/Search integration pipeline
- **System Health**: 100% operational (19/19 checks passing)
- **RAG API**: FastAPI server with semantic search (localhost:8765)

## Phase 15 Goals

### 1. Intelligent Query Routing
- Analyze user queries to determine optimal knowledge sources
- Route to local index, MCP Memory, or external APIs based on query characteristics
- Implement fallback chains for query failures

### 2. Agent Orchestration
- Create routing agent that coordinates knowledge retrieval
- Implement context aggregation from multiple sources
- Add response synthesis with source attribution

### 3. RAG Pipeline Optimization
- Hybrid search (semantic + keyword) with configurable weights
- Query expansion and reformulation
- Context window management for LLM responses

### 4. Observability & Metrics
- Track routing decisions and latencies
- Measure hit rates by source type
- Implement telemetry for query patterns

## Deliverables

### Core Components

1. **Routing Engine** (`tools/akr_router.py`)
   - Query analyzer (semantic classification)
   - Source selector (rule-based + ML scoring)
   - Fallback orchestrator

2. **Context Aggregator** (`tools/akr_context.py`)
   - Multi-source result merging
   - Deduplication and ranking
   - Source attribution metadata

3. **Configuration** (`config/akr.yaml`)
   - Routing rules (query patterns → sources)
   - Source priorities and timeouts
   - Cache policies

### Documentation

4. **Architecture Doc** (`docs/PHASE15_AKR_ARCHITECTURE.md`)
   - System design and data flow
   - Routing decision tree
   - Integration points

5. **Operations Manual** (`g/manuals/AKR_OPERATIONS.md`)
   - Configuration guide
   - Troubleshooting procedures
   - Performance tuning

### Testing & Verification

6. **Test Suite** (`tests/test_akr_*.py`)
   - Unit tests for routing logic
   - Integration tests with mock sources
   - Performance benchmarks

7. **Verification Report** (`g/reports/PHASE_15_VERIFICATION.md`)
   - Test results and metrics
   - Performance analysis
   - Production readiness checklist

## Technical Approach

### Query Analysis Pipeline

```
User Query
    ↓
[Semantic Classifier]
    ↓
Query Type: {factual, procedural, diagnostic, exploratory}
    ↓
[Source Selector]
    ↓
Sources: [local_index, mcp_memory, external_api]
    ↓
[Parallel Retrieval]
    ↓
[Context Aggregator]
    ↓
Synthesized Response + Sources
```

### Routing Decision Matrix

| Query Type | Primary Source | Fallback | Use Case |
|------------|---------------|----------|----------|
| Factual | MCP Memory | Local Index | "What is X?" |
| Procedural | Local Index (manuals) | MCP Search | "How to do Y?" |
| Diagnostic | Telemetry Logs | Local Index | "Why did Z fail?" |
| Exploratory | Hybrid (all sources) | - | "Find related to X" |

### Integration Points

1. **Upstream**: User queries via CLI, web UI, or API
2. **Downstream**:
   - RAG API (localhost:8765) for local index
   - MCP Memory (localhost:5330) for persistent knowledge
   - External LLMs (Moonshot AI Kimi) for generation

## Success Criteria

### Functional Requirements
- ✅ Route 95%+ queries to appropriate sources
- ✅ Response latency < 500ms (p95)
- ✅ Support 5+ concurrent queries
- ✅ Graceful degradation on source failures

### Operational Requirements
- ✅ Comprehensive logging and telemetry
- ✅ Configuration hot-reload support
- ✅ Health check endpoints
- ✅ Prometheus-compatible metrics

### Documentation Requirements
- ✅ Architecture and design docs
- ✅ API documentation with examples
- ✅ Operations manual and troubleshooting guide
- ✅ Performance tuning guide

## Dependencies

### Phase 14 Components (Required)
- ✅ RAG API (port 8765) - semantic search
- ✅ Unified index (memory/index_unified/unified.jsonl)
- ✅ Telemetry schema (config/telemetry_unified.yaml)

### External Services (Optional for MVP)
- MCP Memory (port 5330) - to be configured
- Moonshot AI Kimi API - for response generation

### Python Packages
```
sentence-transformers>=2.2.0
fastapi>=0.100.0
pydantic>=2.0.0
aiohttp>=3.8.0
prometheus-client>=0.17.0
```

## Implementation Phases

### Phase 15.1: Core Routing Engine (Week 1)
- Query analyzer implementation
- Source selector with rule-based routing
- Basic telemetry integration

### Phase 15.2: Context Aggregation (Week 2)
- Multi-source result merging
- Deduplication and ranking algorithms
- Source attribution metadata

### Phase 15.3: Optimization & Tuning (Week 3)
- Performance profiling and optimization
- Cache layer implementation
- Load testing and benchmarking

### Phase 15.4: Documentation & Verification (Week 4)
- Complete documentation suite
- End-to-end testing
- Production readiness review

## Related Work

### Phase 14 Reports
- [Phase 14 Final System Restoration](../PHASE_14_FINAL_SYSTEM_RESTORATION.md)
- [Phase 14.1 Federation](../PHASE_14_1_FEDERATION.md)
- [Phase 14.2 Telemetry](../PHASE_14_2_TELEMETRY.md)
- [Phase 14.3 Bridge](../PHASE_14_3_BRIDGE.md)

### Configuration Files
- `config/akr.yaml` (to be created)
- `config/telemetry_unified.yaml` (existing)
- `config/bridge_knowledge.yaml` (existing)

## Risk Assessment

### Technical Risks
- **Latency**: Multi-source queries may exceed 500ms target
  - *Mitigation*: Parallel retrieval + aggressive timeouts + caching
- **Source Availability**: External services may be unavailable
  - *Mitigation*: Fallback chains + circuit breakers

### Operational Risks
- **Configuration Complexity**: Many knobs to tune
  - *Mitigation*: Sensible defaults + comprehensive docs
- **Debugging Difficulty**: Distributed traces across sources
  - *Mitigation*: Structured logging + correlation IDs

## Next Steps After Phase 15

### Phase 16: Learning & Adaptation (Proposed)
- ML-based routing model trained on telemetry
- Query reformulation using user feedback
- Automatic source priority adjustment

### Phase 17: Multi-Agent Collaboration (Proposed)
- Agent-to-agent knowledge sharing
- Federated learning across agent instances
- Consensus-based response synthesis

---

**Generated**: 2025-11-06
**Author**: CLC (Claude Code)
**Status**: Draft - Awaiting approval
**Target Branch**: `main`
**Source Branch**: `claude/exploration-and-research-011CUrRfU1hPvBmZXZqjgN9M`

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
