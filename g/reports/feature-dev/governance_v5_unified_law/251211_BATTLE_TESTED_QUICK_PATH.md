# How to Reach "PRODUCTION READY v5 — Battle-Tested"

**Date:** 2025-12-11  
**Reference:** `251211_production_ready_v5_battle_tested_SPEC.md`  
**Current Status:** ✅ **WIRED (Integrated)** — Limited Production Verification  
**Target Status:** ✅ **PRODUCTION READY v5 — Battle-Tested**

---

## Quick Path (7 Days)

| Day | Action | PR Gate | Evidence |
|-----|--------|---------|----------|
| **1-3** | Use v5 routing in daily work (30+ ops) | **PR-7** | Telemetry log shows 30+ `process_v5` entries |
| **3** | Intentionally test error scenario | **PR-8** | 3+ error cases logged in `bridge/error/MAIN/` |
| **4** | Execute 1 live rollback test | **PR-9** | Rollback report with checksums verified |
| **5** | Let CLS auto-approve 2+ LOCKED writes | **PR-10** | CLS auto-approve evidence in telemetry |
| **6-7** | Monitor stability, no crashes | **PR-11** | 7-day monitor window summary |
| **7** | Sign-off | **PR-12** | Final battle-tested report |

---

## Practical Steps

### PR-7: Real Production Usage (Volume) — 30+ Operations

**Objective:** Collect 30+ v5 operations within 7 days

**How to do it:**
```bash
# Just use the system normally - save-now, seal-now, etc.
# Each operation logs to telemetry automatically

# Check current count:
tail -100 g/telemetry/gateway_v3_router.log | grep '"action":"process_v5"' | wc -l

# Monitor progress:
zsh tools/monitor_v5_production.zsh json | python3 -c "import sys, json; d=json.load(sys.stdin); print(f\"v5 ops: {d.get('v5_activity_24h', 'N/A')}\")"
```

**What counts:**
- ✅ Any WO processed through `wo_processor_v5.process_wo_from_main()`
- ✅ Operations logged with `action:"process_v5"` in telemetry
- ✅ Both FAST (local) and STRICT (CLC) lanes count

**Target:**
- Total: ≥ 30 operations
- Strict ops: ≥ 5
- Local ops: ≥ 20
- Rejected ops: ≥ 1

**Evidence file:** `2512xx_v5_production_usage_STATS.json`

---

### PR-8: Real Error & Recovery — 3+ Error Scenarios

**Objective:** Test error handling with real error cases

**How to do it:**

#### Test 1: DANGER Zone Block
```bash
# Create a WO that tries to write to DANGER zone
cat > /tmp/test_danger_wo.yaml << 'EOF'
wo_id: TEST-ERROR-DANGER-$(date +%Y%m%d_%H%M%S)
origin:
  actor: GG
  world: CLI
operations:
  - type: write
    target_path: /System/Library/test.txt
    content: "test"
EOF

# Move to MAIN inbox
cp /tmp/test_danger_wo.yaml bridge/inbox/MAIN/

# Should be blocked by SandboxGuard
# Check error log:
ls -la bridge/error/MAIN/TEST-ERROR-DANGER-*.yaml
```

#### Test 2: Invalid Path (Traversal)
```bash
# Create a WO with path traversal
cat > /tmp/test_traversal_wo.yaml << 'EOF'
wo_id: TEST-ERROR-TRAVERSAL-$(date +%Y%m%d_%H%M%S)
origin:
  actor: GG
  world: CLI
operations:
  - type: write
    target_path: ../../../etc/passwd
    content: "test"
EOF

cp /tmp/test_traversal_wo.yaml bridge/inbox/MAIN/
# Should be blocked by SandboxGuard
```

#### Test 3: Invalid YAML
```bash
# Create invalid YAML
cat > /tmp/test_invalid_yaml.yaml << 'EOF'
wo_id: TEST-ERROR-INVALID-YAML
invalid: yaml: [unclosed
EOF

cp /tmp/test_invalid_yaml.yaml bridge/inbox/MAIN/
# Should be caught by parser, moved to error/
```

