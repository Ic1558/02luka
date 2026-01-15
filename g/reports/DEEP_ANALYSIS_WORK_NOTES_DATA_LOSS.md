# Deep Analysis: Work Notes Data Loss Issue

**Generated:** 2026-01-16  
**Analyzed by:** CLC  
**Status:** 🚨 CRITICAL - Confirmed Data Loss

---

## Executive Summary

**Confirmed Finding:** The `work_notes.jsonl` system is **silently discarding old entries**, violating its documented "append-only journal" invariant.

**Root Cause:** `bridge/lac/writer.py` implements a **rolling window** (WORK_NOTES_MAX = 200) that truncates entries, contradicting the "append-only" design promise.

**Impact:**
- Historical work notes are lost after 200 new entries
- Violates audit trail and memory persistence guarantees
- Creates unpredictable behavior for agents relying on historical context

**Recommended Fix:** Decouple journal (true append-only) from snapshot (bounded view)

---

## Root Cause Analysis

### The Conflicting Invariants

**Documented Invariant** (from `roadmaps/MAIN_BLUEPRINT_ROADMAP.md:11`):
```
One runtime activity log: g/core_state/work_notes.jsonl
(append-only, non-blocking, best-effort, git-ignored)
```

**Implemented Behavior** (`bridge/lac/writer.py:211-217`):
```python
if WORK_NOTES_MAX > 0:
    keep = max(0, WORK_NOTES_MAX - 1)
    if keep == 0:
        lines = []
    elif len(lines) > keep:
        lines = lines[-keep:]  # ⚠️ TRUNCATION HAPPENS HERE
```

### The Contradiction

| Aspect | Documentation Says | Code Does |
|--------|-------------------|-----------|
| **Pattern** | Append-Only Journal | Rolling Window |
| **Data Retention** | Persistent | Last 200 entries only |
| **Behavior** | Never deletes | Silently discards |
| **Invariant** | Cumulative history | Bounded memory |

---

## What Actually Happens (Step-by-Step)

### Current `write_work_note()` Execution Flow:

1. **Open file** in `"a+"` mode (line 194)
2. **Acquire non-blocking lock** (line 196)
3. **Read ALL existing lines** (line 200)
   ```python
   lines = [line for line in handle.read().splitlines() if line.strip()]
   ```
4. **Create new entry** (lines 201-210)
5. **Apply rolling window truncation** (lines 211-217)
   ```python
   if len(lines) > 199:
       lines = lines[-199:]  # Keep only last 199
   ```
6. **Write to temp file** (line 219)
7. **Atomic replace** (line 220)
   ```python
   os.replace(temp_path, path)  # OLD DATA GONE
   ```

### Data Loss Scenario

```
Initial state: work_notes.jsonl has 200 entries
├─ Entry #1: "Task A completed"
├─ Entry #2: "Task B started"
...
└─ Entry #200: "Task Z finished"

Agent writes Entry #201: "New task began"

Result after write_work_note():
├─ Entry #1: DELETED ❌
├─ Entry #2: "Task B started"
...
├─ Entry #200: "Task Z finished"
└─ Entry #201: "New task began"
```

**Entry #1 is PERMANENTLY LOST** - no backup, no warning, no recovery.

---

## Why This Wasn't `core_latest_state.py`'s Fault

### Initial Hypothesis (INCORRECT):
"Running snapshot generator deletes work notes"

### Evidence Against:
1. **`core_latest_state.py` never touches `work_notes.jsonl`**
   - Lines 279-286: Only writes `latest.json` and `latest.md`
   - No code path reads or modifies work notes

2. **Directories are separate concerns:**
   - `g/core_state/latest.{json,md}` ← Snapshot (overwrite by design)
   - `g/core_state/work_notes.jsonl` ← Journal (append-only by design)

3. **The bug is self-inflicted:**
   - `write_work_note()` truncates its OWN file
   - No external process involved

---

## Ideas from Dryrun Analysis

### Idea 1: **True Append-Only Journal** (Recommended)

**Change:** Remove `WORK_NOTES_MAX` limit entirely

