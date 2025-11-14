# WO Pipeline Durability - Executive Summary

**Date:** 2025-11-13 23:45  
**Status:** Ready for Execution  
**Recommended Path:** Option D (Sequenced: A → B/C → D)

---

## 📋 Tasks Not Done (From session_20251113_145301.md)

### ❌ Critical (Must Fix Now)

1. **WO Pipeline Components Missing:**
   - `agents/apply_patch_processor/apply_patch_processor.zsh`
   - `agents/json_wo_processor/json_wo_processor.zsh`
   - `agents/wo_executor/wo_executor.zsh`
   - `tools/followup_tracker_update.zsh`
   - `g/followup/state/` directory
   - All 5 LaunchAgents: exit 127 (script not found)

2. **No Forensic Analysis:**
   - Gap investigation: Nov 13 01:50 → 22:43 (21 hours)
   - Rollback log review: Not done
   - Git history check: Not done

3. **No Persistence System:**
   - No guardrail to detect missing components
   - No rollback protection for critical files
   - No durability guarantee

### ⚠️ High Priority (Fix Soon)

4. **Pre-existing Health Issues:**
   - Expense ledger: Missing
   - Roadmap file: Missing
   - Dashboard validation: Failing

5. **Documentation Gaps:**
   - GG WO generation approval: Not documented
   - WO creation pattern (0-1 vs 2+): Not enforced
   - Cursor model setup: Not standardized

---

## 📦 Tasks Not Deployed (But Were Developed)

### ✅ Developed by CLC (Nov 13 01:50) - LOST:
- `apply_patch_processor` - **Was working, now missing**
- 9 WO state files - **All disappeared**
- PATH fixes - **Lost**
- Absolute path fixes - **Lost**

### ✅ Developed by CLS (Nov 13) - DEPLOYED:
- Phase 6 Week 1 (collector, dashboard, digest) - **✅ Active**
- Phase 6 Week 2 (proposal generator) - **✅ Active**
- MLS Cursor Watcher - **✅ Active**
- Session save system - **✅ Active**
- WO status checker - **✅ Active**

### ⚠️ Partially Deployed:
- WO creation pattern - **Documented, not automated**
- Dashboard improvements - **Some fixes not applied**

### ❌ Not Yet Deployed:
- Guardrail system - **Doesn't exist**
- Protected rollback - **Not implemented**
- History-aware diagnosis - **Not implemented**
- SSOT tree unification - **Not started**

---

## 🎯 Recommended Path: Option D (Sequenced)

**Your Wisdom:** "D, but sequenced"

**Translation:** Do all three (A+B+C), but in smart order with time limits

---

### Step 1: Time-Boxed Forensics (A, max 10-15 min)

**Goal:** Just enough to know how it died, not a crime novel

**What to Check:**

1. **Git history** (5 min)
   ```bash
   git log --oneline --since="2025-11-13 01:50" --until="2025-11-13 22:43"
   git log -p --all --full-history -- agents/apply_patch_processor/
   ```
   - Look for: hard resets, checkouts, big reversions

2. **Rollback scripts** (5 min)
   ```bash
   grep -l "agents/apply_patch_processor\|g/followup/state" tools/rollback_*.zsh
   cat tools/rollback_phase6_week1_20251113.zsh
   ```
   - Look for: Scripts that touch those paths

3. **LaunchAgent logs** (5 min)
   ```bash
   ls -lht ~/Library/Logs/*apply_patch*
   grep "exit 127\|command not found" ~/Library/Logs/*.log
   ```
   - Look for: First "file not found" timestamp

**Stop After 15 Minutes:**
- If smoking gun found → Document and move on
- If nothing clear → Accept "cause: rollback/tree mismatch" and move on

**Deliverable:**
- `g/reports/forensic_wo_pipeline_20251113.json`
- MLS entry with findings

---

### Step 2: Decide Restore vs Rebuild (B vs C)

**Your Call:** **Rebuild (C) as main path, Restore (B) as reference**

**Why?**

✅ **Use CLC's script as design spec:**
- We know it worked
- We have the full pattern (from clc_251112.txt lines 362-540)
- It's proven successful

✅ **But rebuild, don't blind copy:**
- Encode as official WO with tests
- Add state tracking
- Add telemetry
- Add MLS integration
- Make reproducible

**Approach:**
1. Create WO: `WO-20251113-WO-PIPELINE-REBUILD.yaml`
2. Include 4 processors + LaunchAgents + state dir
3. Add canary WO for end-to-end test
4. CLC processes the WO
5. Verify all components installed & running

**Time:** 60-90 minutes

**Deliverable:**
- Working WO pipeline
- All 4 LaunchAgents running
- Canary test passes
- Dashboard shows WOs

---

### Step 3: Add Persistence Monitoring (The Protection Layer)

**Once pipeline is back up:**

#### 3.1 Guardrail Script (LaunchAgent, runs every 5 min)

**Checks:**
- `agents/apply_patch_processor/apply_patch_processor.zsh` exists & executable
- `agents/json_wo_processor/json_wo_processor.zsh` exists & executable
- `agents/wo_executor/wo_executor.zsh` exists & executable
- `g/followup/state/` directory exists

**If missing:**
- Log telemetry: `{"event":"wo_pipeline_drift","missing":"..."}`
- Log alert: `~/02luka/logs/guardrail_alerts.log`
- Optional: Auto-drop repair WO

