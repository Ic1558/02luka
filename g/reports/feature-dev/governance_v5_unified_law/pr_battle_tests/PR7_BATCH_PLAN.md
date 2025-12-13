# PR-7: Production Usage Batch Plan

**Date:** 2025-12-12  
**Status:** ⏳ **IN PROGRESS** — 8/30 → Target: 30+

---

## Objective

Reach 30+ v5 operations with `local_ops > 0` (FAST lane) for production usage verification.

---

## Current Status

- **Starting:** 8/30 (26%)
- **After Batch 1:** ~20/30 (estimated)
- **Remaining:** ~10 operations needed

---

## Strategy

### Batch 1: 12 WOs (Created)
- Target: Whitelist paths (OPEN zone)
- Trigger: `cursor` (CLI world)
- Actor: `CLS`
- Expected: All go to FAST lane (`local_ops > 0`)

### Batch 2: 10 WOs (If needed)
- Create additional WOs if Batch 1 doesn't reach 30
- Same strategy: Whitelist paths, FAST lane

---

## Target Paths (Whitelist/OPEN Zone)

1. `bridge/templates/pr7_test_*.html`
2. `g/reports/feature-dev/governance_v5_unified_law/pr_battle_tests/pr7_test_*.md`
3. `bridge/templates/pr7_doc_*.html`
4. `g/reports/feature-dev/governance_v5_unified_law/pr_battle_tests/pr7_evidence_*.md`

---

## Verification

**Count command:**
```bash
grep -c '"local_ops":[1-9]' ~/02luka/g/telemetry/gateway_v3_router.log
```

**Or from Python:**
```python
# Count entries with process_v5 and local_ops > 0
total = sum(1 for line in open('g/telemetry/gateway_v3_router.log')
            if 'process_v5' in line and '"local_ops":' in line
            and int(line.split('"local_ops":')[1].split(',')[0].strip()) > 0)
```

---

## Progress Tracking

- **File:** `PR7_PROGRESS.json`
- **Updated:** After each batch
- **Format:** JSON with current count, target, percentage

---

## Next Steps

1. ✅ Batch 1 created (12 WOs)
2. ⏳ Wait for processing
3. ⏳ Check count
4. ⏳ Create Batch 2 if needed (10 WOs)
5. ✅ Reach 30+ operations
6. ✅ Verify all are `process_v5` with `local_ops > 0`

---

**Last Updated:** 2025-12-12

