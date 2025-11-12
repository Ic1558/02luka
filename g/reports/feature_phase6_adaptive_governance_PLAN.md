# Feature PLAN: Phase 6 - Adaptive Governance & Predictive Analytics

**Feature ID:** `phase6_adaptive_governance`  
**Version:** 1.0.0  
**Date:** 2025-11-12  
**Status:** Ready for Development

---

## Task Breakdown

### Phase 6.1: Foundation - Adaptive Collector (Week 1)

- [ ] **Task 1.1:** Create adaptive collector script
  - Create `tools/adaptive_collector.zsh`
  - Read metrics from Redis (claude, rnd, mary)
  - Calculate trend slopes (7-day, 30-day windows)
  - Detect anomalies using Z-score
  - Generate insights JSON

- [ ] **Task 1.2:** Create insights data structure
  - Create `mls/adaptive/` directory
  - Define insights JSON schema
  - Create sample insights file

- [ ] **Task 1.3:** Integrate with daily digest
  - Modify `tools/memory_daily_digest.zsh`
  - Add "Adaptive Insights" section
  - Read from `mls/adaptive/insights_YYYYMMDD.json`

- [ ] **Task 1.4:** Create LaunchAgent for collector
  - Create `com.02luka.adaptive.collector.daily.plist`
  - Schedule: Daily 06:30
  - Load and test

- [ ] **Task 1.5:** Phase 6.1 acceptance tests
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

### Phase 6.2: Predictions - Predictive Analytics (Week 2)

- [ ] **Task 2.1:** Create predictive analytics engine
  - Create `tools/predictive_analytics.zsh`
  - Implement linear regression for trend prediction
  - Calculate 7-day and 30-day forecasts
  - Generate confidence scores

- [ ] **Task 2.2:** Risk assessment system
  - Identify metrics approaching thresholds
  - Calculate days until threshold breach
  - Generate risk alerts
  - Publish to `governance:risk` channel

- [ ] **Task 2.3:** Create predictions data structure
  - Define predictions JSON schema
  - Create `mls/adaptive/predictions_YYYYMMDD.json`
  - Include uncertainty ranges

- [ ] **Task 2.4:** Integrate predictions into daily digest
  - Add "Predictions" subsection to adaptive insights
  - Show 7-day and 30-day forecasts
  - Include risk warnings

- [ ] **Task 2.5:** Create LaunchAgent for analytics
  - Create `com.02luka.predictive.analytics.daily.plist`
  - Schedule: Daily 07:00
  - Load and test

- [ ] **Task 2.6:** Phase 6.2 acceptance tests
  - Create `tools/phase6_2_acceptance.zsh`
  - Test prediction generation
  - Test risk assessment
  - Test accuracy tracking

**Deliverables:**
- `tools/predictive_analytics.zsh`
- `mls/adaptive/predictions_YYYYMMDD.json` (daily)
- Enhanced daily digest with predictions
- LaunchAgent: `com.02luka.predictive.analytics.daily`

---

### Phase 6.3: Dashboard - HTML Dashboard (Week 3)

- [ ] **Task 3.1:** Create dashboard generator script
  - Create `tools/dashboard_generator.zsh`
  - Read metrics from Redis
  - Generate HTML with Chart.js
  - Include real-time data

- [ ] **Task 3.2:** Dashboard components
  - Health score indicator
  - Trend charts (7-day, 30-day)
  - Agent status table
  - Predictive insights panel
  - Action items list

- [ ] **Task 3.3:** Real-time updates
  - Implement auto-refresh (60 seconds)
  - Show data freshness timestamp
  - Handle Redis connection errors gracefully

- [ ] **Task 3.4:** Web server integration
  - Create `g/reports/dashboard/` directory
  - Generate `index.html`
  - Configure web server (ops.theedges.work or dashboard.theedges.work)

- [ ] **Task 3.5:** Create LaunchAgent for dashboard
  - Create `com.02luka.dashboard.generator.plist`
  - Schedule: Every 5 minutes
  - Load and test

- [ ] **Task 3.6:** Phase 6.3 acceptance tests
  - Create `tools/phase6_3_acceptance.zsh`
  - Test dashboard generation
  - Test HTML validity
  - Test chart rendering

**Deliverables:**
- `tools/dashboard_generator.zsh`
- `g/reports/dashboard/index.html` (auto-updated)
- LaunchAgent: `com.02luka.dashboard.generator`
- Web server configuration

---

### Phase 6.4: Auto-Improvement - Closed Loop (Week 4)

