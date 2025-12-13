# Production Verification Plan — v5 Stack

**Date:** 2025-12-10  
**Status:** 🔄 **Ready for Production Verification**  
**Reference:** Monitor output analysis

---

## Current Status (From Monitor)

**Monitor Output:**
```json
{
  "v5_activity_24h": "v5:0,legacy:0",
  "lane_distribution": {"strict":0,"local":0,"rejected":0},
  "inbox_backlog": {"main":0,"clc":21},
  "error_stats": {"processed":1,"errors":3,"error_rate":75}
}
```

**Analysis:**
- ✅ v5 stack ready (tests passing, code safe)
- ⚠️ No v5 traffic yet (0 activity in 24h)
- ⚠️ Legacy CLC backlog: 21 Work Orders
- ⚠️ Monitor script bug fixed (0\n0 → clean JSON)

---

## Verification Steps

### Step 1: Fix Monitor Script ✅

**Issue:** `grep -c ... || echo "0"` under `set -e` caused `0\n0` in JSON

**Fix Applied:**
- Changed to `grep -q` + `wc -l` pattern
- Clean JSON output now

**Verification:**
```bash
zsh ~/02luka/tools/monitor_v5_production.zsh json
```

---

### Step 2: Archive Legacy CLC Backlog

**Tool:** `tools/archive_legacy_clc_backlog.zsh`

**Usage:**
```bash
# Dry run first
zsh ~/02luka/tools/archive_legacy_clc_backlog.zsh --dry-run

# Actually archive
zsh ~/02luka/tools/archive_legacy_clc_backlog.zsh
```

**What it does:**
- Moves all YAML files from `bridge/inbox/CLC/` to `bridge/archive/CLC/legacy_before_v5/`
- Adds timestamp prefix to avoid conflicts
- Clears backlog for clean monitoring

**Expected Result:**
- `inbox_backlog.clc` → 0
- Legacy WOs archived (not deleted)
- Clean slate for v5 monitoring

---

### Step 3: Test v5 Production Flow

**Tool:** `tools/test_v5_production_flow.zsh`

**Usage:**
```bash
# Create FAST lane test (OPEN zone → LOCAL execution)
zsh ~/02luka/tools/test_v5_production_flow.zsh fast

# Create STRICT lane test (LOCKED zone → CLC)
zsh ~/02luka/tools/test_v5_production_flow.zsh strict

# Create both
zsh ~/02luka/tools/test_v5_production_flow.zsh both
```

**What it does:**
- Creates test Work Orders in `bridge/inbox/MAIN/`
- FAST lane: OPEN zone file (should route to LOCAL)
- STRICT lane: LOCKED zone file (should route to CLC)

**Expected Results:**
1. **FAST Lane:**
   - WO processed immediately
   - File created in `g/reports/`
   - Monitor shows: `lane_distribution.local > 0`
   - Monitor shows: `v5_activity_24h.v5 > 0`

2. **STRICT Lane:**
   - WO routed to CLC inbox
   - Monitor shows: `lane_distribution.strict > 0`
   - Monitor shows: `inbox_backlog.clc` increases
   - CLC Executor processes WO

---

## Verification Checklist

- [ ] **Step 1:** Monitor script fixed and verified
  - [ ] JSON output clean (no `0\n0`)
  - [ ] All fields readable

- [ ] **Step 2:** Legacy backlog archived
  - [ ] Dry run reviewed
  - [ ] Archive executed
  - [ ] `inbox_backlog.clc` → 0

- [ ] **Step 3:** Production flow tested
  - [ ] FAST lane test created
  - [ ] FAST lane processed (LOCAL execution)
  - [ ] STRICT lane test created
  - [ ] STRICT lane routed to CLC
  - [ ] Monitor shows v5 activity

- [ ] **Step 4:** Results documented
  - [ ] Monitor output captured
  - [ ] Lane routing verified
  - [ ] Production ready confirmed

---

## Expected Monitor Output (After Verification)

**After Step 2 (Archive):**
```json
{
  "inbox_backlog": {"main":0,"clc":0}
}
```

**After Step 3 (Test Flow):**
```json
{
  "v5_activity_24h": "v5:2,legacy:0",
  "lane_distribution": {"strict":1,"local":1,"rejected":0},
  "inbox_backlog": {"main":0,"clc":1}
}
```

---

## Status

**Current:** 🔄 **Ready for Verification**

- ✅ Monitor script fixed
- ✅ Archive tool ready
- ✅ Test flow tool ready
- ⏳ Verification pending

**Next:** Execute Steps 2-3 to verify production flow

---

**Last Updated:** 2025-12-10

