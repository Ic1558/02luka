# Feature PLAN: Claude Code Best Practices - Governance Integration

**Feature ID:** `claude_code_governance_integration`  
**Version:** 1.0.0  
**Date:** 2025-11-12  
**Status:** Ready for Implementation

---

## Task Breakdown

### Claude Code → Phase 5 Integration ✅

- [x] **Task 1:** Add Redis integration to Claude Code metrics collector
  - Modify `tools/claude_tools/metrics_collector.zsh`
  - Write metrics to `memory:agents:claude`
  - Publish updates to `memory:updates` channel
  - Update `shared_memory/context.json`

- [x] **Task 2:** Integrate Claude Code metrics into Phase 5 collector
  - Modify `tools/memory_metrics_collector.zsh`
  - Include Claude Code metrics in monthly aggregation
  - Add to `g/reports/memory_metrics_YYYYMM.json`

- [x] **Task 3:** Add Claude Code health to unified health check
  - Modify `tools/memory_hub_health.zsh`
  - Add Claude Code health section
  - Calculate Claude Code health score
  - Include in overall system health

- [x] **Task 4:** Integrate Claude Code alerts
  - Modify `tools/governance_alert_hook.zsh`
  - Add Claude Code health checks
  - Add alert triggers (hook failure > 20%, conflicts > 10%)
  - Send Telegram alerts

- [x] **Task 5:** Add Claude Code section to governance report
  - Modify `tools/governance_report_generator.zsh`
  - Add "Claude Code Compliance" section
  - Include hook metrics, review metrics, deployment metrics
  - Calculate compliance score

- [x] **Task 6:** Include Claude Code in certificate validation
  - Modify `tools/certificate_validator.zsh`
  - Add Claude Code component checks
  - Validate hooks, settings, dependencies

- [x] **Task 7:** Create dependency management script
  - Create `tools/claude_hooks/setup_dependencies.zsh`
  - Check for shellcheck, pylint, jq, gh, git
  - Install missing dependencies
  - Verify installation

- [x] **Task 8:** Add security/credential checks
  - Add pattern scanning to hooks
  - Detect hard-coded credentials
  - Detect SSH keys
  - Link with certificate validation

- [x] **Task 9:** Update acceptance tests
  - Modify `tools/phase5_acceptance.zsh`
  - Add Claude Code integration tests
  - Verify metrics in Redis
  - Verify health check includes Claude Code

---

## Test Strategy

### Unit Tests

**Test 1: Redis Integration**
```bash
tools/claude_tools/metrics_collector.zsh
redis-cli -a changeme-02luka HGETALL memory:agents:claude
# Expected: Claude Code metrics in Redis
```

**Test 2: Metrics Collector Integration**
```bash
tools/memory_metrics_collector.zsh
jq '.agents.claude' g/reports/memory_metrics_YYYYMM.json
# Expected: Claude Code metrics included
```

**Test 3: Health Check Integration**
```bash
tools/memory_hub_health.zsh
# Expected: Claude Code health section included, overall score calculated
```

**Test 4: Alert Integration**
```bash
# Simulate high hook failure rate
CLAUDE_CODE_HOOK_FAILURE_RATE=25 tools/governance_alert_hook.zsh
# Expected: Telegram alert sent
```

**Test 5: Dependency Management**
```bash
tools/claude_hooks/setup_dependencies.zsh
# Expected: All dependencies verified/installed
```

### Integration Tests

**Test 1: End-to-End Metrics Flow**
```bash
# Run Claude Code metrics collector
tools/claude_tools/metrics_collector.zsh

# Verify in Redis
redis-cli -a changeme-02luka HGETALL memory:agents:claude

# Run Phase 5 metrics collector
tools/memory_metrics_collector.zsh

# Verify in monthly metrics
jq '.agents.claude' g/reports/memory_metrics_YYYYMM.json

# Expected: Metrics flow from Claude Code → Redis → Phase 5 → Monthly report
```

