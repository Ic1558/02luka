# Feature SPEC: Phase 6 - Adaptive Governance (Simplified)

**Feature ID:** `phase6_adaptive_governance`  
**Version:** 1.1.0 (Simplified)  
**Date:** 2025-11-12  
**Status:** Ready for Development

---

## Objective

Add adaptive insights to Phase 5 by learning from metrics patterns and automatically suggesting improvements. Keep it simple, practical, and immediately useful.

---

## Problem Statement

**Current State:**
- Phase 5 collects metrics but doesn't learn from them
- No trend detection or pattern recognition
- Manual analysis required to spot issues
- No automatic improvement suggestions

**Desired State:**
- Simple trend detection (improving/declining/stable)
- Basic anomaly alerts (when metrics spike/drop)
- Automatic R&D proposal generation for obvious improvements
- Enhanced daily digest with insights

---

## Architecture (Simplified)

```
Metrics (Redis) → Adaptive Collector → Insights JSON → Daily Digest
                                      ↓
                              R&D Proposal (if needed)
```

**Key Principle:** Start simple, add complexity only when needed.

---

## Core Components

### 1. Adaptive Collector (`tools/adaptive_collector.zsh`)

**Purpose:** Simple trend detection and anomaly spotting.

**What it does:**
- Reads last 7 days of metrics from monthly JSON files
- Calculates simple trends: improving (+), declining (-), stable (=)
- Detects anomalies: values >2x or <0.5x average
- Generates insights JSON

**Inputs:**
- `g/reports/memory_metrics_YYYYMM.json` (last 2-3 months)
- Redis current values: `memory:agents:claude`, `memory:agents:rnd`, `memory:agents:mary`

**Output:**
- `mls/adaptive/insights_YYYYMMDD.json` (simple structure)
- Publish to Redis: `governance:insight` (optional, for future use)

**Trend Detection (Simple):**
```bash
# Compare last 7 days vs previous 7 days
if current_avg > previous_avg * 1.1: "improving" (trend: "up")
if current_avg < previous_avg * 0.9: "declining" (trend: "down")
else: "stable" (trend: "stable")
```

**Anomaly Detection (Simple):**
```bash
# If value > 2x average or < 0.5x average: anomaly
```

**No complex math, no ML, just simple comparisons.**

---

### 2. Enhanced Daily Digest

**Purpose:** Add "Adaptive Insights" section to existing digest.

**What it adds:**
```markdown
## Adaptive Insights

### Trends (Last 7 Days)
- Claude Code hook success: Improving (+5%)
- R&D proposal acceptance: Stable (85%)
- Mary task completion: Declining (-3%) ⚠️

### Anomalies
- Mary completion dropped to 88% (expected: 95%)

### Recommendations
- Investigate Mary task completion decline
```

**Implementation:**
- Modify `tools/memory_daily_digest.zsh`
- Read `mls/adaptive/insights_YYYYMMDD.json`
- Append section if insights exist

---

### 3. Simple Auto-Proposal Generator (`tools/adaptive_proposal_gen.zsh`)

**Purpose:** Generate R&D proposals for obvious improvements.

**When it triggers:**
- Metric declining for 3+ days
- Metric below threshold (e.g., health < 85%)
- Anomaly detected
- **Guard:** Metric must have ≥3 data points (samples) to avoid noise

**What it generates:**
- Simple R&D proposal YAML
- Only for low-risk changes (docs, tests, CI)
- Submit to `bridge/inbox/RND/`

**Safety:**
- Max 1 proposal per day
- Only for metrics we understand well
- Human approval still required (via R&D gate)

**Example Proposal:**
```yaml
id: RND-ADAPTIVE-20251112-001
type: adaptive_insight
metric: mary_completion_rate
issue: Declining for 3 days (95% → 88%)
suggestion: Review Mary task logs for patterns
risk: low
auto_generated: true
```

---

## Data Structures (Simplified)

