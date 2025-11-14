# Feature Plan: MLS Auto-Capture for Training Prompts & Conversations

**Feature ID:** `mls_auto_prompt_capture`  
**Date:** 2025-11-13  
**Status:** 📋 **PLAN**  
**Priority:** 🔴 **P1 - CRITICAL**

---

## Overview

**Time Estimate:** 1-2 working days (6-10 hours)  
**Approach:** File watcher on Cursor SQLite database (Option A)  
**Strategy:** Non-invasive monitoring, leverage existing MLS infrastructure

---

## Task Breakdown

### Phase 1: Investigation & Schema Discovery (1-2 hours)

**Goal:** Understand Cursor storage structure and conversation format

#### Task 1.1: Analyze Cursor SQLite Schema & Workspace Detection
- [ ] Locate all workspace storage directories (`workspaceStorage/*/`)
- [ ] **Workspace Detection:** Map workspace hash to workspace path
  - Check for `workspace.json` or similar metadata files
  - Query database for workspace path metadata if available
  - Identify which `state.vscdb` belongs to `~/02luka` workspace
  - Document workspace identification method
- [ ] Inspect `state.vscdb` schema (tables, columns) for `~/02luka` workspace
- [ ] Identify conversation storage format
- [ ] Document schema findings
- [ ] Test queries to extract conversations
- [ ] Verify workspace filtering works correctly
- **Deliverable:** Schema documentation + working query + workspace detection logic

#### Task 1.2: Test Conversation Extraction
- [ ] Create test script: `tools/test_cursor_extraction.zsh`
- [ ] Query recent conversations from database
- [ ] Parse conversation format (JSON/text)
- [ ] Extract prompt and response pairs
- [ ] Verify data structure
- **Deliverable:** Working extraction script

**Phase 1 Deliverables:**
- Cursor schema documented
- Workspace detection logic implemented
- Working conversation extraction
- Test script verified

---

### Phase 1.5: Go/No-Go Decision Point (15-30 minutes)

**Goal:** Evaluate feasibility and decide whether to proceed with Option A or pivot

#### Task 1.5.1: Schema Feasibility Assessment
- [ ] Evaluate if SQLite schema supports conversation extraction
- [ ] Test conversation extraction with real data
- [ ] Measure query performance (< 1 second requirement)
- [ ] Document any schema limitations or blockers
- **Deliverable:** Feasibility assessment report

#### Task 1.5.2: Decision Point
- [ ] **If schema supports extraction:** Proceed to Phase 2 (Option A)
- [ ] **If schema doesn't support extraction:** Pivot to Option C (Session Summary)
- [ ] Document decision and rationale
- **Decision Criteria:**
  - ✅ Can extract conversations from SQLite → Proceed Option A
  - ❌ Cannot extract conversations → Pivot Option C
  - ⚠️ Partial extraction possible → Evaluate trade-offs

**Phase 1.5 Deliverables:**
- Go/No-Go decision documented
- Clear path forward (Option A or Option C)

---

### Phase 2: Core Watcher Implementation (2-3 hours)

**Goal:** Build file watcher that monitors and captures conversations

#### Task 2.1: Create MLS Cursor Watcher Script
- [ ] Create `tools/mls_cursor_watcher.zsh`
- [ ] Implement workspace detection (from Phase 1.1)
- [ ] Implement file modification time tracking
- [ ] Add SQLite query for new conversations (with `PRAGMA read_uncommitted`)
- [ ] **Error Handling:**
  - Retry logic: 3 attempts with exponential backoff (1s, 2s, 4s)
  - Detect `SQLITE_BUSY` error code specifically
  - Skip if locked (will catch on next run)
  - Handle missing files gracefully
- [ ] Integrate with `mls_auto_record.zsh`
- [ ] Add logging to `logs/mls_cursor_watcher.log`
- **Deliverable:** Working watcher script with robust error handling

