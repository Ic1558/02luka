# Feature Specification: MLS Auto-Capture for Training Prompts & Conversations

**Feature ID:** `mls_auto_prompt_capture`  
**Date:** 2025-11-13  
**Status:** 📋 **SPEC**  
**Priority:** 🔴 **P1 - CRITICAL**

---

## Problem Statement

**Critical Failure:** MLS (Memory & Learning System) is not capturing training prompts/conversations automatically. This defeats the core purpose of MLS as the "core brain" and memory system.

### Current State
- ✅ `mls_auto_record.zsh` exists but requires **manual invocation**
- ❌ No automatic hook for Cursor conversations
- ❌ No automatic hook for prompts/training sessions
- ❌ System relies on manual recording = **work gets lost**

### Impact
- Training efforts are lost if not manually recorded
- No memory of what was taught
- Cannot learn from past conversations
- MLS core purpose (memory/brain) is failing

---

## Requirements

### Functional Requirements

**FR1: Automatic Conversation Capture**
- System MUST automatically detect and capture Cursor conversations
- System MUST capture prompts (user messages) and responses (AI messages)
- System MUST record to MLS Ledger (`mls/ledger/YYYY-MM-DD.jsonl`)
- System MUST work without manual intervention

**FR2: Multiple Capture Methods**
- Primary: File watcher on Cursor workspace storage (`state.vscdb`)
- Fallback: Post-conversation hook/script
- Alternative: Cursor extension/command integration (if available)

**FR3: Data Extraction**
- Extract conversation metadata (timestamp, session ID)
- Extract prompt text (user input)
- Extract response text (AI output)
- Extract context (file paths, workspace info)

**FR4: MLS Integration**
- Use existing `mls_auto_record.zsh` infrastructure
- Record as "learning" or "work" activity type
- Include tags: `cursor,conversation,prompt,training`
- Link to current WO if available

**FR5: Deduplication**
- Avoid recording same conversation multiple times
- Track last recorded timestamp in state file: `memory/cls/mls_cursor_watcher_state.json`
- Extract conversation ID (from SQLite or generate hash)
- Compare conversation IDs/timestamps before recording
- Fallback: Hash-based deduplication if no ID/timestamp available
- Skip if conversation already in MLS Ledger (check by ID or hash)

### Non-Functional Requirements

**NFR1: Performance**
- Capture must not block Cursor operations
- File watcher must be lightweight (< 1% CPU increase)
- Database queries must complete in < 1 second
- **Baseline Measurement Required:** Measure Cursor CPU usage before implementation
- **Alert Threshold:** Alert if CPU increase > 2% during testing

**NFR2: Reliability**
- System must handle Cursor database locks gracefully
- Must not fail if Cursor storage inaccessible
- Must log errors but continue operation

**NFR3: Privacy**
- Only capture conversations in `~/02luka` workspace
- **Workspace Detection:** Map workspace hash to workspace path
  - Check `workspaceStorage/*/workspace.json` or similar metadata
  - Query database for workspace path if available
  - Verify workspace path matches `~/02luka` before processing
- Respect user privacy settings (if any)
- Store data locally only

---

## Technical Approach

### Option A: File Watcher on SQLite Database (Recommended)

**How it works:**
1. Monitor `state.vscdb` file modification time
2. When file changes, query for new conversations
3. Extract new entries since last check
4. Record to MLS Ledger via `mls_auto_record.zsh`