**What to verify:**
- ✅ Error logged in `bridge/error/MAIN/`
- ✅ Telemetry shows error entry
- ✅ Gateway/Mary doesn't crash
- ✅ No backlog stuck in MAIN/CLC inbox

**Evidence file:** `2512xx_v5_incident_log.md`

---

### PR-9: Real Rollback Exercise (Live) — 1 Live Rollback

**Objective:** Execute a real rollback in production

**How to do it:**

#### Step 1: Create High-Risk WO (STRICT lane)
```bash
# Create a safe test file first
TEST_FILE="g/reports/test_rollback_$(date +%Y%m%d_%H%M%S).md"

# Create WO that writes to this file
cat > /tmp/test_rollback_wo.yaml << EOF
wo_id: TEST-ROLLBACK-$(date +%Y%m%d_%H%M%S)
origin:
  actor: CLC
  world: BACKGROUND
operations:
  - type: write
    target_path: $TEST_FILE
    content: |
      # Test Rollback
      This file will be rolled back.
      Timestamp: $(date -Iseconds)
risk_level: HIGH
rollback_strategy: git_revert
EOF

# Move to MAIN inbox
cp /tmp/test_rollback_wo.yaml bridge/inbox/MAIN/

# Wait for CLC to process (or trigger manually)
# Check CLC inbox:
ls -la bridge/inbox/CLC/TEST-ROLLBACK-*.yaml
```

#### Step 2: Verify File Created
```bash
# Check file exists
ls -la "$TEST_FILE"

# Get checksum before rollback
CHECKSUM_BEFORE=$(md5sum "$TEST_FILE" | cut -d' ' -f1)
echo "Checksum before: $CHECKSUM_BEFORE"
```

#### Step 3: Execute Rollback
```bash
# Trigger rollback (via CLC executor or manually)
# Or use git revert:
cd /Users/icmini/02luka
git add "$TEST_FILE"
git commit -m "Test rollback file"
git revert HEAD --no-edit

# Verify checksum after (should match original or file deleted)
CHECKSUM_AFTER=$(md5sum "$TEST_FILE" 2>/dev/null | cut -d' ' -f1 || echo "FILE_DELETED")
echo "Checksum after: $CHECKSUM_AFTER"
```

#### Step 4: Check Audit Log
```bash
# Find audit log
AUDIT_LOG=$(ls -t g/logs/clc_execution/*TEST-ROLLBACK*.json | head -1)
cat "$AUDIT_LOG" | python3 -m json.tool | grep -A 5 "rollback"
```

**What to verify:**
- ✅ File created successfully
- ✅ Rollback executed
- ✅ Checksum before/after match (or file reverted)
- ✅ Audit log shows `status: "rollback_ok"`

**Evidence file:** `2512xx_v5_live_rollback_REPORT.md`

---

### PR-10: CLS Auto-Approve in Real Use — 2+ Cases

**Objective:** Verify CLS auto-approve works in production

**How to do it:**

#### Test Case 1: CLS writes to whitelist path (g/reports/)
```bash
# Create WO with CLS actor, LOCKED zone path in whitelist
cat > /tmp/test_cls_auto1.yaml << 'EOF'
wo_id: TEST-CLS-AUTO-1-$(date +%Y%m%d_%H%M%S)
origin:
  actor: CLS
  world: CLI
operations:
  - type: write
    target_path: g/reports/test_cls_auto1.md
    content: |
      # CLS Auto-Approve Test 1
      This should auto-approve (whitelist path).
context:
  rollback_strategy: git_revert
  boss_approved_pattern: "g/reports/*.md"
EOF

cp /tmp/test_cls_auto1.yaml bridge/inbox/MAIN/
```

