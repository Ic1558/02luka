# Feature PLAN: Claude Code Governance Integration - Phased Deployment

**Feature ID:** `claude_code_governance_phased`  
**Version:** 1.0.0  
**Date:** 2025-11-12  
**Status:** Ready for Phased Deployment

---

## Task Breakdown by Phase

### Phase 1: Redis + Metrics Integration ✅

- [x] **Task 1.1:** Deploy Claude Code metrics collector
  - Verify `tools/claude_tools/metrics_collector.zsh` exists
  - Test Redis integration
  - Verify data in `memory:agents:claude`

- [x] **Task 1.2:** Integrate into Phase 5 metrics collector
  - Verify `tools/memory_metrics_collector.zsh` includes Claude Code
  - Test monthly aggregation
  - Verify output JSON includes Claude Code

- [x] **Task 1.3:** Create LaunchAgent for metrics collection
  - Verify `com.02luka.claude.metrics.collector` loaded
  - Test scheduled execution (23:55)
  - Verify logs

- [x] **Task 1.4:** Phase 1 acceptance tests
  - Create `tools/phase1_claude_metrics_acceptance.zsh`
  - Test metrics collection
  - Test Redis integration
  - Test monthly aggregation

**Deployment Script:** `tools/deploy_phase1_claude_metrics.zsh`

---

### Phase 2: Health + Alert Integration ✅

- [x] **Task 2.1:** Add Claude Code to unified health check
  - Verify `tools/memory_hub_health.zsh` includes Claude Code
  - Test health score calculation
  - Verify dependency checks

- [x] **Task 2.2:** Integrate Claude Code alerts
  - Verify `tools/governance_alert_hook.zsh` includes Claude Code
  - Test alert triggers (hook failure > 20%, conflicts > 10%)
  - Test Telegram notifications

- [x] **Task 2.3:** Deploy dependency management
  - Verify `tools/claude_hooks/setup_dependencies.zsh` exists
  - Test dependency verification
  - Test automatic installation

- [x] **Task 2.4:** Create LaunchAgent for alerts
  - Create `com.02luka.governance.alerts` (every 15 minutes)
  - Test alert execution
  - Verify deduplication

- [x] **Task 2.5:** Phase 2 acceptance tests
  - Create `tools/phase2_claude_health_alerts_acceptance.zsh`
  - Test health check integration
  - Test alert functionality
  - Test dependency management

**Deployment Script:** `tools/deploy_phase2_claude_health_alerts.zsh`

---

### Phase 3: Report + Certificate + Dependencies ✅

- [x] **Task 3.1:** Add Claude Code to governance report
  - Verify `tools/governance_report_generator.zsh` includes Claude Code
  - Test report generation
  - Verify Claude Code compliance section

- [x] **Task 3.2:** Include Claude Code in certificate validation
  - Verify `tools/certificate_validator.zsh` includes Claude Code
  - Test component validation
  - Verify validation report

- [x] **Task 3.3:** Deploy security checks
  - Verify `tools/claude_hooks/security_check.zsh` exists
  - Test credential scanning
  - Test pattern detection

- [x] **Task 3.4:** Create LaunchAgents for Phase 3
  - Create `com.02luka.governance.report.weekly` (Sunday 08:00)
  - Create `com.02luka.certificate.validator` (daily 06:00)
  - Test scheduled execution

- [x] **Task 3.5:** Phase 3 acceptance tests
  - Create `tools/phase3_claude_reporting_acceptance.zsh`
  - Test report generation
  - Test certificate validation
  - Test security checks

**Deployment Script:** `tools/deploy_phase3_claude_reporting.zsh`

---

## Test Strategy by Phase

### Phase 1 Tests

**Unit Tests:**
```bash
# Test metrics collector
tools/claude_tools/metrics_collector.zsh
redis-cli -a changeme-02luka HGETALL memory:agents:claude

# Test monthly aggregation
tools/memory_metrics_collector.zsh
jq '.agents.claude' g/reports/memory_metrics_YYYYMM.json
```

**Integration Tests:**
```bash
# End-to-end metrics flow
tools/claude_tools/metrics_collector.zsh
sleep 2
tools/memory_metrics_collector.zsh
# Verify data in monthly metrics
```

### Phase 2 Tests

**Unit Tests:**
```bash
# Test health check
tools/memory_hub_health.zsh
# Expected: Claude Code section included

# Test alerts
GOVERNANCE_HEALTH_THRESHOLD=100 tools/governance_alert_hook.zsh
# Expected: Alert sent if health < threshold

# Test dependencies
tools/claude_hooks/setup_dependencies.zsh
# Expected: All dependencies verified/installed
```

**Integration Tests:**
```bash
# Test unified health
tools/memory_hub_health.zsh
# Expected: Overall score includes Claude Code

# Test alert integration
# Simulate low health, verify alert sent
```

### Phase 3 Tests

**Unit Tests:**
```bash
# Test report generation
tools/governance_report_generator.zsh
grep "Claude Code Compliance" g/reports/system_governance_WEEKLY_*.md

# Test certificate validation
tools/certificate_validator.zsh
# Expected: Claude Code components validated

# Test security checks
tools/claude_hooks/security_check.zsh
# Expected: Credential patterns detected
```