**Implementation:**
```python
# bridge/lac/writer.py (modified)

WORK_NOTES_MAX = 0  # 0 = unlimited (true append-only)

def write_work_note(...) -> bool:
    # ... existing code ...

    # Remove lines 211-217 (truncation logic)
    # Just append new line:
    note_line = json.dumps(note, ensure_ascii=True)

    # Atomic append (no read, no truncation)
    temp_path = path.with_suffix(path.suffix + ".tmp")
    with temp_path.open("w") as f:
        with path.open("r") as src:
            f.write(src.read())
        f.write(note_line + "\n")
    os.replace(temp_path, path)
```

**Pros:**
- ✅ Honors "append-only" invariant
- ✅ No data loss ever
- ✅ Audit trail preserved
- ✅ Simple implementation

**Cons:**
- ⚠️ Unbounded growth (but mitigated by rotation)

**Mitigation:** Add external rotation tool:
```bash
# tools/rotate_work_notes.zsh (weekly cron)
mv g/core_state/work_notes.jsonl g/core_state/archive/work_notes_$(date +%Y%m%d).jsonl
touch g/core_state/work_notes.jsonl
```

---

### Idea 2: **Decouple Journal from Digest** (Architecture Fix)

**Change:** Split into two files with clear responsibilities

**Structure:**
```
g/core_state/
├── work_notes.jsonl          # True append-only journal (never truncates)
└── work_notes_digest.json    # Bounded snapshot (last N entries)
```

**Implementation:**
```python
# bridge/lac/writer.py

def write_work_note(...) -> bool:
    """Write to append-only journal."""
    path = _work_notes_path()
    note_line = json.dumps(note) + "\n"

    # True append (no read, no truncation)
    with path.open("a") as f:
        f.write(note_line)

    # Optionally update digest (non-critical)
    _update_digest(path)
    return True

def _update_digest(journal_path: Path) -> None:
    """Create bounded digest from journal (best-effort)."""
    digest_path = journal_path.with_name("work_notes_digest.json")
    try:
        # Read last 200 from journal
        with journal_path.open("r") as f:
            all_lines = f.readlines()
        recent = all_lines[-200:]

        # Write digest
        digest_path.write_text(json.dumps({
            "last_200": [json.loads(line) for line in recent],
            "total_count": len(all_lines),
            "generated_at": datetime.now(timezone.utc).isoformat()
        }))
    except Exception:
        pass  # Digest update is non-critical
```

**Reads:**
```python
# g/tools/core_intake.py (modified)

def _extract_work_notes() -> List[Dict[str, Any]]:
    """Read from digest first, fallback to journal."""
    digest_path = _work_notes_path().with_name("work_notes_digest.json")

    # Fast path: read digest
    if digest_path.exists():
        try:
            data = json.loads(digest_path.read_text())
            return data.get("last_200", [])
        except Exception:
            pass

    # Slow path: read full journal
    return _read_journal_tail(200)
```

**Pros:**
- ✅ Journal never loses data (true append-only)
- ✅ Digest provides fast bounded view
- ✅ Clear separation of concerns
- ✅ Reads are optimized (digest)
- ✅ Writes are simple (journal only)

**Cons:**
- ⚠️ More complex (two files to manage)
- ⚠️ Digest can lag behind journal (acceptable)

---

### Idea 3: **Explicit Rotation with Archival** (Operational Fix)

**Change:** Keep rolling window BUT document it explicitly and add archival

**Implementation:**
```python
# bridge/lac/writer.py

WORK_NOTES_MAX = 200
WORK_NOTES_ARCHIVE_DIR = "g/core_state/archive/"

def write_work_note(...) -> bool:
    # ... existing code ...

    # Before truncation, archive old entries
    if len(lines) > WORK_NOTES_MAX:
        _archive_old_entries(lines[:-WORK_NOTES_MAX], path)

    # Then apply rolling window
    if len(lines) > WORK_NOTES_MAX - 1:
        lines = lines[-(WORK_NOTES_MAX - 1):]

    # ... rest of existing code ...

def _archive_old_entries(old_lines: List[str], source_path: Path) -> None:
    """Move old entries to timestamped archive (best-effort)."""
    try:
        archive_dir = source_path.parent / "archive"
        archive_dir.mkdir(exist_ok=True)

        timestamp = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
        archive_path = archive_dir / f"work_notes_{timestamp}.jsonl"

        archive_path.write_text("\n".join(old_lines) + "\n")
    except Exception:
        pass  # Archival is best-effort, don't fail write
```