#### Task 2.2: Implement Conversation Parser
- [ ] Parse conversation data from SQLite
- [ ] Extract prompt text (user message)
- [ ] Extract response text (AI message)
- [ ] Extract metadata (timestamp, session ID)
- [ ] Format for MLS Ledger entry
- [ ] Handle edge cases (empty conversations, malformed data)
- **Deliverable:** Conversation parser function

#### Task 2.3: Add Deduplication Logic
- [ ] **State File:** `memory/cls/mls_cursor_watcher_state.json`
- [ ] Extract conversation ID from SQLite (if available)
- [ ] Track last processed timestamp in state file
- [ ] Generate hash of conversation content (fallback if no ID)
- [ ] Compare conversation IDs/timestamps/hashes
- [ ] Skip already-recorded conversations
- [ ] **Atomic Write:** Use `mv temp_file state_file` pattern
- [ ] Add checksum validation for state file
- [ ] Handle state file corruption gracefully (reset if invalid)
- **Deliverable:** Deduplication working with multiple strategies

**Phase 2 Deliverables:**
- Watcher script operational
- Conversations extracted and parsed
- Deduplication prevents duplicates
- Error handling robust

---

### Phase 3: LaunchAgent & Automation (1 hour)

**Goal:** Schedule watcher to run automatically

#### Task 3.1: Create LaunchAgent
- [ ] Create `LaunchAgents/com.02luka.mls.cursor.watcher.plist`
- [ ] Configure to run every 30 seconds (StartInterval)
- [ ] Set ThrottleInterval: 30
- [ ] Configure log paths (stdout/stderr)
- [ ] Set environment variables (LUKA_SOT, PATH)
- [ ] Test plist validation
- **Deliverable:** Valid LaunchAgent plist

#### Task 3.2: Create Installer Script
- [ ] Create `tools/install_mls_cursor_watcher.zsh`
- [ ] Copy plist to `~/Library/LaunchAgents/`
- [ ] Validate plist with `plutil`
- [ ] Load LaunchAgent with `launchctl`
- [ ] Verify LaunchAgent loaded
- [ ] Add uninstall option
- **Deliverable:** Installer script

**Phase 3 Deliverables:**
- LaunchAgent created and installed
- Watcher runs automatically every 30 seconds
- Logs configured correctly

---

### Phase 4: Testing & Validation (1-2 hours)

**Goal:** Verify system works end-to-end

#### Task 4.1: Manual Testing
- [ ] Start watcher manually
- [ ] Create test conversation in Cursor
- [ ] Wait for watcher to detect
- [ ] Verify entry in MLS Ledger
- [ ] Check deduplication (run twice, verify single entry)
- [ ] Test error handling (lock database, verify graceful failure)
- **Deliverable:** Manual test results documented

#### Task 4.2: Integration Testing & Performance Baseline
- [ ] **Performance Baseline:** Measure Cursor CPU usage before watcher
- [ ] Install LaunchAgent
- [ ] Verify watcher runs automatically
- [ ] Create multiple conversations
- [ ] Verify all captured in MLS Ledger
- [ ] Check logs for errors
- [ ] **Performance Impact:** Measure CPU usage with watcher active
- [ ] Verify CPU increase < 1% (alert threshold: 2%)
- [ ] Document performance metrics
- **Deliverable:** Integration test passing + performance baseline documented

#### Task 4.3: Edge Case Testing
- [ ] Test with empty database
- [ ] Test with locked database
- [ ] Test with missing state file
- [ ] Test with corrupted state file
- [ ] Test with very long conversations
- [ ] Test with multiple workspaces
- **Deliverable:** Edge cases handled gracefully

**Phase 4 Deliverables:**
- All tests passing
- System handles edge cases
- No regressions

---

### Phase 5: Documentation & Delivery (1 hour)

**Goal:** Document solution and verify completion

#### Task 5.1: Update Documentation
- [ ] Update `g/manuals/CURSOR_CLS_SETUP.md` with watcher info
- [ ] Document watcher in `02luka.md`
- [ ] Add troubleshooting section
- [ ] Document configuration options
- **Deliverable:** Updated documentation