#### Test Case 2: CLS writes to another whitelist path
```bash
cat > /tmp/test_cls_auto2.yaml << 'EOF'
wo_id: TEST-CLS-AUTO-2-$(date +%Y%m%d_%H%M%S)
origin:
  actor: CLS
  world: CLI
operations:
  - type: write
    target_path: bridge/templates/test_cls_auto2.md
    content: |
      # CLS Auto-Approve Test 2
      This should also auto-approve.
context:
  rollback_strategy: git_revert
  boss_approved_pattern: "bridge/templates/*.md"
EOF

cp /tmp/test_cls_auto2.yaml bridge/inbox/MAIN/
```

**What to verify:**
- ✅ CLS auto-approve triggered (check telemetry)
- ✅ Path in whitelist
- ✅ `rollback_strategy` present
- ✅ `boss_approved_pattern` matches
- ✅ No manual Boss approval needed
- ✅ File created successfully

**Evidence file:** `2512xx_cls_auto_approve_EVIDENCE.md`

---

### PR-11: Monitoring Stability Window — 7 Days

**Objective:** Monitor system stability for 7 consecutive days

**How to do it:**

#### Daily Monitor Command
```bash
# Run daily (save output):
DATE=$(date +%Y%m%d)
zsh tools/monitor_v5_production.zsh json > "g/reports/monitor_daily_${DATE}.json"

# Check status:
cat "g/reports/monitor_daily_${DATE}.json" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(f\"Status: {d.get('status', 'N/A')}\")
print(f\"Error rate: {d.get('error_stats', {}).get('error_rate', 0)}%\")
print(f\"Main backlog: {d.get('inbox_backlog', {}).get('main', 0)}\")
print(f\"CLC backlog: {d.get('inbox_backlog', {}).get('clc', 0)}\")
"
```

#### Weekly Summary Script
```bash
# After 7 days, create summary:
cat > /tmp/summarize_monitor.sh << 'EOF'
#!/bin/bash
cd /Users/icmini/02luka
echo "# 7-Day Monitor Summary" > g/reports/2512xx_v5_monitor_window_SUMMARY.md
echo "" >> g/reports/2512xx_v5_monitor_window_SUMMARY.md
echo "Date range: $(date -v-7d +%Y-%m-%d) to $(date +%Y-%m-%d)" >> g/reports/2512xx_v5_monitor_window_SUMMARY.md
echo "" >> g/reports/2512xx_v5_monitor_window_SUMMARY.md

for file in g/reports/monitor_daily_*.json; do
    if [ -f "$file" ]; then
        DATE=$(basename "$file" | sed 's/monitor_daily_//;s/.json//')
        echo "## $DATE" >> g/reports/2512xx_v5_monitor_window_SUMMARY.md
        cat "$file" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(f\"- Status: {d.get('status', 'N/A')}\")
print(f\"- Error rate: {d.get('error_stats', {}).get('error_rate', 0)}%\")
print(f\"- Main backlog: {d.get('inbox_backlog', {}).get('main', 0)}\")
print(f\"- CLC backlog: {d.get('inbox_backlog', {}).get('clc', 0)}\")
" >> g/reports/2512xx_v5_monitor_window_SUMMARY.md
        echo "" >> g/reports/2512xx_v5_monitor_window_SUMMARY.md
    fi
done
EOF

chmod +x /tmp/summarize_monitor.sh
/tmp/summarize_monitor.sh
```

**What to verify:**
- ✅ Status never "down" or "degraded"
- ✅ Error rate ≤ 10% (for v5 ops)
- ✅ Main backlog = 0 (no stuck WOs)
- ✅ CLC backlog = 0 (no pending YAML files)

**Evidence file:** `2512xx_v5_monitor_window_SUMMARY.md`

---

### PR-12: Post-Mortem & Final Sign-off

**Objective:** Create final battle-tested report

**How to do it:**