**Pros:**
- Non-invasive (doesn't modify Cursor)
- Works with existing Cursor storage
- Can run as background service

**Cons:**
- Requires SQLite schema knowledge
- May miss rapid conversations
- Database may be locked during writes

**Implementation:**
- LaunchAgent: `com.02luka.mls.cursor.watcher`
- Script: `tools/mls_cursor_watcher.zsh`
- Interval: Check every 30 seconds
- Log: `logs/mls_cursor_watcher.log`
- State File: `memory/cls/mls_cursor_watcher_state.json` (atomic writes)
- **Error Handling:**
  - Retry count: 3 attempts
  - Backoff: 1s, 2s, 4s (exponential)
  - Lock detection: `SQLITE_BUSY` error code
  - Use `PRAGMA read_uncommitted` for read-only queries

### Option B: Post-Conversation Hook

**How it works:**
1. Create Cursor command/extension that runs after conversations
2. Extract conversation from Cursor API/context
3. Call `mls_cursor_hook.zsh` with conversation data
4. Record to MLS Ledger

**Pros:**
- Direct integration with Cursor
- Can capture full conversation context
- Real-time capture

**Cons:**
- Requires Cursor extension development
- May not be possible with current Cursor API
- More complex implementation

### Option C: Session Summary Auto-Recorder

**How it works:**
1. Run `mls_session_summary.zsh` periodically
2. Extract activities from session files
3. Record summaries to MLS Ledger

**Pros:**
- Uses existing infrastructure
- Simple to implement
- Works with current system

**Cons:**
- Not real-time
- May miss individual prompts
- Less granular

---

## Data Schema

### Conversation Entry Format

```json
{
  "ts": "2025-11-13T04:00:00+0700",
  "type": "learning",
  "title": "Cursor Conversation: [Topic]",
  "summary": "Prompt: [first 200 chars]...\nResponse: [first 200 chars]...",
  "source": {
    "producer": "clc",
    "context": "conversation",
    "repo": "Ic1558/02luka",
    "run_id": "",
    "workflow": "",
    "sha": "",
    "artifact": "",
    "artifact_path": ""
  },
  "links": {
    "followup_id": null,
    "wo_id": "[current WO if available]"
  },
  "tags": ["cursor", "conversation", "prompt", "training"],
  "author": "user",
  "confidence": 0.8
}
```

---

## Success Criteria

1. ✅ All Cursor conversations automatically recorded to MLS Ledger
2. ✅ Training sessions captured without manual intervention
3. ✅ No work/training lost
4. ✅ System runs reliably in background
5. ✅ No performance impact on Cursor
6. ✅ Deduplication prevents duplicate entries
7. ✅ Error handling prevents system failures

---

## Out of Scope

- Capturing conversations from other editors (Claude Desktop, etc.)
- Modifying Cursor's internal storage
- Real-time streaming (batch processing acceptable)
- Conversation search/retrieval UI (separate feature)

---

## Dependencies

- ✅ `tools/mls_auto_record.zsh` exists
- ✅ `tools/mls_cursor_hook.zsh` exists (created)
- ✅ SQLite3 available on system
- ✅ Cursor workspace storage accessible
- ⏳ LaunchAgent infrastructure (to be created)

---

## Risks & Mitigations

**Risk:** SQLite database schema may change  
**Mitigation:** Use defensive queries, handle schema errors gracefully

**Risk:** Database locked during Cursor writes  
**Mitigation:** 
- Retry logic: 3 attempts with exponential backoff (1s, 2s, 4s)
- Detect `SQLITE_BUSY` error code specifically
- Skip if locked (will catch on next 30-second run)
- Use `PRAGMA read_uncommitted` for read-only queries

**Risk:** Performance impact on Cursor  
**Mitigation:** Lightweight checks, 30-second intervals, background process

**Risk:** Privacy concerns  
**Mitigation:** Only capture 02luka workspace, local storage only

---

## Open Questions

1. **Q:** What is the exact SQLite schema for Cursor conversations?  
   **A:** Need to investigate `ItemTable` and `cursorDiskKV` tables

2. **Q:** Can we access Cursor API for real-time capture?  
   **A:** Need to research Cursor extension/API capabilities

3. **Q:** Should we capture ALL conversations or filter by workspace?  
   **A:** Filter by `~/02luka` workspace only (privacy)

4. **Q:** How to handle very long conversations?  
   **A:** Truncate summary to 200 chars, store full text separately if needed

5. **Q:** What deduplication strategy?  
   **A:** 
   - Primary: Extract conversation ID from SQLite (if available)
   - Secondary: Track last recorded timestamp in state file
   - Fallback: Generate hash of conversation content
   - State file: `memory/cls/mls_cursor_watcher_state.json` (atomic writes)

---

**Status:** 📋 **READY FOR PLAN CREATION**