#### Task 5.2: Create Delivery Report
- [ ] Create `g/reports/feature_mls_auto_prompt_capture_DELIVERED.md`
- [ ] Document all deliverables
- [ ] Include test results
- [ ] List files created/modified
- [ ] Record to MLS Ledger
- **Deliverable:** Delivery report

**Phase 5 Deliverables:**
- Documentation updated
- Delivery report complete
- Feature marked as complete

---

## Test Strategy

### Unit Tests
- [ ] Conversation parser handles valid data
- [ ] Conversation parser handles invalid data
- [ ] Deduplication logic works correctly
- [ ] Error handling prevents crashes

### Integration Tests
- [ ] Watcher detects new conversations
- [ ] Conversations recorded to MLS Ledger
- [ ] Deduplication prevents duplicates
- [ ] LaunchAgent runs automatically

### System Tests
- [ ] Real conversations captured automatically
- [ ] No performance impact on Cursor
- [ ] System handles database locks
- [ ] Logs contain useful information

---

## Risk Mitigation

**Risk:** SQLite schema unknown or changes  
**Mitigation:** 
- Document schema in Phase 1
- Use defensive queries
- Handle schema errors gracefully
- Fallback to alternative methods if needed

**Risk:** Database locked during writes  
**Mitigation:**
- Retry logic with exponential backoff
- Skip if locked (will catch on next run)
- Log warnings but don't fail

**Risk:** Performance impact  
**Mitigation:**
- 30-second check interval (not continuous)
- Lightweight queries (only new entries)
- Background process (doesn't block Cursor)
- Monitor CPU usage in testing

**Risk:** Privacy concerns  
**Mitigation:**
- Only capture `~/02luka` workspace conversations
- Store locally only
- No external transmission
- User can disable via LaunchAgent

---

## Rollback Plan

**If Issues:**
1. Unload LaunchAgent: `launchctl unload ~/Library/LaunchAgents/com.02luka.mls.cursor.watcher.plist`
2. Remove watcher script: `rm tools/mls_cursor_watcher.zsh`
3. Remove LaunchAgent plist
4. Document issues in delivery report

**Rollback Script:** `tools/rollback_mls_cursor_watcher.zsh` (create if needed)

---

## Dependencies

- ✅ `tools/mls_auto_record.zsh` exists
- ✅ `tools/mls_cursor_hook.zsh` exists
- ✅ SQLite3 available (`sqlite3` command)
- ✅ Cursor workspace storage accessible
- ✅ LaunchAgent infrastructure available
- ⏳ Cursor SQLite schema (to be discovered in Phase 1)

---

## Success Criteria

1. ✅ All Cursor conversations automatically recorded to MLS Ledger
2. ✅ Training sessions captured without manual intervention
3. ✅ No work/training lost
4. ✅ System runs reliably in background (LaunchAgent)
5. ✅ No performance impact on Cursor (< 1% CPU)
6. ✅ Deduplication prevents duplicate entries
7. ✅ Error handling prevents system failures
8. ✅ Documentation complete
9. ✅ All tests passing
10. ✅ Delivery report created

---

## Timeline Summary

**Phase 1 (1-2 hours):** Investigation & Schema Discovery  
**Phase 1.5 (15-30 min):** Go/No-Go Decision Point  
**Phase 2 (2-3 hours):** Core Watcher Implementation  
**Phase 3 (1 hour):** LaunchAgent & Automation  
**Phase 4 (1-2 hours):** Testing & Validation  
**Phase 5 (1 hour):** Documentation & Delivery  

**Total:** 6.25-10.5 hours (1-2 working days)

---

## Next Steps

1. **Start Phase 1:** Investigate Cursor SQLite schema
2. **Create test script:** Extract sample conversations
3. **Build watcher:** Implement file monitoring
4. **Test thoroughly:** Verify end-to-end flow
5. **Deploy:** Install LaunchAgent and monitor

---

**Status:** 📋 **READY FOR IMPLEMENTATION**

**Answer to "Is this solved?":** ❌ **NO** - Currently documented and planned, but **NOT YET IMPLEMENTED**. This PLAN provides the roadmap to solve it.