- [ ] **Task 4.1:** Create auto-improvement loop script
  - Create `tools/auto_improvement_loop.zsh`
  - Read adaptive insights
  - Identify improvement opportunities
  - Generate R&D proposals

- [ ] **Task 4.2:** Proposal generation logic
  - Only generate for low-risk changes
  - Include risk assessment in proposal
  - Set confidence scores based on insights
  - Submit to `bridge/inbox/RND/`

- [ ] **Task 4.3:** Outcome tracking
  - Track proposal outcomes
  - Learn from results
  - Update confidence scores
  - Record in MLS

- [ ] **Task 4.4:** Safety mechanisms
  - Require human approval for high-risk proposals
  - Rate limiting (max proposals per day)
  - Deduplication (avoid duplicate proposals)

- [ ] **Task 4.5:** Create LaunchAgent for loop
  - Create `com.02luka.auto.improvement.loop.plist`
  - Schedule: Every 30 minutes
  - Load and test

- [ ] **Task 4.6:** Phase 6.4 acceptance tests
  - Create `tools/phase6_4_acceptance.zsh`
  - Test proposal generation
  - Test outcome tracking
  - Test safety mechanisms

**Deliverables:**
- `tools/auto_improvement_loop.zsh`
- R&D proposal generation
- Outcome tracking system
- LaunchAgent: `com.02luka.auto.improvement.loop`

---

## Test Strategy

### Unit Tests

**Adaptive Collector:**
```bash
# Test trend calculation
tools/adaptive_collector.zsh
jq '.trends.claude_hook_success.direction' mls/adaptive/insights_*.json

# Test anomaly detection
# Simulate metric spike, verify detection
```

**Predictive Analytics:**
```bash
# Test prediction generation
tools/predictive_analytics.zsh
jq '.predictions[0].forecast_7d' mls/adaptive/predictions_*.json

# Test risk assessment
# Verify risk alerts generated
```

**Dashboard Generator:**
```bash
# Test HTML generation
tools/dashboard_generator.zsh
# Verify index.html exists and valid
# Test chart.js integration
```

**Auto-Improvement Loop:**
```bash
# Test proposal generation
tools/auto_improvement_loop.zsh
# Verify R&D proposal created
# Test safety mechanisms
```

### Integration Tests

**End-to-End Flow:**
```bash
# 1. Collect metrics
tools/claude_tools/metrics_collector.zsh
tools/mary_memory_hook.zsh
tools/rnd_memory_hook.zsh

# 2. Generate insights
tools/adaptive_collector.zsh

# 3. Generate predictions
tools/predictive_analytics.zsh

# 4. Generate dashboard
tools/dashboard_generator.zsh

# 5. Check daily digest
tools/memory_daily_digest.zsh
grep "Adaptive Insights" g/reports/memory_digest_*.md
```

### Acceptance Tests

**Phase 6.1:**
- Adaptive insights generated daily
- Daily digest includes adaptive insights section
- LaunchAgent runs on schedule

**Phase 6.2:**
- Predictions generated with >70% confidence
- Risk alerts published to Redis
- Daily digest includes predictions

**Phase 6.3:**
- Dashboard HTML generated and valid
- Charts render correctly
- Real-time updates working

**Phase 6.4:**
- Auto-proposals generated for low-risk changes
- Outcomes tracked and learned
- Safety mechanisms working

---

## Deployment Checklist

### Phase 6.1 Deployment

- [ ] **Pre-Deployment:**
  - [ ] Verify Phase 5 operational
  - [ ] Verify Redis connectivity
  - [ ] Check metrics collection working

- [ ] **Deployment:**
  - [ ] Deploy adaptive collector
  - [ ] Create insights directory
  - [ ] Modify daily digest
  - [ ] Create LaunchAgent
  - [ ] Load LaunchAgent
  - [ ] Run Phase 6.1 acceptance tests

- [ ] **Post-Deployment:**
  - [ ] Verify insights generated
  - [ ] Verify daily digest includes insights
  - [ ] Monitor for 24 hours

### Phase 6.2 Deployment

- [ ] **Pre-Deployment:**
  - [ ] Verify Phase 6.1 operational
  - [ ] Verify insights generation working

- [ ] **Deployment:**
  - [ ] Deploy predictive analytics
  - [ ] Create predictions directory
  - [ ] Integrate with daily digest
  - [ ] Create LaunchAgent
  - [ ] Load LaunchAgent
  - [ ] Run Phase 6.2 acceptance tests