**Pros:**
- ✅ No data loss (archived)
- ✅ Keeps current file bounded
- ✅ Audit trail preserved in archive/
- ✅ Minimal code changes

**Cons:**
- ⚠️ Archive directory grows over time
- ⚠️ Reads need to search archives for old data

---

### Idea 4: **Configuration-Based Behavior** (Flexible)

**Change:** Make truncation behavior configurable

**Implementation:**
```python
# bridge/lac/writer.py

# Environment variable controls behavior
WORK_NOTES_MODE = os.environ.get("LUKA_WORK_NOTES_MODE", "rolling")
WORK_NOTES_MAX = int(os.environ.get("LUKA_WORK_NOTES_MAX", "200"))

def write_work_note(...) -> bool:
    # ... existing code ...

    if WORK_NOTES_MODE == "append_only":
        # True append-only (no truncation)
        payload = "\n".join(lines + [note_line]) + "\n"

    elif WORK_NOTES_MODE == "rolling":
        # Rolling window (current behavior)
        if WORK_NOTES_MAX > 0 and len(lines) > WORK_NOTES_MAX - 1:
            lines = lines[-(WORK_NOTES_MAX - 1):]
        payload = "\n".join(lines + [note_line]) + "\n"

    else:
        return False  # Unknown mode

    # ... atomic write ...
```

**Configuration:**
```bash
# .env or shell profile
export LUKA_WORK_NOTES_MODE=append_only  # or "rolling"
export LUKA_WORK_NOTES_MAX=200
```

**Pros:**
- ✅ Backward compatible (default = rolling)
- ✅ Easy to switch to append-only
- ✅ No code changes for mode switch
- ✅ Testable (set env var)

**Cons:**
- ⚠️ Hidden behavior (requires env var knowledge)
- ⚠️ Still needs external rotation for append-only mode

---

## Recommended Solution: Idea 2 (Decouple)

**Why Idea 2 wins:**
1. **Architectural clarity:** Journal vs Digest are fundamentally different patterns
2. **No data loss:** Journal is true append-only
3. **Performance:** Digest provides fast bounded reads
4. **Flexibility:** Can change digest size without touching journal
5. **Auditability:** Full history always available in journal

**Implementation Plan:**

### Phase 1: Add True Append-Only Journal (Today)
```python
# bridge/lac/writer.py - modify write_work_note()
def write_work_note(...) -> bool:
    path = _work_notes_path()
    note_line = json.dumps(note) + "\n"

    # True append (no read-modify-write)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a") as f:
        f.write(note_line)

    return True
```

### Phase 2: Add Digest Generator (Day 2)
```bash
# tools/update_work_notes_digest.zsh
# Called periodically (cron every 5 min, or post-write hook)
tail -n 200 g/core_state/work_notes.jsonl > g/core_state/work_notes_digest.jsonl
```

### Phase 3: Update Readers (Day 3)
```python
# g/tools/core_intake.py - modify _extract_work_notes()
def _extract_work_notes() -> List[Dict[str, Any]]:
    # Read digest first (fast)
    digest_path = _work_notes_path().with_name("work_notes_digest.jsonl")
    if digest_path.exists():
        return _read_jsonl(digest_path)

    # Fallback to journal tail (slower)
    return _read_jsonl_tail(_work_notes_path(), 200)
```

### Phase 4: Verify & Document (Day 4)
- Test: Write 500 entries, verify all 500 in journal
- Test: Verify digest contains last 200
- Update: `roadmaps/MAIN_BLUEPRINT_ROADMAP.md`
- Update: `g/docs/CORE_STATE_BUS.md`

---

## Verification Plan

### Test 1: **No Data Loss After 200+ Entries**

