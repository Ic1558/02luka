# Code Review: MLS Auto-Prompt Capture - Recommended Approach

**Review Date:** 2025-11-13  
**Reviewer:** CLS (Code Review Mode)  
**Feature:** `mls_auto_prompt_capture`  
**Files Reviewed:**
- `g/reports/feature_mls_auto_prompt_capture_SPEC.md`
- `g/reports/feature_mls_auto_prompt_capture_PLAN.md`
- `tools/mls_cursor_hook.zsh` (existing)

---

## Style Check

### ✅ Strengths
- **Clear structure**: SPEC and PLAN follow established patterns
- **Comprehensive requirements**: Functional and non-functional requirements well-defined
- **Good documentation**: Open questions, risks, and mitigations documented
- **Consistent naming**: Follows codebase conventions (`mls_*`, `com.02luka.*`)

### ⚠️ Issues Found

**1. SPEC Data Schema Mismatch**
```json
// SPEC shows:
"source": {
  "producer": "cursor",  // ❌ Should be "clc" or "cls"?
  "context": "conversation",
  ...
}
```
**Issue:** `mls_auto_record.zsh` uses `--producer "clc"` by default. Need consistency.

**2. Hook Script Incomplete**
```zsh
# tools/mls_cursor_hook.zsh line 41
sqlite3 "$db_file" "SELECT * FROM ItemTable WHERE key LIKE '%chat%' ..."
```
**Issue:** Query is exploratory and may not work. No error handling for schema differences.

**3. PLAN Missing Workspace Detection**
- Plan doesn't specify how to identify `~/02luka` workspace vs other workspaces
- Multiple `state.vscdb` files exist (one per workspace)
- Need to match workspace hash to `~/02luka` path

---

## History-Aware Review

### ✅ Matches Existing Patterns

**1. LaunchAgent Pattern** ✅
- Matches `com.02luka.cls.wo.cleanup.plist` structure
- Uses `ThrottleInterval: 30` (consistent with other agents)
- Log paths follow convention: `logs/mls_cursor_watcher.log`

**2. File Watcher Pattern** ✅
- Similar to `bridge_monitor.sh` (monitors directory, processes files)
- Uses polling interval (30 seconds) vs continuous monitoring
- Follows existing watcher patterns in codebase

**3. MLS Integration** ✅
- Uses `mls_auto_record.zsh` correctly
- Follows MLS Ledger format (not MLS Lessons)
- Tags format matches existing entries

### ⚠️ Deviations from Patterns

**1. SQLite Query Pattern Missing**
- No existing SQLite monitoring scripts in codebase
- `rag_index_federation.zsh` uses SQLite but for different purpose
- Need to establish pattern for SQLite file monitoring

**2. State File Management**
- Plan mentions state file for deduplication but doesn't specify location
- Should follow pattern: `memory/cls/mls_cursor_watcher_state.json`
- Need atomic writes to prevent corruption

**3. Error Handling Pattern**
- Existing scripts use `|| true` for non-blocking failures
- Plan mentions retry logic but doesn't specify retry count/backoff
- Should match `bridge_monitor.sh` error handling pattern

---

## Obvious Bug Scan

### 🔴 Critical Issues

**1. Workspace Identification Missing**
```zsh
# PLAN Task 1.1: "Locate active workspace storage directory"
# But HOW? Multiple workspaces exist!
```
**Bug:** Cannot determine which `state.vscdb` belongs to `~/02luka` workspace.

**Fix Required:**
- Need to map workspace hash to workspace path
- Check `workspaceStorage/*/workspace.json` or similar
- Or query database for workspace path metadata

**2. SQLite Schema Unknown**
```zsh
# SPEC mentions: "Requires SQLite schema knowledge"
# But schema is completely unknown!
```
**Bug:** Plan assumes we can query conversations, but schema is undocumented.

**Fix Required:**
- Phase 1 MUST discover schema before proceeding
- Need fallback if schema doesn't support conversation extraction
- Consider Option C (Session Summary) as backup

**3. Database Lock Handling Incomplete**
```zsh
# PLAN mentions: "Retry logic with exponential backoff"
# But no implementation details!
```
**Bug:** SQLite locks are common. Plan doesn't specify:
- How many retries?
- What backoff strategy?
- How to detect lock vs other errors?

**Fix Required:**
- Specify retry count (e.g., 3 retries)
- Exponential backoff: 1s, 2s, 4s
- Detect `SQLITE_BUSY` error specifically

### ⚠️ Medium Issues

**4. Deduplication Strategy Vague**
```zsh
# PLAN: "Track last processed timestamp in state file"
# But what if conversations have no timestamp?
```
**Issue:** Need to identify unique conversation ID, not just timestamp.

**5. Performance Impact Unmeasured**
```zsh
# SPEC: "File watcher must be lightweight (< 1% CPU)"
# But no baseline measurement plan!
```
**Issue:** Should measure current Cursor CPU usage first, then verify impact.

