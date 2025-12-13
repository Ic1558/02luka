# Battle Test Results Summary

**Date:** 2025-12-10  
**Tests Run:** PR-8, PR-9, PR-10

## Issue Identified

**Problem:** WOs are being routed through legacy system (`action: "route"`) instead of v5 processing (`action: "process_v5"`).

## Test Results

### PR-8: Error Scenarios

- ✅ **Invalid YAML:** Caught correctly (moved to error inbox)
- ⚠️ **Forbidden Path:** Routed to CLC via legacy routing (not processed by v5)
- ⚠️ **Sandbox Violation:** Routed to CLC via legacy routing (not processed by v5)

**Telemetry shows:**
- `WO-PR8-FORBIDDEN-PATH`: `action: "route"` (legacy)
- `WO-PR8-SANDBOX-VIOLATION`: `action: "route"` (legacy)
- Expected: `action: "process_v5"` with `rejected_ops > 0`

### PR-9: Rollback Test

- ⚠️ **File not modified:** WO routed to CLC but not processed
- ⚠️ **Move error:** WO moved to error inbox due to file not found
- ⚠️ **False positive:** Test "passed" because file was never changed

**Telemetry shows:**
- `WO-PR9-ROLLBACK-TEST`: `action: "route"` → `action: "move"` → error
- Expected: `action: "process_v5"` → CLC processes → file modified

### PR-10: CLS Auto-Approve

- ⚠️ **Files not created:** WOs routed to CLC via legacy routing
- ⚠️ **Not processed by v5:** No `process_v5` action in telemetry

**Telemetry shows:**
- `WO-PR10-CLS-TEMPLATE`: `action: "route"` (legacy)
- `WO-PR10-CLS-DOC`: `action: "route"` (legacy)
- Expected: `action: "process_v5"` → local execution (WARN lane)

## Root Cause

Gateway v3 Router is not calling `wo_processor_v5.process_wo_from_main()` for these WOs. They're going through the legacy routing system instead.

## Next Steps

1. Check gateway_v3_router.py integration with wo_processor_v5
2. Verify MAIN inbox processing uses v5 stack
3. Re-run tests after fixing integration

