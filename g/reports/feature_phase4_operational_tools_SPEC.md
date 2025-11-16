# Feature SPEC: Phase 4 Operational Tools & Documentation

**Feature ID:** `phase4_operational_tools`  
**Version:** 1.0.0  
**Date:** 2025-11-12  
**Status:** Ready for Implementation

---

## Objective

Create operational tools, acceptance tests, runbook, and documentation to make Phase 4 (Redis Hub & Mary/R&D Integration) production-ready and easy to use daily.

---

## Problem Statement

Phase 4 is deployed but lacks:
- Quick acceptance tests to verify everything works
- Daily runbook for operators
- Helper aliases for easy access
- Comprehensive health check script
- Daily digest combining Mary + R&D activity
- Deployment certificate and evidence report

**Impact:**
- Hard to verify system is working
- Operators don't know how to use it daily
- No visibility into combined Mary/R&D activity
- No formal acceptance documentation

---

## Solution Overview

Create:
1. **Acceptance Test Script:** 5-command verification suite
2. **Daily Runbook:** 60-second operational guide
3. **Helper Aliases:** Short names for hooks (`mary.zsh`, `rnd.zsh`)
4. **Health Check Script:** `memory_hub_health.zsh` with Phase 4 checks
5. **Daily Digest:** Combined Mary + R&D activity report
6. **Deployment Certificate:** Formal acceptance documentation

---

## Components

### 1. Acceptance Test Script (`tools/phase4_acceptance.zsh`)

**Purpose:** Quick 5-command verification that Phase 4 is operational

**Tests:**
1. Hub running + LaunchAgent loaded
2. Redis connectivity + pub/sub working
3. Mary hook → Redis + context.json
4. R&D hook → Redis + context.json
5. Health check (all Phase 4 checks)

**Output:**
- ✅/❌ for each test
- Summary: "PASS" or "FAIL"
- Exit code: 0 (pass) or 1 (fail)

### 2. Helper Aliases (`tools/mary.zsh`, `tools/rnd.zsh`)

**Purpose:** Short, memorable names for memory hooks

**Implementation:**
- Symlinks to `mary_memory_hook.zsh` and `rnd_memory_hook.zsh`
- Same functionality, easier to remember

### 3. Health Check Script (`tools/memory_hub_health.zsh`)

**Purpose:** Comprehensive health check for Phase 4

**Checks:**
- Hub service running
- LaunchAgent loaded
- Redis connectivity
- Pub/sub channel working
- Hooks executable
- Context.json accessible
- Recent activity (last 5 minutes)

**Output:**
- ✅/❌ for each check
- Overall health score (0-100)
- Quick-fix hints for failures

### 4. Daily Digest Script (`tools/memory_daily_digest.zsh`)

**Purpose:** Generate daily report combining Mary + R&D activity

**Sources:**
- Redis keys: `memory:agents:mary`, `memory:agents:rnd`
- File: `shared_memory/context.json`
- Logs: `logs/memory_hub.out.log`

**Output:**
- `g/reports/memory_digest_YYYYMMDD.md`
- Summary of Mary tasks completed
- Summary of R&D proposals processed
- Activity timeline
- Statistics (total tasks, success rate, etc.)

**Schedule:**
- LaunchAgent: `com.02luka.memory.digest.daily` (07:05)

### 5. Deployment Certificate (`g/reports/DEPLOYMENT_CERTIFICATE_phase4_operational.md`)

**Purpose:** Formal acceptance documentation

**Contents:**
- Acceptance test results
- Evidence (Redis dumps, log excerpts)
- Sign-off checklist
- Operational readiness confirmation

### 6. Daily Runbook (`docs/runbooks/phase4_daily_operations.md`)

**Purpose:** 60-second operational guide

**Sections:**
- Quick status check
- Recording Mary results
- Recording R&D outcomes
- Monitoring hub logs
- Troubleshooting tips

---

## Acceptance Criteria

✅ **Functional:**
- Acceptance test script passes all 5 tests
- Helper aliases work (`mary.zsh`, `rnd.zsh`)
- Health check script comprehensive
- Daily digest generates report
- Runbook clear and actionable

✅ **Operational:**
- All tools executable
- LaunchAgent for daily digest loaded
- Documentation complete
- Deployment certificate signed

---

## File Structure

```
~/02luka/
├── tools/
│   ├── phase4_acceptance.zsh          # Acceptance tests
│   ├── memory_hub_health.zsh           # Health check
│   ├── memory_daily_digest.zsh         # Daily digest
│   ├── mary.zsh -> mary_memory_hook.zsh  # Alias
│   └── rnd.zsh -> rnd_memory_hook.zsh    # Alias
├── docs/
│   └── runbooks/
│       └── phase4_daily_operations.md  # Runbook
├── g/reports/
│   ├── memory_digest_YYYYMMDD.md      # Daily reports
│   └── DEPLOYMENT_CERTIFICATE_phase4_operational.md
└── ~/Library/LaunchAgents/
    └── com.02luka.memory.digest.daily.plist
```

---

## Success Metrics

1. **Acceptance:** All 5 tests pass
2. **Usability:** Runbook < 60 seconds to read
3. **Visibility:** Daily digest shows Mary + R&D activity
4. **Reliability:** Health check catches issues early

---

## References

- **Phase 4 SPEC:** `g/reports/feature_shared_memory_phase4_redis_hub_SPEC.md`
- **Phase 4 PLAN:** `g/reports/feature_shared_memory_phase4_redis_hub_PLAN.md`
- **Existing Health Check:** `tools/shared_memory_health.zsh`

