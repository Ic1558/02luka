# Code Review v2: MLS Auto-Prompt Capture - Updated SPEC/PLAN

**Review Date:** 2025-11-13  
**Reviewer:** CLS (Code Review Mode)  
**Feature:** `mls_auto_prompt_capture`  
**Version:** v2 (Post-Update Review)  
**Files Reviewed:**
- `g/reports/feature_mls_auto_prompt_capture_SPEC.md` (updated)
- `g/reports/feature_mls_auto_prompt_capture_PLAN.md` (updated)

---

## Review Summary

**Previous Review:** ⚠️ **CONDITIONAL APPROVAL** (75% confidence)  
**This Review:** ✅ **FULL APPROVAL** (90% confidence)

---

## Changes Verified

### ✅ Must Fix Items - ALL ADDRESSED

**1. Workspace Detection Logic** ✅ **FIXED**
- ✅ Added to Phase 1 Task 1.1: "Map workspace hash to workspace path"
- ✅ SPEC NFR3: "Workspace Detection" section added with implementation details
- ✅ Includes: Check `workspace.json`, query database, verify `~/02luka` path
- **Status:** Complete

**2. Phase 1.5 Go/No-Go Decision Point** ✅ **ADDED**
- ✅ New Phase 1.5: "Go/No-Go Decision Point" (15-30 minutes)
- ✅ Task 1.5.1: Schema Feasibility Assessment
- ✅ Task 1.5.2: Decision Point with clear criteria
- ✅ Fallback to Option C if schema doesn't support extraction
- **Status:** Complete

**3. Error Handling Spec** ✅ **COMPLETED**
- ✅ SPEC Risk Mitigation: "Retry logic: 3 attempts with exponential backoff (1s, 2s, 4s)"
- ✅ SPEC Implementation: "Detect `SQLITE_BUSY` error code specifically"
- ✅ PLAN Task 2.1: Detailed error handling checklist
- ✅ Includes: Retry count, backoff strategy, lock detection, `PRAGMA read_uncommitted`
- **Status:** Complete

**4. Data Schema Consistency** ✅ **FIXED**
- ✅ SPEC Data Schema: Changed `"producer": "cursor"` → `"producer": "clc"`
- ✅ Matches `mls_auto_record.zsh` defaults
- **Status:** Complete

### ✅ Should Fix Items - ALL ADDRESSED

**5. State File Location** ✅ **SPECIFIED**
- ✅ SPEC FR5: "Track last recorded timestamp in state file: `memory/cls/mls_cursor_watcher_state.json`"
- ✅ PLAN Task 2.3: "State File: `memory/cls/mls_cursor_watcher_state.json`"
- ✅ Includes: Atomic write pattern (`mv temp_file state_file`)
- ✅ Includes: Checksum validation
- **Status:** Complete

**6. Performance Baseline** ✅ **ADDED**
- ✅ SPEC NFR1: "Baseline Measurement Required: Measure Cursor CPU usage before implementation"
- ✅ SPEC NFR1: "Alert Threshold: Alert if CPU increase > 2% during testing"
- ✅ PLAN Task 4.2: "Performance Baseline: Measure Cursor CPU usage before watcher"
- ✅ PLAN Task 4.2: "Performance Impact: Measure CPU usage with watcher active"
- ✅ PLAN Task 4.2: "Verify CPU increase < 1% (alert threshold: 2%)"
- **Status:** Complete

**7. Deduplication Strategy** ✅ **COMPLETED**
- ✅ SPEC FR5: Multi-strategy approach (ID → timestamp → hash)
- ✅ PLAN Task 2.3: "Extract conversation ID from SQLite (if available)"
- ✅ PLAN Task 2.3: "Generate hash of conversation content (fallback)"
- ✅ PLAN Task 2.3: "Compare conversation IDs/timestamps/hashes"
- ✅ Includes: Atomic writes, checksum validation, corruption handling
- **Status:** Complete

---

## Style Check

### ✅ Strengths Maintained
- Clear structure and organization
- Comprehensive requirements
- Consistent naming conventions
- Good documentation

### ✅ Improvements Made
- All critical blockers addressed
- Error handling now fully specified
- Workspace detection logic clear
- Performance baseline included
- Deduplication strategy complete

---

## History-Aware Review

### ✅ Matches Existing Patterns

**1. LaunchAgent Pattern** ✅
- Matches `com.02luka.cls.wo.cleanup.plist` structure
- Uses `ThrottleInterval: 30`
- Log paths follow convention

**2. File Watcher Pattern** ✅
- Similar to `bridge_monitor.sh`
- Polling interval (30 seconds)
- Error handling with `|| true` pattern

**3. State File Pattern** ✅
- Location: `memory/cls/` (matches other CLS state files)
- Atomic writes: `mv temp_file state_file` (matches codebase patterns)
- Checksum validation (defensive programming)

**4. Error Handling Pattern** ✅
- Retry logic matches existing patterns
- Exponential backoff standard approach
- Non-blocking failures (`|| true`)

---

## Obvious Bug Scan

### ✅ Critical Issues - ALL RESOLVED

**1. Workspace Identification** ✅ **RESOLVED**
- ✅ Phase 1 Task 1.1 includes workspace detection
- ✅ SPEC NFR3 specifies workspace filtering
- ✅ Clear implementation path documented

**2. SQLite Schema Unknown** ✅ **RESOLVED**
- ✅ Phase 1.5 go/no-go decision point added
- ✅ Fallback to Option C if schema doesn't support extraction
- ✅ Clear decision criteria documented

