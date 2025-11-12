# Feature PLAN: Phase 5 - Governance & Reporting Layer

**Feature ID:** `phase5_governance_reporting`  
**Version:** 1.0.0  
**Date:** 2025-11-12  
**Status:** Ready for Implementation

---

## Task Breakdown

### Phase 5: Governance & Reporting ✅

- [x] **Task 1:** Create metrics collector
  - `tools/memory_metrics_collector.zsh`
  - Aggregate Redis events daily
  - Generate monthly metrics JSON/MD
  - LaunchAgent: `com.02luka.memory.metrics.collector` (23:55)

- [x] **Task 2:** Create governance report generator
  - `tools/governance_report_generator.zsh`
  - Combine metrics + health + digest + certificates
  - Generate weekly Markdown report
  - LaunchAgent: `com.02luka.governance.report.weekly` (Sunday 08:00)

- [x] **Task 3:** Create auto-alert hook
  - `tools/governance_alert_hook.zsh`
  - Telegram alerts for health < 80%, missing digest, etc.
  - Deduplication logic
  - LaunchAgent: `com.02luka.governance.alerts` (every 15 minutes)

- [x] **Task 4:** Create certificate validator
  - `tools/certificate_validator.zsh`
  - Validate deployment certificates
  - Check component existence
  - LaunchAgent: `com.02luka.certificate.validator` (06:00)

- [x] **Task 5:** Create self-auditing system
  - `tools/governance_self_audit.zsh`
  - Compliance checks
  - Audit report generation
  - LaunchAgent: `com.02luka.governance.audit` (05:00)

- [x] **Task 6:** Update health check
  - Add governance checks to `memory_hub_health.zsh`
  - Include certificate validation status
  - Include audit compliance score

- [x] **Task 7:** Create acceptance tests
  - `tools/phase5_acceptance.zsh`
  - Test all Phase 5 components
  - Verify reports generated
  - Verify alerts working

---

## Test Strategy

### Unit Tests

**Test 1: Metrics Collector**
```bash
tools/memory_metrics_collector.zsh
# Expected: Monthly metrics JSON/MD generated
```

**Test 2: Governance Report**
```bash
tools/governance_report_generator.zsh
# Expected: Weekly report generated
```

**Test 3: Auto-Alert Hook**
```bash
# Simulate low health
GOVERNANCE_HEALTH_THRESHOLD=100 tools/governance_alert_hook.zsh
# Expected: Telegram alert sent
```

**Test 4: Certificate Validator**
```bash
tools/certificate_validator.zsh
# Expected: Validation report generated
```

**Test 5: Self-Audit**
```bash
tools/governance_self_audit.zsh
# Expected: Audit report generated, compliance score > 90%
```

### Integration Tests

**Test 1: End-to-End Weekly Cycle**
```bash
# Run metrics collector
tools/memory_metrics_collector.zsh

# Generate governance report
tools/governance_report_generator.zsh

# Verify report exists and contains expected sections
# Expected: Report generated with all sections
```

**Test 2: Alert Integration**
```bash
# Trigger alert condition
# Verify Telegram alert sent
# Verify deduplication works
# Expected: Alert sent once, not duplicated
```

**Test 3: Certificate Validation**
```bash
# Run validator
tools/certificate_validator.zsh

# Verify validation report
# Expected: All certificates valid
```

---

## Deployment Checklist

- [x] **Pre-Deployment:**
  - [x] Verify Phase 4 components operational
  - [x] Verify Telegram credentials available
  - [x] Verify Redis connectivity
  - [x] Check existing reports structure

- [x] **Deployment:**
  - [x] Create metrics collector script
  - [x] Create governance report generator
  - [x] Create auto-alert hook
  - [x] Create certificate validator
  - [x] Create self-auditing system
  - [x] Create LaunchAgents (5 total)
  - [x] Update health check
  - [x] Create acceptance tests
  - [x] Load all LaunchAgents

- [x] **Post-Deployment:**
  - [x] Run acceptance tests
  - [x] Verify metrics collection
  - [x] Verify report generation
  - [x] Test alert functionality
  - [x] Verify certificate validation
  - [x] Run self-audit

---

## Rollback Plan

### Immediate Rollback
```bash
# Unload LaunchAgents
launchctl unload ~/Library/LaunchAgents/com.02luka.memory.metrics.collector.plist
launchctl unload ~/Library/LaunchAgents/com.02luka.governance.report.weekly.plist
launchctl unload ~/Library/LaunchAgents/com.02luka.governance.alerts.plist
launchctl unload ~/Library/LaunchAgents/com.02luka.certificate.validator.plist
launchctl unload ~/Library/LaunchAgents/com.02luka.governance.audit.plist

# Remove scripts (optional)
rm -f ~/02luka/tools/memory_metrics_collector.zsh
rm -f ~/02luka/tools/governance_report_generator.zsh
rm -f ~/02luka/tools/governance_alert_hook.zsh
rm -f ~/02luka/tools/certificate_validator.zsh
rm -f ~/02luka/tools/governance_self_audit.zsh

# Preserve data
# (keep existing reports and metrics)
```

---

## Acceptance Criteria

✅ **Functional:**
- Metrics collector aggregates data daily
- Governance report generates weekly
- Auto-alert sends notifications
- Certificate validator checks certificates
- Self-audit runs daily

✅ **Operational:**
- All LaunchAgents loaded
- Reports generated on schedule
- Alerts working correctly
- Compliance score > 90%

✅ **Quality:**
- Reports clear and actionable
- Alerts timely and relevant
- Metrics accurate
- Validation comprehensive

---

## Timeline

- **Implementation:** ~2 hours
- **Testing:** ~1 hour
- **Documentation:** ~30 minutes

**Total:** ~3.5 hours

---

## Success Metrics

1. **Metrics:** Daily collection working
2. **Reports:** Weekly reports generated
3. **Alerts:** Notifications sent correctly
4. **Validation:** Certificates validated
5. **Compliance:** Audit score > 90%

---

## Dependencies

- **Phase 4:** Must be operational
- **Telegram:** Credentials required for alerts
- **Redis:** Must be running
- **Health Check:** Must be working

---

## References

- **SPEC:** `g/reports/feature_phase5_governance_reporting_SPEC.md`
- **Phase 4 SPEC:** `g/reports/feature_shared_memory_phase4_redis_hub_SPEC.md`
- **Phase 4 Operational:** `g/reports/feature_phase4_operational_tools_SPEC.md`