**Test 2: Unified Health Check**
```bash
tools/memory_hub_health.zsh
# Expected: Includes Claude Code health, overall score includes Claude Code
```

**Test 3: Governance Report Integration**
```bash
tools/governance_report_generator.zsh
grep -A 20 "Claude Code Compliance" g/reports/system_governance_WEEKLY_*.md
# Expected: Claude Code section in report
```

---

## Deployment Checklist

- [x] **Pre-Deployment:**
  - [x] Verify Phase 5 components operational
  - [x] Verify Claude Code components exist
  - [x] Verify Redis connectivity
  - [x] Check existing metrics structure

- [x] **Deployment:**
  - [x] Modify Claude Code metrics collector (Redis integration)
  - [x] Modify Phase 5 metrics collector (include Claude Code)
  - [x] Modify unified health check (add Claude Code)
  - [x] Modify alert hook (add Claude Code alerts)
  - [x] Modify governance report (add Claude Code section)
  - [x] Modify certificate validator (include Claude Code)
  - [x] Create dependency management script
  - [x] Add security checks
  - [x] Update acceptance tests

- [x] **Post-Deployment:**
  - [x] Run acceptance tests
  - [x] Verify metrics in Redis
  - [x] Verify health check includes Claude Code
  - [x] Test alert functionality
  - [x] Verify governance report includes Claude Code
  - [x] Verify certificate validation includes Claude Code
  - [x] Test dependency management

---

## Rollback Plan

### Immediate Rollback
```bash
# Revert modified scripts to previous versions
git checkout HEAD~1 tools/claude_tools/metrics_collector.zsh
git checkout HEAD~1 tools/memory_metrics_collector.zsh
git checkout HEAD~1 tools/memory_hub_health.zsh
git checkout HEAD~1 tools/governance_alert_hook.zsh
git checkout HEAD~1 tools/governance_report_generator.zsh
git checkout HEAD~1 tools/certificate_validator.zsh

# Remove new scripts
rm -f tools/claude_hooks/setup_dependencies.zsh

# Preserve data
# (keep existing metrics and reports)
```

---

## Acceptance Criteria

✅ **Functional:**
- Claude Code metrics in Redis
- Metrics included in monthly aggregation
- Health check includes Claude Code
- Alerts sent when health degrades
- Governance report includes Claude Code
- Certificate validation includes Claude Code
- Dependencies managed

✅ **Operational:**
- All integrations working
- Metrics accurate
- Alerts timely
- Reports complete

✅ **Quality:**
- Unified health score accurate
- Compliance reporting clear
- Dependencies verified
- Security checks comprehensive

---

## Timeline

- **Implementation:** ~3 hours
- **Testing:** ~1.5 hours
- **Documentation:** ~30 minutes

**Total:** ~5 hours

---

## Success Metrics

1. **Integration:** Claude Code metrics in Redis
2. **Health:** Unified health score includes Claude Code
3. **Alerts:** Notifications sent correctly
4. **Reports:** Governance report includes Claude Code
5. **Validation:** Certificates validated including Claude Code
6. **Dependencies:** All dependencies verified/installed

---

## Dependencies

- **Phase 5:** Must be operational
- **Claude Code Best Practices:** Must be deployed
- **Redis:** Must be running
- **Telegram:** Credentials required for alerts

---

## Integration Checklist

- [x] Redis integration (metrics → memory:agents:claude)
- [x] Metrics collector integration (monthly aggregation)
- [x] Health check integration (unified score)
- [x] Alert integration (Telegram notifications)
- [x] Governance report integration (Claude Code section)
- [x] Certificate validation integration (component checks)
- [x] Dependency management (setup script)
- [x] Security checks (credential scanning)

---

## References

- **SPEC:** `g/reports/feature_claude_code_governance_integration_SPEC.md`
- **Phase 5 SPEC:** `g/reports/feature_phase5_governance_reporting_SPEC.md`
- **Claude Code Best Practices:** Previous implementation plan
- **Phase 4 SPEC:** `g/reports/feature_shared_memory_phase4_redis_hub_SPEC.md`