**Integration Tests:**
```bash
# Test complete reporting flow
tools/governance_report_generator.zsh
# Verify report includes all sections including Claude Code
```

---

## Deployment Checklist by Phase

### Phase 1 Checklist

- [x] **Pre-Deployment:**
  - [x] Verify Redis running
  - [x] Verify Claude Code components exist
  - [x] Check existing metrics structure

- [x] **Deployment:**
  - [x] Deploy metrics collector
  - [x] Integrate into Phase 5 collector
  - [x] Create LaunchAgent
  - [x] Load LaunchAgent
  - [x] Run Phase 1 acceptance tests

- [x] **Post-Deployment:**
  - [x] Verify metrics in Redis
  - [x] Verify monthly aggregation
  - [x] Monitor for 24 hours
  - [x] Check logs for errors

### Phase 2 Checklist

- [x] **Pre-Deployment:**
  - [x] Verify Phase 1 operational
  - [x] Verify Telegram credentials
  - [x] Check existing health check

- [x] **Deployment:**
  - [x] Update health check
  - [x] Deploy alert hook
  - [x] Deploy dependency management
  - [x] Create LaunchAgents
  - [x] Load LaunchAgents
  - [x] Run Phase 2 acceptance tests

- [x] **Post-Deployment:**
  - [x] Verify health check includes Claude Code
  - [x] Test alert functionality
  - [x] Verify dependencies
  - [x] Monitor alerts for 24 hours

### Phase 3 Checklist

- [x] **Pre-Deployment:**
  - [x] Verify Phase 1 + 2 operational
  - [x] Check existing report structure
  - [x] Verify certificate structure

- [x] **Deployment:**
  - [x] Deploy report generator
  - [x] Deploy certificate validator
  - [x] Deploy security checks
  - [x] Create LaunchAgents
  - [x] Load LaunchAgents
  - [x] Run Phase 3 acceptance tests

- [x] **Post-Deployment:**
  - [x] Verify report generation
  - [x] Verify certificate validation
  - [x] Verify security checks
  - [x] Generate initial reports

---

## Rollback Plan by Phase

### Phase 1 Rollback
```bash
# Unload LaunchAgent
launchctl unload ~/Library/LaunchAgents/com.02luka.claude.metrics.collector.plist

# Remove Redis keys (optional)
redis-cli -a changeme-02luka DEL memory:agents:claude

# Keep metrics files for audit
```

### Phase 2 Rollback
```bash
# Revert health check
git checkout HEAD~1 tools/memory_hub_health.zsh

# Disable alert hook
launchctl unload ~/Library/LaunchAgents/com.02luka.governance.alerts.plist

# Keep dependency script (useful standalone)
```

### Phase 3 Rollback
```bash
# Revert report generator
git checkout HEAD~1 tools/governance_report_generator.zsh

# Revert certificate validator
git checkout HEAD~1 tools/certificate_validator.zsh

# Unload LaunchAgents
launchctl unload ~/Library/LaunchAgents/com.02luka.governance.report.weekly.plist
launchctl unload ~/Library/LaunchAgents/com.02luka.certificate.validator.plist

# Keep security check (useful standalone)
```

---

## Acceptance Criteria by Phase

### Phase 1 Acceptance

✅ **Functional:**
- Metrics collector runs successfully
- Data appears in Redis
- Monthly metrics include Claude Code
- LaunchAgent loaded and running

✅ **Operational:**
- No errors in logs
- Metrics accurate
- Collection on schedule

### Phase 2 Acceptance

✅ **Functional:**
- Health check includes Claude Code
- Alerts sent when thresholds exceeded
- Dependencies verified
- Unified health score calculated

✅ **Operational:**
- Alerts timely
- No false positives
- Dependencies managed

### Phase 3 Acceptance

✅ **Functional:**
- Governance report includes Claude Code
- Certificate validation includes Claude Code
- Security checks working
- Reports generating correctly

✅ **Operational:**
- Reports complete
- Validation accurate
- Security coverage comprehensive

---

## Timeline

- **Phase 1:** 1 day (deploy + 24h monitoring)
- **Phase 2:** 1 day (deploy + 24h monitoring)
- **Phase 3:** 1 day (deploy + verification)

**Total:** 3 days for complete phased rollout

---

## Success Metrics

**Phase 1:**
- Metrics collection: 100% success rate
- Redis integration: < 1 second latency
- Data accuracy: 100%

**Phase 2:**
- Health check: All components included
- Alert accuracy: 100% (no false positives)
- Dependency coverage: 100%

**Phase 3:**
- Report completeness: All sections included
- Validation accuracy: 100%
- Security coverage: All patterns detected

---

## References

- **SPEC:** `g/reports/feature_claude_code_governance_phased_deployment_SPEC.md`
- **Full Integration SPEC:** `g/reports/feature_claude_code_governance_integration_SPEC.md`
- **Phase 5 SPEC:** `g/reports/feature_phase5_governance_reporting_SPEC.md`

