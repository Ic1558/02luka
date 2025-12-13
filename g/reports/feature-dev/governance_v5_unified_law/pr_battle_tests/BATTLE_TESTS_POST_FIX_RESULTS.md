# Battle Tests Results — Post Gateway Fix

**Date:** 2025-12-10  
**Status:** ✅ **TESTS EXECUTED** — Gateway using v5 stack

---

## Test Execution

### PR-8: Error Scenarios
- ✅ 3 WOs created
- ✅ Invalid YAML: Caught and moved to error inbox
- ⏳ Forbidden Path: Processing...
- ⏳ Sandbox Violation: Processing...

### PR-9: Rollback Test
- ✅ Baseline created
- ✅ WO created (STRICT lane)
- ⏳ CLC processing...
- ⏳ Rollback execution...

### PR-10: CLS Auto-Approve
- ✅ 2 WOs created
- ⏳ Gateway processing...
- ⏳ File creation verification...

---

## Telemetry Analysis

**v5 Processing:** Check telemetry for `action: "process_v5"` entries

**Expected:**
- All PR-8, PR-9, PR-10 WOs should show `action: "process_v5"`
- No `action: "route"` (legacy) for test WOs

---

## Next Steps

1. Wait for gateway to process WOs (check telemetry)
2. Verify PR-8: Error scenarios blocked correctly
3. Verify PR-9: Rollback executed successfully
4. Verify PR-10: CLS auto-approve files created

---

**Last Updated:** 2025-12-10

