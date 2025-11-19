# Gemini Routing Dry-Run Test Plan

**Date:** 2025-11-18  
**Purpose:** Verify Gemini routing integration flow (Liam → Kim → Dispatcher → Handler)  
**Status:** ✅ **TEST SCRIPT READY**

---

## Test Objectives

Verify that work orders with `engine: gemini` correctly:
1. Route through `wo_dispatcher.zsh` to `bridge/inbox/GEMINI/`
2. Preserve metadata: `engine=gemini`, `locked_zone_allowed=false`, `review_required_by`
3. Can be parsed and validated by `gemini_handler.py`
4. Generate reviewable output in `bridge/outbox/GEMINI/`

---

## Test Script

**Location:** `g/tools/test_gemini_routing_dryrun.zsh`

**What it does:**
1. Creates a test work order with proper Gemini metadata
2. Verifies metadata structure
3. Routes through `wo_dispatcher.zsh`
4. Validates routing destination (GEMINI inbox)
5. Tests handler YAML parsing (dry-run, no API call)
6. Generates test report

---

## Running the Test

```bash
cd ~/02luka
~/02luka/g/tools/test_gemini_routing_dryrun.zsh
```

**Expected Output:**
- ✅ Work order created
- ✅ Metadata verified
- ✅ Routing successful
- ✅ Handler validation passed
- 📝 Test report generated

---

## Manual Handler Execution (Optional)

After dry-run test passes, optionally run the handler:

```bash
cd ~/02luka
python3 bridge/handlers/gemini_handler.py
```

This will:
- Process work orders in `bridge/inbox/GEMINI/`
- Call Gemini API (if configured)
- Write results to `bridge/outbox/GEMINI/`

**Note:** This requires `GEMINI_API_KEY` environment variable to be set.

---

## Verification Checklist

After running the test:

- [ ] Test WO created in `g/tests/gemini_routing/`
- [ ] WO routed to `bridge/inbox/GEMINI/`
- [ ] Metadata preserved: `engine=gemini`, `locked_zone_allowed=false`
- [ ] Handler can parse WO (validation passed)
- [ ] Test report generated
- [ ] (Optional) Handler executed and result written to outbox

---

## Review Output

**For Andy/CLS Review:**

1. **Check Test Report:**
   ```bash
   cat g/tests/gemini_routing/GEMINI_DRYRUN_*_report.md
   ```

2. **Check Routed WO:**
   ```bash
   cat bridge/inbox/GEMINI/GEMINI_DRYRUN_*.yaml
   ```

3. **Check Handler Result (if executed):**
   ```bash
   cat bridge/outbox/GEMINI/GEMINI_DRYRUN_*_result.yaml
   ```

4. **Verify Metadata:**
   ```bash
   yq -r '.engine, .routing.locked_zone_allowed, .routing.review_required_by' \
     bridge/inbox/GEMINI/GEMINI_DRYRUN_*.yaml
   ```

---

## Expected Results

### Metadata Propagation

All of these should be `true`:

- ✅ `engine: gemini` in routed WO
- ✅ `locked_zone_allowed: false` in routed WO
- ✅ `review_required_by: andy` (or `cls`) in routed WO
- ✅ Handler validates WO structure
- ✅ Result includes `engine: gemini` (if handler executed)

### File Locations

- Test WO: `g/tests/gemini_routing/GEMINI_DRYRUN_*.yaml`
- Routed WO: `bridge/inbox/GEMINI/GEMINI_DRYRUN_*.yaml`
- Result: `bridge/outbox/GEMINI/GEMINI_DRYRUN_*_result.yaml` (if handler executed)
- Report: `g/tests/gemini_routing/GEMINI_DRYRUN_*_report.md`

---

## Status

| Component | Status |
|-----------|--------|
| Test Script Created | ✅ |
| Syntax Validated | ✅ |
| Ready to Run | ✅ |

---

**Status:** ✅ **TEST SCRIPT READY — Run to verify routing flow**

The dry-run test script is ready to verify the complete Gemini routing integration flow.