- [ ] **Post-Deployment:**
  - [ ] Verify predictions generated
  - [ ] Verify risk alerts working
  - [ ] Monitor prediction accuracy

### Phase 6.3 Deployment

- [ ] **Pre-Deployment:**
  - [ ] Verify Phase 6.2 operational
  - [ ] Verify web server access

- [ ] **Deployment:**
  - [ ] Deploy dashboard generator
  - [ ] Create dashboard directory
  - [ ] Configure web server
  - [ ] Create LaunchAgent
  - [ ] Load LaunchAgent
  - [ ] Run Phase 6.3 acceptance tests

- [ ] **Post-Deployment:**
  - [ ] Verify dashboard accessible
  - [ ] Verify charts rendering
  - [ ] Verify real-time updates

### Phase 6.4 Deployment

- [ ] **Pre-Deployment:**
  - [ ] Verify Phase 6.3 operational
  - [ ] Verify R&D system ready

- [ ] **Deployment:**
  - [ ] Deploy auto-improvement loop
  - [ ] Configure safety mechanisms
  - [ ] Create LaunchAgent
  - [ ] Load LaunchAgent
  - [ ] Run Phase 6.4 acceptance tests

- [ ] **Post-Deployment:**
  - [ ] Verify proposals generated
  - [ ] Verify outcome tracking
  - [ ] Monitor for 1 week

---

## Rollback Plan

### Phase 6.1 Rollback
```bash
# Unload LaunchAgent
launchctl unload ~/Library/LaunchAgents/com.02luka.adaptive.collector.daily.plist

# Revert daily digest
git checkout HEAD~1 tools/memory_daily_digest.zsh

# Keep insights files for audit
```

### Phase 6.2 Rollback
```bash
# Unload LaunchAgent
launchctl unload ~/Library/LaunchAgents/com.02luka.predictive.analytics.daily.plist

# Revert daily digest changes
git checkout HEAD~1 tools/memory_daily_digest.zsh

# Keep predictions files for audit
```

### Phase 6.3 Rollback
```bash
# Unload LaunchAgent
launchctl unload ~/Library/LaunchAgents/com.02luka.dashboard.generator.plist

# Remove dashboard directory
rm -rf g/reports/dashboard/

# Revert web server config
```

### Phase 6.4 Rollback
```bash
# Unload LaunchAgent
launchctl unload ~/Library/LaunchAgents/com.02luka.auto.improvement.loop.plist

# Disable auto-proposal generation
# (Keep script but don't run)
```

---

## Success Metrics

### Phase 6.1
- Insights generated daily: 100%
- Daily digest includes insights: 100%
- Trend detection accuracy: >80%

### Phase 6.2
- Predictions generated daily: 100%
- Prediction accuracy (7-day): >70%
- Risk alerts timely: <5 minute latency

### Phase 6.3
- Dashboard accessible: 100% uptime
- Dashboard load time: <2 seconds
- Real-time updates: <5 second latency

### Phase 6.4
- Auto-proposals generated: As needed
- Proposal acceptance rate: >60%
- Outcome learning: Confidence scores updated

---

## Timeline

- **Week 1:** Phase 6.1 - Foundation (Adaptive Collector)
- **Week 2:** Phase 6.2 - Predictions (Predictive Analytics)
- **Week 3:** Phase 6.3 - Dashboard (HTML Dashboard)
- **Week 4:** Phase 6.4 - Auto-Improvement (Closed Loop)

**Total:** 4 weeks for complete Phase 6 deployment

---

## Dependencies

### External
- Redis (for metrics and pub/sub)
- Chart.js (for dashboard)
- Web server (for dashboard access)
- jq, bc (for calculations)

### Internal
- Phase 5 governance system
- R&D proposal system
- Mary dispatcher
- Claude Code metrics
- Daily digest generator

---

## Risk Assessment

### High Risk
- **Prediction Accuracy:** Low accuracy could lead to false alarms
  - **Mitigation:** Start with conservative confidence thresholds, improve over time

### Medium Risk
- **Auto-Proposal Generation:** Could generate too many proposals
  - **Mitigation:** Rate limiting and deduplication

### Low Risk
- **Dashboard Performance:** High load could slow dashboard
  - **Mitigation:** Caching and optimization

---

## References

- **SPEC:** `g/reports/feature_phase6_adaptive_governance_SPEC.md`
- **Phase 5 SPEC:** `g/reports/feature_phase5_governance_reporting_SPEC.md`
- **System Status:** `g/reports/SYSTEM_STATUS_phase5_20251112.md`