**6. Privacy Filter Missing**
```zsh
# SPEC: "Only capture conversations in ~/02luka workspace"
# But how to filter?
```
**Issue:** Need to verify workspace path before recording.

---

## Risk Analysis

### 🔴 High Risk

**1. Schema Discovery Failure**
- **Risk:** Cursor SQLite schema doesn't support conversation extraction
- **Impact:** Entire approach fails, need to pivot to Option C
- **Mitigation:** ✅ Plan includes Phase 1 investigation (good!)
- **Recommendation:** Add explicit "go/no-go" decision point after Phase 1

**2. Database Corruption Risk**
- **Risk:** Concurrent reads during Cursor writes could corrupt database
- **Impact:** Cursor crashes or data loss
- **Mitigation:** ✅ Plan mentions lock handling
- **Recommendation:** Use `PRAGMA read_uncommitted` or read-only mode

**3. Performance Impact**
- **Risk:** 30-second SQLite queries impact Cursor performance
- **Impact:** User experience degradation
- **Mitigation:** ✅ Plan includes performance monitoring
- **Recommendation:** Measure baseline first, set alert threshold

### ⚠️ Medium Risk

**4. False Positives**
- **Risk:** File modification time changes but no new conversations
- **Impact:** Unnecessary processing, wasted CPU
- **Mitigation:** ✅ Deduplication logic
- **Recommendation:** Add hash-based change detection

**5. State File Corruption**
- **Risk:** State file corrupted, causes duplicate entries
- **Impact:** MLS Ledger pollution
- **Mitigation:** ✅ Plan mentions corruption handling
- **Recommendation:** Use atomic writes, add checksum validation

---

## Diff Hotspots

### Areas Requiring Careful Implementation

**1. SQLite Query Construction**
```zsh
# This will be the most critical code:
sqlite3 "$db_file" "SELECT ... WHERE ..."
```
**Risk:** SQL injection if conversation data contains SQL
**Fix:** Use parameterized queries or escape input

**2. State File Updates**
```zsh
# Race condition risk:
echo "$last_timestamp" > "$state_file"
```
**Risk:** Concurrent writes corrupt state file
**Fix:** Use atomic write pattern: `mv temp_file state_file`

**3. MLS Recording Integration**
```zsh
# Need to ensure proper error handling:
"$BASE/tools/mls_auto_record.zsh" ... || true
```
**Risk:** Silent failures if MLS recording fails
**Fix:** Log failures but don't block watcher

---

## Recommendations

### ✅ Must Fix Before Implementation

1. **Add Workspace Detection Logic**
   - Map workspace hash to workspace path
   - Verify workspace is `~/02luka` before processing
   - Add to Phase 1 Task 1.1

2. **Specify Schema Discovery Fallback**
   - Add explicit "go/no-go" decision after Phase 1
   - If schema doesn't support extraction, pivot to Option C
   - Document fallback criteria

3. **Complete Error Handling Spec**
   - Specify retry count (3 retries)
   - Specify backoff strategy (1s, 2s, 4s)
   - Specify lock detection (`SQLITE_BUSY` error code)

4. **Fix Data Schema Consistency**
   - Change `"producer": "cursor"` to `"producer": "clc"` or `"cls"`
   - Match `mls_auto_record.zsh` defaults

### ⚠️ Should Fix

5. **Add State File Location**
   - Specify: `memory/cls/mls_cursor_watcher_state.json`
   - Add atomic write pattern
   - Add checksum validation

6. **Add Performance Baseline**
   - Measure Cursor CPU usage before implementation
   - Set alert threshold (e.g., > 2% CPU increase)
   - Add to Phase 4 testing

7. **Complete Deduplication Strategy**
   - Specify conversation ID extraction method
   - Handle conversations without timestamps
   - Add hash-based deduplication fallback

---

## Final Verdict

### ⚠️ **APPROVED WITH CONDITIONS**

**Overall Assessment:**
- ✅ **Architecture:** Sound approach, matches codebase patterns
- ✅ **Planning:** Comprehensive, well-structured
- ⚠️ **Implementation Readiness:** Missing critical details

**Critical Blockers:**
1. Workspace identification logic not specified
2. SQLite schema discovery has no fallback plan
3. Error handling incomplete (retry strategy missing)

**Recommendation:**
- **Proceed with implementation** after addressing critical blockers
- **Add Phase 1.5:** "Go/No-Go Decision" after schema discovery
- **Update SPEC** with workspace detection and error handling details
- **Update PLAN** with explicit retry strategy and state file location

**Confidence Level:** 75% (will increase to 90% after addressing blockers)

---

## Next Steps

1. ✅ **Update SPEC** with workspace detection logic
2. ✅ **Update PLAN** with retry strategy and state file details
3. ✅ **Add Phase 1.5** go/no-go decision point
4. ⏳ **Start Phase 1** investigation (after SPEC/PLAN updates)

---

**Review Status:** ⚠️ **CONDITIONAL APPROVAL** - Address critical blockers before implementation
