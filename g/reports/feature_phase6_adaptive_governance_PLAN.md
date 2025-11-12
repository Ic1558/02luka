# Feature PLAN: Phase 6 - Adaptive Governance (Simplified)

**Feature ID:** `phase6_adaptive_governance`  
**Version:** 1.1.0 (Simplified)  
**Date:** 2025-11-12  
**Status:** Ready for Development

---

## Task Breakdown (Simplified)

### Week 1: Adaptive Collector + Daily Digest Integration

- [ ] **Task 1.1:** Create adaptive collector script
  - Create `tools/adaptive_collector.zsh`
  - Read last 7 days from monthly metrics JSON
  - Calculate simple trends (compare averages)
  - Detect anomalies (2x or 0.5x threshold)
  - Write insights JSON

- [ ] **Task 1.2:** Create insights directory and structure
  - Create `mls/adaptive/` directory
  - Define simple JSON schema
  - Test with sample data

- [ ] **Task 1.3:** Integrate with daily digest
  - Modify `tools/memory_daily_digest.zsh`
  - Add "Adaptive Insights" section
  - Read from `mls/adaptive/insights_YYYYMMDD.json`
  - Handle missing insights gracefully

- [ ] **Task 1.4:** Create LaunchAgent
  - Create `com.02luka.adaptive.collector.daily.plist`
  - Schedule: Daily 06:30
  - Load and test

- [ ] **Task 1.5:** Week 1 acceptance tests
  - Create `tools/phase6_1_acceptance.zsh`
  - Test collector execution
  - Test insights generation
  - Test daily digest integration

**Deliverables:**
- `tools/adaptive_collector.zsh`
- `mls/adaptive/insights_YYYYMMDD.json` (daily)
- Enhanced `tools/memory_daily_digest.zsh`
- LaunchAgent: `com.02luka.adaptive.collector.daily`

---

### Week 2: Auto-Proposal Generator

- [ ] **Task 2.1:** Create proposal generator script
  - Create `tools/adaptive_proposal_gen.zsh`
  - Read insights JSON
  - Identify improvement opportunities
  - Generate R&D proposal YAML

- [ ] **Task 2.2:** Proposal generation logic
  - Only for declining metrics (3+ days)
  - Only for metrics below threshold
  - Only for low-risk changes
  - Include context and suggestion

- [ ] **Task 2.3:** Safety mechanisms
  - Max 1 proposal per day
  - Deduplication (check existing proposals)
  - Rate limiting

- [ ] **Task 2.4:** Create LaunchAgent
  - Create `com.02luka.adaptive.proposal.gen.plist`
  - Schedule: Daily 07:00
  - Load and test

- [ ] **Task 2.5:** Week 2 acceptance tests
  - Create `tools/phase6_2_acceptance.zsh`
  - Test proposal generation
  - Test safety mechanisms
  - Test R&D integration

**Deliverables:**
- `tools/adaptive_proposal_gen.zsh`
- R&D proposals in `bridge/inbox/RND/`
- LaunchAgent: `com.02luka.adaptive.proposal.gen`

---

## Test Strategy (Simplified)

### Unit Tests

**Adaptive Collector:**
```bash
# Test trend calculation
tools/adaptive_collector.zsh
jq '.trends.claude_hook_success.direction' mls/adaptive/insights_*.json
# Expected: "improving", "declining", or "stable"

# Test anomaly detection
# Create test data with spike, verify detection
```

**Proposal Generator:**
```bash
# Test proposal generation
tools/adaptive_proposal_gen.zsh
# Verify R&D proposal created in bridge/inbox/RND/
# Verify proposal format is valid
```

### Integration Tests

**End-to-End:**
```bash
# 1. Generate insights
tools/adaptive_collector.zsh

# 2. Check daily digest includes insights
tools/memory_daily_digest.zsh
grep "Adaptive Insights" g/reports/memory_digest_*.md

# 3. Generate proposal (if conditions met)
tools/adaptive_proposal_gen.zsh
ls bridge/inbox/RND/RND-ADAPTIVE-*.yaml
```

**Simple, focused tests.**

---

## Deployment Checklist

### Week 1 Deployment

- [ ] **Pre-Deployment:**
  - [ ] Verify Phase 5 operational
  - [ ] Verify monthly metrics exist
  - [ ] Check daily digest working

- [ ] **Deployment:**
  - [ ] Deploy adaptive collector
  - [ ] Create insights directory
  - [ ] Modify daily digest
  - [ ] Create LaunchAgent
  - [ ] Load LaunchAgent
  - [ ] Run Week 1 acceptance tests

- [ ] **Post-Deployment:**
  - [ ] Verify insights generated
  - [ ] Verify daily digest includes insights
  - [ ] Monitor for 3 days

### Week 2 Deployment

- [ ] **Pre-Deployment:**
  - [ ] Verify Week 1 operational
  - [ ] Verify insights generation working

- [ ] **Deployment:**
  - [ ] Deploy proposal generator
  - [ ] Configure safety mechanisms
  - [ ] Create LaunchAgent
  - [ ] Load LaunchAgent
  - [ ] Run Week 2 acceptance tests

- [ ] **Post-Deployment:**
  - [ ] Verify proposals generated (if conditions met)
  - [ ] Monitor proposal quality
  - [ ] Monitor for 1 week

---

## Rollback Plan

### Week 1 Rollback
```bash
# Unload LaunchAgent
launchctl unload ~/Library/LaunchAgents/com.02luka.adaptive.collector.daily.plist

# Revert daily digest
git checkout HEAD~1 tools/memory_daily_digest.zsh

# Keep insights files for audit
```

### Week 2 Rollback
```bash
# Unload LaunchAgent
launchctl unload ~/Library/LaunchAgents/com.02luka.adaptive.proposal.gen.plist

# Disable proposal generation
# (Keep script but don't run)
```

**Simple, straightforward rollback.**

---

## Success Metrics

### Week 1
- Insights generated daily: 100%
- Daily digest includes insights: 100%
- Trend detection accuracy: >80%

### Week 2
- Proposals generated when needed: 100%
- Proposal relevance: >90%
- No false positives: >95%

**Measurable, achievable goals.**

---

## Timeline

- **Week 1:** Adaptive Collector + Daily Digest Integration
- **Week 2:** Auto-Proposal Generator

**Total: 2 weeks (not 4)**

**Rationale:** Focus on core value, add complexity only when needed.

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

## What We're NOT Building (Yet)

**Explicitly excluded:**
- ❌ Complex predictive analytics
- ❌ HTML dashboard
- ❌ Real-time pub/sub
- ❌ Complex correlation analysis
- ❌ Confidence scoring
- ❌ Multi-week forecasts

**Rationale:** Start simple, prove value, add complexity only when needed.

---

## References

- **SPEC:** `g/reports/feature_phase6_adaptive_governance_SPEC.md`
- **Phase 5 SPEC:** `g/reports/feature_phase5_governance_reporting_SPEC.md`
- **System Status:** `g/reports/SYSTEM_STATUS_phase5_20251112.md`
