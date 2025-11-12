# Feature PLAN: Phase 4 Operational Tools & Documentation

**Feature ID:** `phase4_operational_tools`  
**Version:** 1.0.0  
**Date:** 2025-11-12  
**Status:** Ready for Implementation

---

## Task Breakdown

### Phase 4 Operational Tools ✅

- [x] **Task 1:** Create acceptance test script
  - `tools/phase4_acceptance.zsh`
  - 5 tests: hub, Redis, Mary hook, R&D hook, health
  - Clear ✅/❌ output

- [x] **Task 2:** Create helper aliases
  - `tools/mary.zsh` → `mary_memory_hook.zsh`
  - `tools/rnd.zsh` → `rnd_memory_hook.zsh`

- [x] **Task 3:** Create health check script
  - `tools/memory_hub_health.zsh`
  - Comprehensive Phase 4 checks
  - Health score + quick-fix hints

- [x] **Task 4:** Create daily digest script
  - `tools/memory_daily_digest.zsh`
  - Combines Mary + R&D activity
  - Generates `g/reports/memory_digest_YYYYMMDD.md`

- [x] **Task 5:** Create daily digest LaunchAgent
  - `com.02luka.memory.digest.daily` (07:05)

- [x] **Task 6:** Create daily runbook
  - `docs/runbooks/phase4_daily_operations.md`
  - 60-second operational guide

- [x] **Task 7:** Create deployment certificate
  - `g/reports/DEPLOYMENT_CERTIFICATE_phase4_operational.md`
  - Acceptance test results
  - Evidence (Redis dumps, logs)

---

## Test Strategy

### Unit Tests

**Test 1: Acceptance Script**
```bash
tools/phase4_acceptance.zsh
# Expected: All 5 tests pass, exit code 0
```

**Test 2: Helper Aliases**
```bash
tools/mary.zsh "test" "completed" '{"result":"ok"}'
tools/rnd.zsh "test" "processed" '{"score":85}'
# Expected: Hooks execute successfully
```

**Test 3: Health Check**
```bash
tools/memory_hub_health.zsh
# Expected: All checks pass, health score 100
```

**Test 4: Daily Digest**
```bash
tools/memory_daily_digest.zsh
# Expected: Report generated at g/reports/memory_digest_YYYYMMDD.md
```

### Integration Tests

**Test 1: End-to-End Acceptance**
```bash
# Run full acceptance suite
tools/phase4_acceptance.zsh
# Expected: All tests pass
```

**Test 2: Daily Digest with Real Data**
```bash
# Trigger some activity
tools/mary.zsh "wo_123" "completed" '{"result":"success"}'
tools/rnd.zsh "rnd_456" "processed" '{"score":88}'
# Generate digest
tools/memory_daily_digest.zsh
# Expected: Report includes both activities
```

---

## Deployment Checklist

- [x] **Pre-Deployment:**
  - [x] Verify Phase 4 components exist
  - [x] Verify Redis running
  - [x] Verify hub LaunchAgent loaded

- [x] **Deployment:**
  - [x] Create acceptance test script
  - [x] Create helper aliases
  - [x] Create health check script
  - [x] Create daily digest script
  - [x] Create LaunchAgent for digest
  - [x] Create runbook
  - [x] Run acceptance tests
  - [x] Generate deployment certificate

- [x] **Post-Deployment:**
  - [x] Verify all scripts executable
  - [x] Verify LaunchAgent loaded
  - [x] Test daily digest generation
  - [x] Verify runbook accessible

---

## Rollback Plan

### Immediate Rollback
```bash
# Remove aliases
rm -f ~/02luka/tools/mary.zsh ~/02luka/tools/rnd.zsh

# Unload LaunchAgent
launchctl unload ~/Library/LaunchAgents/com.02luka.memory.digest.daily.plist

# Remove scripts (optional)
rm -f ~/02luka/tools/phase4_acceptance.zsh
rm -f ~/02luka/tools/memory_hub_health.zsh
rm -f ~/02luka/tools/memory_daily_digest.zsh
```

---

## Acceptance Criteria

✅ **Functional:**
- Acceptance test script passes all 5 tests
- Helper aliases work
- Health check comprehensive
- Daily digest generates report
- Runbook clear

✅ **Operational:**
- All tools executable
- LaunchAgent loaded
- Documentation complete
- Deployment certificate signed

---

## Timeline

- **Implementation:** ~30 minutes
- **Testing:** ~15 minutes
- **Documentation:** ~15 minutes

**Total:** ~60 minutes

---

## Success Metrics

1. **Acceptance:** All 5 tests pass
2. **Usability:** Runbook < 60 seconds
3. **Visibility:** Daily digest shows activity
4. **Reliability:** Health check catches issues

---

## References

- **SPEC:** `g/reports/feature_phase4_operational_tools_SPEC.md`
- **Phase 4 SPEC:** `g/reports/feature_shared_memory_phase4_redis_hub_SPEC.md`

