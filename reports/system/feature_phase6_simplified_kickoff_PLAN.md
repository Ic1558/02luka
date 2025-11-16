# Feature PLAN: Phase 6 Simplified - Kickoff & Activation

**Feature ID:** `phase6_simplified_kickoff`  
**Version:** 1.0.0  
**Date:** 2025-11-12  
**Status:** Ready for Execution  
**Parent:** `phase6_adaptive_governance`

---

## Objective

Activate Phase 6 Simplified components (adaptive collector + proposal generator) with integration to weekly recap and optional JSON index. Complete existing TODOs and deploy in one atomic operation.

---

## Context

**Existing Components:**
- ✅ `tools/adaptive_collector.zsh` - Exists but incomplete (TODOs)
- ✅ `tools/adaptive_proposal_gen.zsh` - Exists but incomplete (TODOs)
- ✅ `g/reports/feature_phase6_adaptive_governance_SPEC.md` - Complete
- ✅ `g/reports/feature_phase6_adaptive_governance_PLAN.md` - Complete
- ✅ `g/reports/dashboard/index.html` - Exists

**New Requirements:**
- Complete adaptive collector (implement trend calculation)
- Complete proposal generator (add sample count guard)
- Integrate with weekly recap
- Add optional JSON index for agents
- Create deployment script (similar to Phase 5/6.1)

---

## Task Breakdown

### Phase 1: Complete Adaptive Collector (30 min)

- [ ] **Task 1.1:** Implement trend calculation from historical data
  - Read last 7 days from monthly metrics JSON
  - Compare with previous 7 days
  - Calculate averages and trends
  - Handle missing data gracefully

- [ ] **Task 1.2:** Implement anomaly detection
  - Detect values >2x or <0.5x average
  - Mark severity (low/medium/high)
  - Generate recommendations

- [ ] **Task 1.3:** Test with real data
  - Run on existing metrics
  - Verify JSON output structure
  - Check edge cases (no data, single data point)

**Deliverables:**
- `tools/adaptive_collector.zsh` (complete, no TODOs)
- `mls/adaptive/insights_YYYYMMDD.json` (sample output)

---

### Phase 2: Complete Proposal Generator (20 min)

- [ ] **Task 2.1:** Add sample count guard
  - **Counting rule:** Require ≥3 days with valid data points (not just 3 data points total)
  - Check historical data availability in monthly metrics JSON
  - Count days where metric has valid value (non-null, non-zero)
  - Skip proposal generation if < 3 days of data available
  - This prevents false positives from insufficient historical context

- [ ] **Task 2.2:** Improve proposal quality
  - Add specific metric context
  - Include trend duration (e.g., "declining for 3 days")
  - Add actionable suggestions

- [ ] **Task 2.3:** Test proposal generation
  - Test with declining metric
  - Test with anomaly
  - Test with insufficient data (should skip)

**Deliverables:**
- `tools/adaptive_proposal_gen.zsh` (complete, no TODOs)
- Sample R&D proposal in `bridge/inbox/RND/`

---

### Phase 3: Weekly Recap Integration (15 min)

- [ ] **Task 3.1:** Add adaptive insights to weekly recap
  - Read insights from past week (`mls/adaptive/insights_*.json`)
  - Aggregate trends and anomalies across the week
  - Add "Adaptive Insights Summary" section
  - **Placement:** Insert after "System Metrics" section, before "Recommendations" section

- [ ] **Task 3.2:** Update weekly recap generator
  - Modify `tools/weekly_recap_generator.zsh`
  - Add insights aggregation logic (read all insights from week range)
  - Handle missing insights gracefully (skip section if no data)
  - Format: Show aggregated trends, top anomalies, summary recommendations

**Deliverables:**
- Enhanced `tools/weekly_recap_generator.zsh`
- Weekly recap includes adaptive insights

---

### Phase 4: JSON Index (Optional, 15 min)

- [ ] **Task 4.1:** Create index generator script
  - Create `tools/reports_index_generator.zsh`
  - Scan `g/reports/system/` for digests, weekly, certificates
  - Generate `g/reports/system/index.json`

- [ ] **Task 4.2:** Index structure
  ```json
  {
    "generated_at": "2025-11-12T08:00:00Z",
    "latest": {
      "daily_digest": "memory_digest_20251112.md",
      "weekly_recap": "system_governance_WEEKLY_20251112.md",
      "certificate": "phase5_governance/DEPLOYMENT_CERTIFICATE_phase5_6.1_20251112.md"
    },
    "recent": {
      "daily_digests": [...],
      "weekly_recaps": [...],
      "certificates": [
        "phase5_governance/DEPLOYMENT_CERTIFICATE_*.md",
        "phase6_paula/DEPLOYMENT_CERTIFICATE_*.md"
      ]
    }
  }
  ```
  **Note:** Certificate paths should auto-detect from `phase5_governance/` and `phase6_paula/` subdirectories.

- [ ] **Task 4.3:** Integrate with LaunchAgent
  - Update weekly LaunchAgent to regenerate index
  - Or create separate daily index job

**Deliverables:**
- `tools/reports_index_generator.zsh`
- `g/reports/system/index.json` (auto-generated)

---

### Phase 5: LaunchAgents (10 min)

- [ ] **Task 5.1:** Create adaptive collector LaunchAgent
  - `LaunchAgents/com.02luka.adaptive.collector.daily.plist`
  - **Schedule:** Daily 06:45 (after metrics collection completes)
  - **Dependency check:** Verify `memory_metrics_collector.zsh` runs before this (typically 23:55 or 00:00)
  - Add guard: Check if metrics file exists before running
  - Load and verify