```bash
# Write 250 work notes
for i in {1..250}; do
  python3 -c "from bridge.lac.writer import write_work_note; write_work_note('test', 'TASK-$i', 'Test note $i', 'success')"
done

# Verify journal has all 250
wc -l g/core_state/work_notes.jsonl
# Expected: 250

# Verify digest has last 200
wc -l g/core_state/work_notes_digest.jsonl
# Expected: 200

# Verify first entry still exists
head -n 1 g/core_state/work_notes.jsonl | jq .task_id
# Expected: "TASK-1"
```

### Test 2: **Digest Auto-Updates**

```bash
# Write note
python3 -c "from bridge.lac.writer import write_work_note; write_work_note('dev', 'TASK-NEW', 'Latest task', 'running')"

# Check digest was updated (if Phase 2 implemented)
tail -n 1 g/core_state/work_notes_digest.jsonl | jq .task_id
# Expected: "TASK-NEW"
```

### Test 3: **Snapshot Generator Doesn't Interfere**

```bash
# Baseline
cp g/core_state/work_notes.jsonl /tmp/before.jsonl

# Run snapshot
python3 g/tools/core_latest_state.py --write

# Verify no change
diff /tmp/before.jsonl g/core_state/work_notes.jsonl
# Expected: no differences
```

---

## Cost-Benefit Analysis

### Current State (Rolling Window)
| Metric | Value |
|--------|-------|
| **Data Loss** | YES (after 200 entries) |
| **Write Performance** | SLOW (read all + truncate + write) |
| **Read Performance** | SLOW (parse entire file) |
| **Disk Usage** | BOUNDED (max 200 entries) |
| **Audit Trail** | NO (history lost) |

### Proposed State (Journal + Digest)
| Metric | Value |
|--------|-------|
| **Data Loss** | NO (never) |
| **Write Performance** | FAST (append-only) |
| **Read Performance** | FAST (read digest only) |
| **Disk Usage** | UNBOUNDED (with rotation) |
| **Audit Trail** | YES (full history) |

**Net Improvement:**
- ✅ Eliminates data loss
- ✅ Faster writes (no read-modify-write)
- ✅ Faster reads (digest is pre-parsed)
- ⚠️ Requires periodic rotation (mitigated by automation)

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| **Unbounded journal growth** | HIGH | MEDIUM | Weekly rotation to archive/ |
| **Digest lag** | MEDIUM | LOW | Acceptable (5-min lag is fine) |
| **Migration data loss** | LOW | HIGH | Backup before migration |
| **Performance regression** | LOW | MEDIUM | Benchmark before/after |

---

## Next Actions

### Immediate (Today)
1. ✅ **Backup current work_notes.jsonl**
   ```bash
   cp g/core_state/work_notes.jsonl g/core_state/work_notes.jsonl.backup-$(date +%Y%m%d)
   ```

2. 🚧 **Implement true append-only** (Phase 1)
   - Modify `bridge/lac/writer.py::write_work_note()`
   - Remove truncation logic (lines 211-217)
   - Test with 500 writes

### Short-term (This Week)
3. 🔜 **Add digest generator** (Phase 2)
   - Create `tools/update_work_notes_digest.zsh`
   - Add to cron or launchd

4. 🔜 **Update readers** (Phase 3)
   - Modify `g/tools/core_intake.py::_extract_work_notes()`
   - Prefer digest, fallback to journal

### Long-term (Next Sprint)
5. 📅 **Add rotation automation**
   - Weekly: Move old journal to archive/
   - Keep last 30 days in archive/
   - Compress older archives

6. 📅 **Update documentation**
   - Clarify journal vs digest in all docs
   - Add troubleshooting guide
   - Document rotation policy

---

## Conclusion

**The data loss is real, confirmed, and fixable.**

**Root cause:** Conflicting invariants between documented "append-only" behavior and implemented "rolling window" truncation.

**Recommended fix:** Decouple journal (true append-only) from digest (bounded view) to honor both needs without compromise.

**Impact:** CRITICAL - affects audit trail, agent memory, and system reliability.

**Urgency:** HIGH - implement Phase 1 today to stop data loss immediately.

---

**Report prepared by:** CLC (Claude Code)  
**Date:** 2026-01-16  
**Confidence:** HIGH (code analysis + documentation review + test confirmation)
