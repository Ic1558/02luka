# Phase 1: Immediate Stabilization Plan

**Objective:** Halt the ongoing data loss in `work_notes.jsonl` by enforcing the "True Append-Only" invariant.

---

## 1. Problem Statement
The current implementation in `bridge/lac/writer.py` contains a rolling-window truncation logic (`WORK_NOTES_MAX = 200`) that silently deletes old entries. This contradicts the system requirement for a persistent, append-only activity journal.

## 2. Proposed Changes (Writer Fix)
The following modifications are planned for `bridge/lac/writer.py`:
- **Disable Truncation:** Set `WORK_NOTES_MAX = 0` (or remove the logic entirely).
- **Optimize Write Pattern:** Transition from a "Read-Modify-Write" pattern to a "Direct Append" pattern using standard file append modes (`"a"`).
- **Atomic Safety:** Maintain the use of temporary files and `os.replace` if atomic replacement of a growing file is still desired, or simply trust standard filesystem append atomicity for smaller entries.

## 3. Expected Outcome
- `work_notes.jsonl` will grow linearly without discarding historical data.
- Write performance will improve as the script no longer needs to read and parse the entire history before adding a new note.
- The audit trail for agent activities will be fully preserved.

## 4. Verification Steps
1. **Stress Test:** Programmatically write 500+ entries and verify the line count is exactly matches the input.
2. **Persistence Check:** Verify that "Entry #1" remains in the file after "Entry #201" is written.
3. **Snapshot Isolation:** Confirm that running `core_latest_state.py` does not truncate or modify the journal.

---
**Status:** Plan finalized. Ready for implementation.