- [ ] **Task 5.2:** Create proposal generator LaunchAgent
  - `LaunchAgents/com.02luka.adaptive.proposal.gen.plist`
  - Schedule: Daily 07:00 (after collector)
  - Load and verify

**Deliverables:**
- 2 LaunchAgent plists
- Both loaded and scheduled

---

### Phase 6: Deployment Script (20 min)

- [ ] **Task 6.1:** Create activation script
  - `tools/activate_phase6_simplified.zsh`
  - Similar to `commit_and_activate_phase5_6_1.zsh`
  - Stages all Phase 6 files
  - Commits with proper message
  - Loads LaunchAgents
  - Runs smoke tests

- [ ] **Task 6.2:** Create acceptance test
  - `tools/phase6_simplified_acceptance.zsh`
  - Test collector execution
  - Test proposal generation (if applicable)
  - Test weekly recap integration
  - Test LaunchAgents loaded

**Deliverables:**
- `tools/activate_phase6_simplified.zsh`
- `tools/phase6_simplified_acceptance.zsh`

---

### Phase 7: Documentation & Verification (10 min)

- [ ] **Task 7.1:** Update deployment certificate
  - Create `g/reports/phase6_paula/DEPLOYMENT_CERTIFICATE_phase6_simplified_YYYYMMDD.md`
  - Document components activated
  - Include health check results

- [ ] **Task 7.2:** Smoke test everything
  - Run collector manually
  - Check insights JSON generated
  - Run weekly recap (should include insights)
  - Verify LaunchAgents loaded
  - Check index.json (if implemented)

**Deliverables:**
- Deployment certificate
- All smoke tests passing

---

## Test Strategy

### Unit Tests

**Adaptive Collector:**
```bash
# Test trend calculation
tools/adaptive_collector.zsh
jq '.trends' mls/adaptive/insights_*.json
# Expected: JSON with trends object

# Test anomaly detection
# Create test data with spike, verify detection
```

**Proposal Generator:**
```bash
# Test with declining metric
tools/adaptive_proposal_gen.zsh
# Verify proposal created in bridge/inbox/RND/

# Test with insufficient data (should skip)
# Remove insights file, verify graceful skip
```

**Weekly Recap:**
```bash
# Test insights integration
tools/weekly_recap_generator.zsh
grep "Adaptive Insights" g/reports/system/system_governance_WEEKLY_*.md
# Expected: Section present
```

### Integration Tests

**End-to-End:**
```bash
# 1. Run collector
tools/adaptive_collector.zsh

# 2. Check insights generated
ls -lh mls/adaptive/insights_*.json

# 3. Run proposal generator (if applicable)
tools/adaptive_proposal_gen.zsh

# 4. Run weekly recap
tools/weekly_recap_generator.zsh

# 5. Verify all components working
tools/phase6_simplified_acceptance.zsh
```

### Acceptance Criteria

- ✅ Adaptive collector generates insights daily
- ✅ Proposal generator creates proposals when needed (≥3 days of data)
- ✅ Weekly recap includes adaptive insights (after "System Metrics" section)
- ✅ LaunchAgents loaded and scheduled (collector at 06:45, proposal gen at 07:00)
- ✅ All smoke tests passing
- ✅ No TODOs in code
- ✅ Metrics collection verified to run before adaptive collector

---

## Timeline

**Total Estimated Time:** ~2 hours

- Phase 1: 30 min (Complete collector)
- Phase 2: 20 min (Complete proposal generator)
- Phase 3: 15 min (Weekly recap integration)
- Phase 4: 15 min (JSON index - optional)
- Phase 5: 10 min (LaunchAgents)
- Phase 6: 20 min (Deployment script)
- Phase 7: 10 min (Documentation)

**Can be done in one session or split across 2 sessions.**

---

## Dependencies

**Required:**
- Phase 5 metrics collection working
- Monthly metrics JSON files exist
- Redis accessible
- Weekly recap generator working

**Optional:**
- Dashboard HTML (for future enhancement)

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Insufficient historical data | Graceful degradation (mark as stable) |
| False positives in proposals | Require ≥3 samples, human approval |
| Performance impact | Run after metrics collection (off-peak) |
| LaunchAgent conflicts | Check existing agents before loading |

---

## Success Metrics

**Functional:**
- Insights generated daily (≥90% success rate)
- Proposals generated when needed (≥80% accuracy)
- Weekly recap includes insights (100% when data available)

**Performance:**
- Collector runs in <10 seconds
- No impact on existing systems
- LaunchAgents stable (no crashes)

**Quality:**
- No false positives in proposals (>90% accuracy)
- Insights are actionable
- All TODOs resolved

---

## Next Steps After Activation

1. **Monitor first week:**
   - Check insights quality
   - Verify proposal accuracy
   - Review weekly recap integration

2. **Iterate based on feedback:**
   - Adjust thresholds if needed
   - Add more metrics if useful
   - Enhance proposal quality

3. **Optional enhancements:**
   - Add more sophisticated trend detection
   - Create HTML dashboard with insights
   - Add alerting for critical anomalies

---

**Plan Created:** 2025-11-12T15:45:00Z  
**Author:** CLS (Cognitive Local System Orchestrator)  
**Status:** Ready for Execution
