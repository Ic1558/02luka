# Dashboard + AP/IO v3.1 Ledger Integration Opportunity

**Date:** 2025-11-16  
**Status:** Future Enhancement Opportunity

---

## Current State

### Dashboard WO Pipeline Metrics
- ✅ Calculates metrics from WO API data
- ✅ Shows throughput, processing time, queue depth, success rate
- ✅ Updates automatically on refresh

### AP/IO v3.1 Ledger
- ✅ Tracks agent activity with precise timestamps
- ✅ Records `execution_duration_ms` for accurate timing
- ✅ Links events via `parent_id` and `correlation_id`
- ✅ Has `pretty_print.zsh` for analysis

---

## Integration Opportunity

### Potential Benefits

1. **More Accurate Metrics**
   - Dashboard currently uses WO API data (may have delays)
   - AP/IO v3.1 Ledger has real-time, precise timestamps
   - Could provide more accurate `avgProcessingTime`

2. **Agent-Level Visibility**
   - Dashboard shows WO-level metrics
   - AP/IO v3.1 Ledger tracks individual agent activity
   - Could show: "Which agent is slowest?", "Which agent has most errors?"

3. **Cross-Agent Correlation**
   - Dashboard shows single WO flow
   - AP/IO v3.1 Ledger tracks multi-agent coordination
   - Could show: "How long does Liam → CLS → Andy flow take?"

4. **Historical Analysis**
   - Dashboard shows current state
   - AP/IO v3.1 Ledger has append-only history
   - Could show trends: "Throughput over time", "Success rate trends"

---

## Proposed Integration Approach

### Option 1: API Endpoint for Ledger Data
Create API endpoint that reads AP/IO v3.1 ledger:
```javascript
// New endpoint: /api/ledger/metrics
// Returns aggregated metrics from ledger
{
  "throughput": 12.5,
  "avgProcessingTime": 45,
  "agentBreakdown": {
    "hybrid": { "count": 10, "avgTime": 50 },
    "andy": { "count": 5, "avgTime": 30 },
    "cls": { "count": 8, "avgTime": 40 }
  },
  "correlationChains": 15
}
```

### Option 2: Direct File Reading (Server-Side)
Dashboard backend reads ledger files directly:
```javascript
// Server-side script aggregates ledger data
// Returns JSON to dashboard
```

### Option 3: Hybrid Approach
- Dashboard continues using WO API for real-time WO status
- Add separate "Agent Activity" section using AP/IO v3.1 Ledger data
- Best of both worlds: WO pipeline + agent activity

---

## Implementation Steps (Future)

1. **Create Ledger Aggregation Script**
   - Read `g/ledger/**/*.jsonl` files
   - Aggregate by agent, correlation_id, time window
   - Calculate metrics similar to dashboard

2. **Add API Endpoint**
   - `/api/ledger/metrics` - Aggregated metrics
   - `/api/ledger/agents` - Per-agent breakdown
   - `/api/ledger/correlations` - Correlation chain analysis

3. **Extend Dashboard**
   - Add "Agent Activity" section
   - Show agent-level metrics
   - Show correlation chains
   - Link to ledger viewer

4. **Real-Time Updates**
   - Option: WebSocket for live ledger updates
   - Option: Poll ledger endpoint every 30s

---

## Example Metrics from Ledger

```javascript
{
  "pipeline": {
    "throughput": 12.5,  // From ledger task_result events
    "avgProcessingTime": 45,  // From execution_duration_ms
    "queueDepth": 3,  // From task_start without task_result
    "agentBreakdown": {
      "hybrid": {
        "count": 10,
        "avgTime": 50,
        "successRate": 90
      },
      "andy": {
        "count": 5,
        "avgTime": 30,
        "successRate": 100
      }
    },
    "correlationChains": 15,  // Multi-agent workflows
    "longestChain": {
      "correlation_id": "corr-20251116-001",
      "duration": 120,
      "agents": ["liam", "cls", "andy"]
    }
  }
}
```

---

## Priority

**Current Priority:** Low (Phase 3-5 integration first)

**Rationale:**
1. Dashboard metrics work well with WO API data
2. AP/IO v3.1 Ledger integration needs Phase 3-5 complete first
3. Better to have real ledger data before integrating

**Suggested Timeline:**
- After Phase 3 (Hybrid Integration) complete
- After Phase 4 (Andy Integration) complete
- Then consider dashboard integration

---

## Notes

- Dashboard metrics are client-side calculations (fast, no server load)
- Ledger integration would require server-side aggregation (more complex)
- Consider performance: ledger files can grow large over time
- May need ledger rotation/archival strategy for long-term use

---

**Status:** Future Enhancement  
**Dependencies:** Phase 3-5 (Real Integration)  
**Owner:** TBD (after Phase 3-5 complete)