#### Create Final Report
```bash
cat > /tmp/create_final_report.sh << 'EOF'
#!/bin/bash
cd /Users/icmini/02luka

FINAL_REPORT="g/reports/feature-dev/governance_v5_unified_law/2512xx_v5_battle_tested_FINAL.md"

cat > "$FINAL_REPORT" << 'INNEREOF'
# Governance v5 — Battle-Tested Final Report

**Date:** $(date +%Y-%m-%d)  
**Status:** ✅ **PRODUCTION READY v5 — Battle-Tested**

## Summary

All battle-tested criteria (PR-7 to PR-12) have been fulfilled.

### Statistics

- Total v5 operations: [COUNT]
- Strict ops: [COUNT]
- Local ops: [COUNT]
- Rejected ops: [COUNT]
- Errors: [COUNT]
- Rollback exercises: [COUNT]

### PR-7: Real Production Usage ✅

- Total operations: [COUNT] (target: ≥30)
- Time window: [DAYS] days
- Evidence: `2512xx_v5_production_usage_STATS.json`

### PR-8: Real Error & Recovery ✅

- Error scenarios: [COUNT] (target: ≥3)
- All errors handled correctly
- Evidence: `2512xx_v5_incident_log.md`

### PR-9: Real Rollback Exercise ✅

- Live rollback executed: [YES/NO]
- Checksums verified: [YES/NO]
- Evidence: `2512xx_v5_live_rollback_REPORT.md`

### PR-10: CLS Auto-Approve ✅

- CLS auto-approve cases: [COUNT] (target: ≥2)
- All in whitelist paths
- Evidence: `2512xx_cls_auto_approve_EVIDENCE.md`

### PR-11: Monitoring Stability ✅

- 7-day window: [START] to [END]
- Status: Stable (no "down" or "degraded")
- Error rate: [RATE]% (target: ≤10%)
- Evidence: `2512xx_v5_monitor_window_SUMMARY.md`

## Final Statement

As of $(date +%Y-%m-%d), Governance v5 routing stack is **Production Ready (Battle-Tested)** under real workload in 02luka. Future failures are expected to be contained and diagnosable using the documented runbooks and telemetry.

**Signed off by:** [NAME]  
**Date:** $(date +%Y-%m-%d)
INNEREOF

echo "✅ Final report created: $FINAL_REPORT"
EOF

chmod +x /tmp/create_final_report.sh
/tmp/create_final_report.sh
```

**What to include:**
- ✅ All statistics (ops, errors, rollback count)
- ✅ Evidence files referenced
- ✅ Final statement confirming battle-tested status
- ✅ Sign-off date

**Evidence file:** `2512xx_v5_battle_tested_FINAL.md`

---

## Quick Reference Checklist

**Day 1-3:**
- [ ] Use system normally (30+ operations)
- [ ] Check telemetry: `tail -100 g/telemetry/gateway_v3_router.log | grep process_v5`

**Day 3:**
- [ ] Test 3 error scenarios (DANGER zone, traversal, invalid YAML)
- [ ] Verify errors logged in `bridge/error/MAIN/`

**Day 4:**
- [ ] Create high-risk WO
- [ ] Execute rollback
- [ ] Verify checksums

**Day 5:**
- [ ] Create 2 CLS auto-approve test cases
- [ ] Verify auto-approve triggered

**Day 6-7:**
- [ ] Run monitor daily: `zsh tools/monitor_v5_production.zsh json`
- [ ] Save output to `g/reports/monitor_daily_YYYYMMDD.json`

**Day 7:**
- [ ] Create final report
- [ ] Update checklist status
- [ ] Change status to "PRODUCTION READY v5 — Battle-Tested"

---

## Summary

**ใช้ระบบปกติ 7 วัน + ทำ 4 tests = Battle-Tested 🎯**

1. **PR-7:** Use system normally (30+ ops)
2. **PR-8:** Test 3 error scenarios
3. **PR-9:** Execute 1 live rollback
4. **PR-10:** Test 2 CLS auto-approve cases
5. **PR-11:** Monitor 7 days
6. **PR-12:** Sign-off

**Result:** ✅ **PRODUCTION READY v5 — Battle-Tested**

---

**Last Updated:** 2025-12-11  
**Reference:** `251211_production_ready_v5_battle_tested_SPEC.md`