### Insights JSON
```json
{
  "date": "2025-11-12",
  "trends": {
    "claude_hook_success": {
      "direction": "improving",
      "trend": "up",
      "change": "+5%"
    },
    "rnd_acceptance": {
      "direction": "stable",
      "trend": "stable",
      "change": "0%"
    },
    "mary_completion": {
      "direction": "declining",
      "trend": "down",
      "change": "-3%"
    }
  },
  "anomalies": [
    {"metric": "mary_completion", "value": 0.88, "expected": 0.95, "severity": "medium"}
  ],
  "recommendations": [
    "Investigate Mary task completion decline"
  ],
  "recommendation_summary": "Mary completion declining (-3%). Review task logs for patterns."
}
```

**Simple, readable, actionable.**

---

## LaunchAgents

### 1. Adaptive Collector (Daily 06:30)
```xml
com.02luka.adaptive.collector.daily
- Runs: Daily 06:30 (after metrics collection at 23:55)
- Script: tools/adaptive_collector.zsh
- Output: mls/adaptive/insights_YYYYMMDD.json
```

### 2. Auto-Proposal Generator (Daily 07:00)
```xml
com.02luka.adaptive.proposal.gen
- Runs: Daily 07:00 (after adaptive collector)
- Script: tools/adaptive_proposal_gen.zsh
- Output: R&D proposals in bridge/inbox/RND/
```

**That's it. No complex scheduling.**

---

## Integration Points

### Phase 5
- Read from monthly metrics JSON
- Enhance daily digest
- Use existing health checks

### R&D System
- Generate proposals in existing format
- Use existing R&D gate for approval

### Daily Digest
- Append insights section
- No breaking changes

---

## Success Criteria

### Functional
- ✅ Insights generated daily
- ✅ Daily digest includes insights
- ✅ Auto-proposals generated when needed
- ✅ Trends detected correctly (>80% accuracy)

### Performance
- Insight generation: < 10 seconds
- No impact on existing systems

### Quality
- Insights are actionable
- Proposals are relevant
- No false positives (>90% accuracy)

---

## HTML Dashboard (Simple)

**Purpose:** Simple HTML dashboard based on existing HTML templates.

**Approach:**
- Modify existing HTML dashboard (if available)
- Or create simple static HTML with embedded data
- Auto-refresh: Every 5 minutes (via meta refresh or simple JS)
- Show: Current metrics, trends, health score, recommendations

**Output:**
- `g/reports/dashboard/index.html`
- Accessible via: `ops.theedges.work` or `dashboard.theedges.work`

**Features:**
- Current health score
- Trend indicators (up/down/stable)
- Recent anomalies
- Top recommendations
- Last updated timestamp

**No complex real-time updates, just simple periodic refresh.**

---

## What We're NOT Building (Yet)

**Explicitly excluded to avoid over-engineering:**
- ❌ Complex predictive analytics (linear regression, ML)
- ❌ Real-time pub/sub (Redis channels optional)
- ❌ Complex correlation analysis
- ❌ Confidence scoring algorithms
- ❌ Multi-week forecasts

**Rationale:** Start simple, prove value, add complexity only when needed.

---

## Rollout Strategy

### Week 1: Adaptive Collector + Dashboard
- Build collector
- Test trend detection
- Integrate with daily digest
- Create/modify HTML dashboard

### Week 2: Auto-Proposals
- Build proposal generator
- Test with real metrics
- Monitor proposal quality

**Total: 2 weeks (not 4)**

---

## Dependencies

### External
- Redis (for current metrics)
- jq (for JSON processing)
- bc (for simple math)

### Internal
- Phase 5 metrics collection
- Daily digest generator
- R&D proposal system

**No new dependencies.**

---

## Risk Assessment

### Low Risk
- Simple trend detection (proven approach)
- Read-only analysis (doesn't change system)
- Auto-proposals go through existing R&D gate

### Mitigation
- Start with conservative thresholds
- Monitor proposal quality
- Easy to disable if issues

---

## References

- **Phase 5 SPEC:** `g/reports/feature_phase5_governance_reporting_SPEC.md`
- **System Status:** `g/reports/SYSTEM_STATUS_phase5_20251112.md`
- **Daily Digest:** `tools/memory_daily_digest.zsh`