**3. Database Lock Handling** ✅ **RESOLVED**
- ✅ Retry strategy: 3 attempts, 1s/2s/4s backoff
- ✅ Lock detection: `SQLITE_BUSY` error code
- ✅ `PRAGMA read_uncommitted` for read-only queries

### ✅ Medium Issues - ALL RESOLVED

**4. Deduplication Strategy** ✅ **RESOLVED**
- ✅ Multi-strategy: ID → timestamp → hash
- ✅ Handles conversations without timestamps
- ✅ Hash-based fallback included

**5. Performance Impact** ✅ **RESOLVED**
- ✅ Baseline measurement required
- ✅ Alert threshold specified (2%)
- ✅ Performance testing in Phase 4

**6. Privacy Filter** ✅ **RESOLVED**
- ✅ Workspace detection logic specified
- ✅ Verify `~/02luka` path before processing
- ✅ Clear implementation path

---

## Risk Analysis

### ✅ High Risk Items - MITIGATED

**1. Schema Discovery Failure** ✅ **MITIGATED**
- ✅ Phase 1.5 go/no-go decision point
- ✅ Fallback to Option C documented
- ✅ Clear decision criteria

**2. Database Corruption Risk** ✅ **MITIGATED**
- ✅ `PRAGMA read_uncommitted` for read-only queries
- ✅ Retry logic with lock detection
- ✅ Skip if locked (non-blocking)

**3. Performance Impact** ✅ **MITIGATED**
- ✅ Baseline measurement required
- ✅ Alert threshold specified
- ✅ Performance testing in Phase 4

### ✅ Medium Risk Items - MITIGATED

**4. False Positives** ✅ **MITIGATED**
- ✅ Deduplication with multiple strategies
- ✅ Hash-based change detection (fallback)

**5. State File Corruption** ✅ **MITIGATED**
- ✅ Atomic writes (`mv temp_file state_file`)
- ✅ Checksum validation
- ✅ Corruption handling (reset if invalid)

---

## Diff Hotspots

### ✅ Areas Requiring Careful Implementation - ALL ADDRESSED

**1. SQLite Query Construction** ✅
- ✅ Use parameterized queries or escape input
- ✅ `PRAGMA read_uncommitted` for read-only
- ✅ Error handling for SQL injection

**2. State File Updates** ✅
- ✅ Atomic write pattern: `mv temp_file state_file`
- ✅ Checksum validation
- ✅ Corruption handling

**3. MLS Recording Integration** ✅
- ✅ Use `mls_auto_record.zsh` (existing infrastructure)
- ✅ Error handling: `|| true` for non-blocking
- ✅ Log failures but don't block watcher

---

## Remaining Considerations

### ⚠️ Minor Items (Not Blockers)

**1. SQLite Query Implementation**
- **Note:** Actual query syntax will depend on schema discovery
- **Mitigation:** Phase 1.5 go/no-go decision ensures feasibility
- **Status:** Acceptable - will be resolved in Phase 1

**2. Workspace Hash Mapping**
- **Note:** Exact method depends on Cursor's storage structure
- **Mitigation:** Phase 1 Task 1.1 includes investigation
- **Status:** Acceptable - will be resolved in Phase 1

**3. Conversation ID Extraction**
- **Note:** Depends on SQLite schema structure
- **Mitigation:** Fallback to hash-based deduplication
- **Status:** Acceptable - fallback strategy in place

---

## Final Verdict

### ✅ **FULL APPROVAL**

**Overall Assessment:**
- ✅ **Architecture:** Sound approach, matches codebase patterns
- ✅ **Planning:** Comprehensive, well-structured, all blockers addressed
- ✅ **Implementation Readiness:** Ready for implementation

**Critical Blockers:** ✅ **ALL RESOLVED**
1. ✅ Workspace identification logic specified
2. ✅ SQLite schema discovery has fallback plan (Phase 1.5)
3. ✅ Error handling complete (retry strategy specified)

**Recommendation:**
- ✅ **Proceed with implementation** - All critical blockers addressed
- ✅ **Start Phase 1** - Investigation and schema discovery
- ✅ **Follow Phase 1.5** - Go/no-go decision point
- ✅ **Monitor performance** - Baseline measurement required

**Confidence Level:** 90% (increased from 75%)

**Remaining 10% Uncertainty:**
- SQLite schema structure (will be resolved in Phase 1)
- Workspace hash mapping method (will be resolved in Phase 1)
- Actual query performance (will be measured in Phase 1.5)

---

## Comparison: v1 vs v2

| Item | v1 Status | v2 Status |
|------|-----------|-----------|
| Workspace Detection | ❌ Missing | ✅ Complete |
| Phase 1.5 Go/No-Go | ❌ Missing | ✅ Added |
| Error Handling Spec | ⚠️ Incomplete | ✅ Complete |
| Data Schema Consistency | ❌ Wrong | ✅ Fixed |
| State File Location | ❌ Unspecified | ✅ Specified |
| Performance Baseline | ❌ Missing | ✅ Added |
| Deduplication Strategy | ⚠️ Vague | ✅ Complete |
| **Overall Confidence** | **75%** | **90%** |

---

## Next Steps

1. ✅ **SPEC/PLAN Updated** - All blockers addressed
2. ✅ **Code Review Complete** - Full approval granted
3. ⏳ **Start Phase 1** - Investigation and schema discovery
4. ⏳ **Execute Phase 1.5** - Go/no-go decision point
5. ⏳ **Proceed with Implementation** - Based on Phase 1.5 decision

---

**Review Status:** ✅ **FULL APPROVAL** - Ready for implementation

**Answer to "Is this solved?":** ❌ **NO** - But SPEC/PLAN is now **READY FOR IMPLEMENTATION** with all critical blockers addressed.
