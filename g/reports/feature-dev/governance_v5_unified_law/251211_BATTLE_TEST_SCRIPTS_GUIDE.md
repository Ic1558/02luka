# Battle Test Scripts Guide — PR-8, PR-9, PR-10

**Date:** 2025-12-11  
**Purpose:** Ready-to-run scripts for PR-8, PR-9, PR-10 battle testing

---

## Quick Start

### Option 1: Run All Tests (Recommended)
```bash
cd ~/02luka
zsh tools/run_all_battle_tests.zsh
```

### Option 2: Run Individually

**PR-8 (Error Scenarios):**
```bash
cd ~/02luka
zsh tools/pr8_v5_error_scenarios.zsh
# Wait a few seconds, then check:
tail -40 g/telemetry/gateway_v3_router.log
zsh tools/monitor_v5_production.zsh json
```

**PR-9 (Rollback Test):**
```bash
cd ~/02luka
# Step 1: Setup
zsh tools/pr9_rollback_test.zsh

# Step 2: After CLC processes (wait ~10 seconds)
zsh tools/pr9_rollback_execute.zsh

# Step 3: After rollback (wait ~10 seconds)
zsh tools/pr9_rollback_verify.zsh
```

**PR-10 (CLS Auto-Approve):**
```bash
cd ~/02luka
# Create test WOs
zsh tools/pr10_cls_auto_approve.zsh

# Wait a few seconds, then verify
zsh tools/pr10_verify.zsh
```

---

## Scripts Overview

| Script | Purpose | Output |
|--------|---------|--------|
| `pr8_v5_error_scenarios.zsh` | Create 3 error test WOs | WO files in `bridge/inbox/MAIN/` |
| `pr9_rollback_test.zsh` | Setup rollback test baseline | Baseline file + checksum |
| `pr9_rollback_execute.zsh` | Execute rollback | Rollback WO created |
| `pr9_rollback_verify.zsh` | Verify rollback success | Verification report |
| `pr10_cls_auto_approve.zsh` | Create CLS auto-approve WOs | 2 WO files |
| `pr10_verify.zsh` | Verify CLS auto-approve | Verification report |
| `run_all_battle_tests.zsh` | Run all tests sequentially | All reports |

---

## PR-8: Error Scenarios

**What it does:**
1. Creates 3 WOs with intentional errors:
   - `WO-PR8-INVALID-YAML.yaml` — Invalid YAML syntax
   - `WO-PR8-FORBIDDEN-PATH.yaml` — DANGER zone path (`/usr/local/...`)
   - `WO-PR8-SANDBOX-VIOLATION.yaml` — Forbidden content (`rm -rf /`)

**Expected results:**
- Invalid YAML → Moved to `bridge/error/MAIN/` with parse error
- Forbidden path → Blocked by SandboxGuard, `rejected_ops > 0`
- Sandbox violation → Blocked by SandboxGuard, `rejected_ops > 0`

**Verification:**
```bash
# Check error inbox
ls -la bridge/error/MAIN/WO-PR8-*

# Check telemetry
tail -40 g/telemetry/gateway_v3_router.log | grep PR8

# Check monitor
zsh tools/monitor_v5_production.zsh json
```

---

## PR-9: Rollback Test

**What it does:**
1. Creates baseline file with checksum
2. Creates WO that modifies file (STRICT lane → CLC)
3. Executes rollback
4. Verifies checksum matches baseline

**Files created:**
- `g/reports/feature-dev/governance_v5_unified_law/pr_battle_tests/PR9_ROLLBACK_TEST.md`
- Checksum files: `.sha256.before`, `.sha256.after_modify`, `.sha256.after_rollback`

**Expected results:**
- File modified by CLC (GOOD → BROKEN)
- Rollback executed successfully
- Checksum after rollback = checksum before

**Verification:**
```bash
# Check checksums
cat g/reports/feature-dev/governance_v5_unified_law/pr_battle_tests/PR9_ROLLBACK_TEST.md.sha256.*

# Check audit logs
ls -la g/logs/clc_execution/*PR9*

# View report
cat g/reports/feature-dev/governance_v5_unified_law/pr_battle_tests/PR9_ROLLBACK_VERIFICATION.md
```

---

## PR-10: CLS Auto-Approve

**What it does:**
1. Creates 2 WOs with CLS actor:
   - `WO-PR10-CLS-TEMPLATE.yaml` → Writes to `bridge/templates/`
   - `WO-PR10-CLS-DOC.yaml` → Writes to `bridge/docs/`
2. Both have `rollback_strategy` and `boss_approved_pattern`
3. Verifies files created without going through CLC strict lane

**Expected results:**
- Both files created successfully
- No WOs in error inbox
- CLS auto-approve triggered (check telemetry)

**Verification:**
```bash
# Check files exist
ls -la bridge/templates/pr10_auto_approve_email.html
ls -la bridge/docs/pr10_auto_approve_note.md

# Check error inbox (should be empty)
ls -la bridge/error/MAIN/WO-PR10-*

# Check telemetry
tail -40 g/telemetry/gateway_v3_router.log | grep PR10

# View report
cat g/reports/feature-dev/governance_v5_unified_law/pr_battle_tests/PR10_CLS_AUTO_APPROVE_VERIFICATION.md
```

---

## Evidence Files

All evidence files are saved in:
```
g/reports/feature-dev/governance_v5_unified_law/pr_battle_tests/
```

**Reports:**
- `PR9_ROLLBACK_VERIFICATION.md` — PR-9 results
- `PR10_CLS_AUTO_APPROVE_VERIFICATION.md` — PR-10 results

**Checksums:**
- `PR9_ROLLBACK_TEST.md.sha256.before`
- `PR9_ROLLBACK_TEST.md.sha256.after_modify`
- `PR9_ROLLBACK_TEST.md.sha256.after_rollback`

---

## Troubleshooting

### PR-8: WOs not processed
```bash
# Check if gateway is running
ps aux | grep gateway_v3_router

# Check inbox
ls -la bridge/inbox/MAIN/WO-PR8-*

# Manually trigger (if needed)
# Check gateway_v3_router.py for manual trigger method
```

### PR-9: Rollback not working
```bash
# Check if CLC processed the WO
ls -la bridge/inbox/CLC/WO-PR9-*
ls -la bridge/outbox/CLC/*/WO-PR9-*

# Check audit logs
ls -la g/logs/clc_execution/*PR9*

# Check git status
cd ~/02luka
git status g/reports/feature-dev/governance_v5_unified_law/pr_battle_tests/PR9_ROLLBACK_TEST.md
```

### PR-10: Files not created
```bash
# Check if WOs were processed
ls -la bridge/inbox/MAIN/WO-PR10-*
ls -la bridge/error/MAIN/WO-PR10-*

# Check telemetry for routing decisions
tail -40 g/telemetry/gateway_v3_router.log | grep PR10

# Check if paths are in whitelist
# See: bridge/core/router_v5_config.yaml (mission_scope)
```

---

## Success Criteria

**PR-8:**
- ✅ 3 error scenarios logged
- ✅ Invalid YAML → error inbox
- ✅ Forbidden path → blocked
- ✅ Sandbox violation → blocked

**PR-9:**
- ✅ File modified (checksum changed)
- ✅ Rollback executed
- ✅ Checksum restored (before = after rollback)
- ✅ Audit log shows rollback status

**PR-10:**
- ✅ Both files created
- ✅ No WOs in error inbox
- ✅ CLS auto-approve triggered (check telemetry)

---

**Last Updated:** 2025-12-11  
**Reference:** `251211_production_ready_v5_battle_tested_SPEC.md`