**If healthy:**
- Log heartbeat: `{"event":"wo_pipeline_healthy"}`

#### 3.2 Simple End-to-End Test

**Canary WO:**
- Drop tiny dummy WO
- Confirm:
  - State file created in `g/followup/state/`
  - Telemetry entry written
  - Dashboard shows +1 item

**Why This Matters:**
> "If this guardrail existed before, CLC's work being erased would have raised a big red flag instead of silently vanishing."

**Time:** 30-45 minutes

**Deliverable:**
- Guardrail running every 5 min
- Healthy heartbeats logged
- Alert test successful

---

### Step 4: History-Aware Diagnosis (Future CLS Improvements)

**Goal:** CLS never says "doesn't exist" without checking history first

**Pattern:**

**Before:**
```
1. Check filesystem
2. Report current state
3. Propose fix
```

**After:**
```
1. Check filesystem (current state)
2. Check history:
   - Git log (last 24h)
   - MLS entries (relevant tags)
   - Rollback logs
3. Determine:
   - Never existed → Create from scratch
   - Existed, vanished → When? Why? → Restore/rebuild
   - Exists but broken → Fix in place
4. Report: "Current + History"
5. Propose fix (informed by history)
```

**Tool:** `tools/check_component_history.zsh`

**Time:** 30 minutes

**Deliverable:**
- History check utility
- Updated CLS diagnostic pattern

---

## 📊 Total Timeline

| Phase | Time | When |
|-------|------|------|
| **Step 1: Forensics** | 10-15 min | Tonight (Nov 13 23:45) |
| **Step 2: Rebuild** | 60-90 min | Tonight (Nov 13 23:55) or Tomorrow morning |
| **Step 3: Guardrail** | 30-45 min | Tomorrow (Nov 14 08:00) |
| **Step 4: History-Aware** | 30 min | Tomorrow (Nov 14 08:45) |
| **Total** | ~3 hours | Split over 2 sessions |

---

## ✅ Success Criteria

### After Step 1 (Forensics):
- ✅ Know what happened (or documented "unknown")
- ✅ MLS entry with findings

### After Step 2 (Rebuild):
- ✅ All 4 processors running
- ✅ 0 LaunchAgent exit 127 errors
- ✅ Canary WO completes
- ✅ Dashboard shows WOs

### After Step 3 (Guardrail):
- ✅ Heartbeat every 5 min
- ✅ Alert within 5 min of simulated drift
- ✅ No false positives in 24h

### After Step 4 (History-Aware):
- ✅ CLS checks history before diagnosis
- ✅ Reports "worked, then broke" when true

---

## 🔄 Rollback Plan

### If Rebuild Fails:
```bash
# Unload LaunchAgents
launchctl unload ~/Library/LaunchAgents/com.02luka.*.plist

# Remove new files (move directories to trash; no destructive shell commands)
# - ~/02luka/agents/apply_patch_processor
# - ~/02luka/agents/json_wo_processor
# - ~/02luka/agents/wo_executor

# Clear state (trash the JSON files in followup/state)
```

### If Guardrail Causes Issues:
```bash
launchctl unload ~/Library/LaunchAgents/com.02luka.wo_pipeline_guardrail.plist
```

---

## 🎯 The Root Problem (Your Diagnosis)

### What You Said:

> "The real problem is:
> 1. No reliable 'don't roll back critical agent installs without snapshot' guard
> 2. Multiple trees/rollbacks without central SSOT
> 3. CLS didn't look at history before declaring 'pipeline doesn't exist'"

> "CLC fixed and verified → I expect that to stay true unless I explicitly undo it."
> **Right now, that guarantee does not exist.**

### What We're Fixing:

1. **Guardrail** → Detects drift within 5 min
2. **Protected rollback** → Critical files need --force
3. **History-aware diagnosis** → CLS checks history first

### What We're NOT Fixing (Yet):

- Multiple trees unification (Phase 5, future work)
- Complete backup/restore (Phase 6, future work)
- Git workflow changes (Phase 7, future work)

---

<!-- Sanitized for Codex Sandbox Mode (2025-11) -->

## 📝 Key Insight

### The Pattern You Identified:

```
"Agent A: fixed ✅" 
→ some hours/tools later → 
"Agent B: but it's broken now ❌"
```

### Root Cause:

> "The fix was not made durable (not committed / not protected from rollback / not unified across trees)."

### Solution:

**Durability Guarantee = Guardrail + Protected Rollback + Tests + SSOT**

---

## 🚀 Ready to Execute

**Documents Created:**
- ✅ `feature_wo_pipeline_durability_SPEC.md` - Complete specification
- ✅ `feature_wo_pipeline_durability_PLAN.md` - Detailed task breakdown
- ✅ `WO_PIPELINE_DURABILITY_SUMMARY.md` - This executive summary

**Next Action:**
- Approve this plan
- Create WO for execution (4 phases = create WO, follows 0-1 vs 2+ rule)
- Begin Step 1: Forensics (10-15 min)

**Expected Completion:** Nov 14, 09:30

---

**Your Wisdom Applied:**
- ✅ Time-boxed forensics (not a crime novel)
- ✅ Rebuild (not blind restore)
- ✅ Guardrail (the protection layer)
- ✅ Sequenced execution (A → B/C → D)

**The Guarantee You Want:**
> "CLC fixed it → stays fixed"

**We're Building That Now.** 🛡️
