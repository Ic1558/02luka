# Local Agent Review - Unified Chain Telemetry (Phase 2.3)

**Feature:** Telemetry completeness for review → GitDrop → session_save workflow chain  
**Date:** 2025-12-06  
**Status:** ✅ **Implemented** (Tightened Spec)  
**Version:** 1.1

---

## Problem Statement

Current telemetry is fragmented:
- Local Agent Review logs to `g/telemetry/local_agent_review.jsonl`
- GitDrop logs to `_gitdrop/index.jsonl`
- session_save logs to its own telemetry
- No unified view of the complete workflow chain

**Goal:** Single JSONL schema that tracks the entire workflow chain (review → GitDrop → save) with run IDs, snapshot IDs, and durations.

---

## Unified Telemetry Schema

### File: `g/telemetry/dev_workflow_chain.jsonl`

**Format:** One JSON object per line (JSONL) - **One-record policy: single append at chain end**

**Design Principles:**
- Stable fields across runs (no nested objects)
- Grep-friendly (flat structure)
- Max line size reasonable (<10KB)
- All fields present in every record (use `null` for missing)

```json
{
  "ts": "2025-12-06T19:30:00Z",
  "run_id": "run_20251206_193000_abc123",
  "caller": "manual",
  "mode": "staged",
  "offline": false,
  "review_exit_code": 0,
  "review_report_path": "g/reports/reviews/review_20251206_193000.md",
  "review_truncated": false,
  "security_blocked": false,
  "files_included": 5,
  "files_excluded": 0,
  "gitdrop_snapshot_id": "20251206_193005",
  "gitdrop_status": "ok",
  "save_status": "ok",
  "duration_ms_total": 1250,
  "duration_ms_review": 800,
  "duration_ms_gitdrop": 300,
  "duration_ms_save": 150,
  "errors": null,
  "notes": null
}
```

### Field Definitions

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `ts` | string (ISO8601) | ✅ | Timestamp of workflow start (chain start) |
| `run_id` | string | ✅ | Unique run identifier (generated at chain start: `run_YYYYMMDD_HHMMSS_<short_hash>`) |
| `caller` | string | ✅ | `"manual"`, `"hook"`, or `"ci"` (detected from context) |
| `mode` | string | ✅ | Review mode: `"staged"`, `"unstaged"`, `"branch"`, `"range"` (always logged) |
| `offline` | boolean | ✅ | `true` if review ran with `--offline` flag |
| `review_exit_code` | integer | ✅ | Exit code from Local Agent Review (0, 1, 2, 3) - always logged |
| `review_report_path` | string \| null | ✅ | Path to review report (relative to repo root) or `null` if no report |
| `review_truncated` | boolean | ✅ | Whether review was truncated due to size limits |
| `security_blocked` | boolean | ✅ | `true` if review exit code was 3 (secrets detected) |
| `files_included` | integer | ✅ | Number of files included in review |
| `files_excluded` | integer | ✅ | Number of files excluded from review |
| `gitdrop_snapshot_id` | string \| null | ✅ | GitDrop snapshot ID (YYYYMMDD_HHMMSS) or `null` if skipped |
| `gitdrop_status` | string | ✅ | `"ok"`, `"fail"`, or `"skipped"` |
| `save_status` | string | ✅ | `"ok"`, `"fail"`, or `"skipped"` |
| `duration_ms_total` | integer | ✅ | Total workflow duration in milliseconds (from chain start to end) |
| `duration_ms_review` | integer | ✅ | Review step duration in milliseconds (time.monotonic() delta) |
| `duration_ms_gitdrop` | integer \| null | ✅ | GitDrop step duration in milliseconds or `null` if skipped |
| `duration_ms_save` | integer \| null | ✅ | Save step duration in milliseconds or `null` if skipped |
| `errors` | string \| null | ⚪ | Error message if any step failed (concatenated if multiple) |
| `notes` | string \| null | ⚪ | Optional notes/context (e.g., GitDrop include/exclude sets) |

---

## ID Propagation

### Run ID Generation

**Source:** Local Agent Review report filename

**Format:** Extract from report path:
- `g/reports/reviews/review_20251206_193000.md` → `run_id: "review_20251206_193000"`
- If no report generated → generate UUID: `run_id: "run_<uuid>"`

**Propagation:**
```bash
export REVIEW_RUN_ID="review_20251206_193000"
# Pass to GitDrop and session_save via environment
```

### GitDrop Snapshot ID

**Source:** GitDrop output (stdout)

**Extraction:** Parse from GitDrop stdout:
- `"[GitDrop] Snapshot 20251206_193005 created"` → `gitdrop_snapshot_id: "20251206_193005"`
- `"No changes to snapshot"` or empty → `gitdrop_snapshot_id: null`, `gitdrop_status: "skipped"`

**Optional Step:**
- If GitDrop not available/not run → `gitdrop_status: "skipped"`, `gitdrop_snapshot_id: null`
- If GitDrop fails → `gitdrop_status: "fail"`, capture error in `errors` field

**Propagation:**
```bash
export GITDROP_SNAPSHOT_ID="20251206_193005"
# Pass to session_save via environment
```

### Save Status

**Source:** `session_save.zsh` exit code

**Mapping:**
- Exit code 0 → `save_status: "ok"`
- Exit code != 0 → `save_status: "fail"`
- Not executed → `save_status: "skipped"`

---

## Logging Strategy

### One-Record Policy

**Approach:** Single JSONL append at chain end with all fields

**Rationale:**
- Avoid partial records
- Collect per-step data in-memory
- Append complete record once at end
- If hard-fail: append terminal record with last-known state

### Data Collection Flow

**Chain Start:**
1. Generate `run_id` (e.g., `run_20251206_193000_a1b2c3`)
2. Capture `ts` (ISO8601 timestamp)
3. Detect `caller` (manual/hook/ci)
4. Initialize in-memory record structure

**During Review:**
1. Start timer: `review_start = time.monotonic()`
2. Run review, capture:
   - `mode` (from args)
   - `offline` (from `--offline` flag)
   - `review_exit_code` (from return code)
   - `review_report_path` (from output_path if generated)
   - `review_truncated` (from diff.truncated)
   - `security_blocked` (true if exit_code == 3)
   - `files_included`, `files_excluded` (from diff)
3. End timer: `duration_ms_review = (time.monotonic() - review_start) * 1000`

**After Review:**
- If `review_exit_code == 3` (security blocked): skip GitDrop/Save, log terminal record
- If `review_exit_code == 2` (config error): log minimal error record or nothing
- If `review_exit_code in [0, 1]`: continue to GitDrop

**During GitDrop (if run):**
1. Start timer: `gitdrop_start = time.monotonic()`
2. Run GitDrop, capture:
   - Parse `gitdrop_snapshot_id` from stdout
   - Set `gitdrop_status` based on exit code
   - Capture include/exclude sets in `notes` (optional)
3. End timer: `duration_ms_gitdrop = (time.monotonic() - gitdrop_start) * 1000`
4. Export `GITDROP_SNAPSHOT_ID` for session_save

**During Save (if run):**
1. Start timer: `save_start = time.monotonic()`
2. Pass `RUN_ID` and `GITDROP_SNAPSHOT_ID` to session_save.zsh
3. Run session_save, capture:
   - `save_status` based on exit code
   - Any stderr output in `errors` field
4. End timer: `duration_ms_save = (time.monotonic() - save_start) * 1000`

**Chain End:**
1. Calculate `duration_ms_total = (time.monotonic() - chain_start) * 1000`
2. Append single JSONL record with all fields
3. File: `g/telemetry/dev_workflow_chain.jsonl`

---

## Implementation Strategy

### One-Record Policy (Selected)

**Approach:** Single JSONL append at chain end with all fields collected in-memory.

**Implementation:**
- Collect all data in Python dict / zsh associative array during chain
- Append complete record once at end
- If hard-fail: append terminal record with last-known state and errors

**Benefits:**
- Simple implementation (no file locking)
- No partial records
- Easy to query (grep-friendly JSONL)
- Atomic write (single append)

**Edge Cases:**
- Config validation error (exit 2): log minimal error record or nothing
- Security block (exit 3): log terminal record, skip GitDrop/Save
- GitDrop optional: if not available, log `gitdrop_status: "skipped"`
- Save failure: log `save_status: "fail"` with error in `errors` field

---

## Safety & Edge Cases

### Offline Mode

**Rule:** If `--offline` flag is set:
- Still log telemetry (local file write)
- Set `offline: true` in record
- Review runs without API call
- GitDrop/Save still run (they're local)

### Chain Failures

**Rule:** Always append terminal record with last-known state:

**Config Error (exit 2):**
- Log minimal error record or nothing (config errors happen before chain starts)
- If logged: `{"errors": "Config validation failed", "review_exit_code": 2, ...}`

**Security Block (exit 3):**
- Log terminal record with `security_blocked: true`
- Skip GitDrop/Save: `gitdrop_status: "skipped"`, `save_status: "skipped"`
- Include error context in `errors` field

**Review Failure (exit 2, system error):**
- Log terminal record with review data
- Skip GitDrop/Save
- Include error in `errors` field

**GitDrop Failure:**
- Log `gitdrop_status: "fail"`
- Continue to Save (optional: can skip if GitDrop critical)
- Include GitDrop error in `errors` field

**Save Failure:**
- Log `save_status: "fail"`
- Include save stderr in `errors` field

### No Network Calls

**Rule:** All telemetry is local file writes. No external API calls. Respect `--offline` flag.

### Missing Values

**Rule:** Use `null` for missing/unknown values (not empty strings or 0).

### GitDrop Optional

**Rule:** If GitDrop not available or not run:
- Set `gitdrop_status: "skipped"`
- Set `gitdrop_snapshot_id: null`
- Set `duration_ms_gitdrop: null`
- Continue to Save step

### Timing Precision

**Rule:** Use `time.monotonic()` (Python) or equivalent for step durations:
- Avoids clock drift
- Millisecond precision
- Deltas between start/end timestamps

---

## Integration Points

### 1. Local Agent Review

**File:** `tools/local_agent_review.py`

**Changes:**
- Read `RUN_ID` from environment (generated by chain script)
- If not set, generate `run_id` (for standalone runs)
- Determine `caller` via helper function:
  ```python
  def determine_caller() -> str:
      if os.getenv("CI"):
          return "ci"
      if os.getenv("LOCAL_REVIEW_ENABLED") or os.getenv("GIT_HOOK"):
          return "hook"
      return "manual"
  ```
- Collect review data in-memory (don't log yet)
- Return review data dict to caller (for chain script)
- Export `RUN_ID` if generated (for standalone runs)

### 2. Unified Chain Script

**File:** `tools/workflow_dev_review_save.zsh` (update existing) or new `tools/unified_chain.zsh`

**Changes:**
- **Chain Start:**
  - Generate `RUN_ID` (format: `run_YYYYMMDD_HHMMSS_<hash>`)
  - Capture `ts` (ISO8601)
  - Detect `caller` (manual/hook/ci)
  - Start total timer: `chain_start = $(date +%s.%N)` or Python equivalent
  - Initialize in-memory record dict/array

- **Run Review:**
  - Export `RUN_ID` environment variable
  - Start review timer
  - Run `python3 tools/local_agent_review.py staged ...`
  - Capture review data (exit_code, report_path, truncated, files, etc.)
  - End review timer, calculate `duration_ms_review`

- **Decision Point:**
  - If `review_exit_code == 3`: skip GitDrop/Save, append terminal record
  - If `review_exit_code == 2`: log minimal error or nothing
  - If `review_exit_code in [0, 1]`: continue

- **Run GitDrop (if continuing):**
  - Start GitDrop timer
  - Run `python3 tools/gitdrop.py backup --reason "After review"`
  - Parse `snapshot_id` from stdout (regex: `Snapshot (\d{8}_\d{6})`)
  - Set `gitdrop_status` (ok/fail/skipped)
  - End GitDrop timer, calculate `duration_ms_gitdrop`
  - Export `GITDROP_SNAPSHOT_ID` environment variable

- **Run Save (if continuing):**
  - Start save timer
  - Export `RUN_ID` and `GITDROP_SNAPSHOT_ID` to session_save
  - Run `tools/session_save.zsh` (or `tools/save.sh`)
  - Capture exit code → `save_status`
  - Capture stderr → `errors` field
  - End save timer, calculate `duration_ms_save`

- **Chain End:**
  - Calculate `duration_ms_total`
  - Append single JSONL record with all fields
  - Write to `g/telemetry/dev_workflow_chain.jsonl`

### 3. GitDrop

**File:** `tools/gitdrop.py`

**Changes:**
- Output `snapshot_id` in parseable format (already done: "Created snapshot {id}")
- Export `GITDROP_SNAPSHOT_ID` environment variable (optional)

### 4. session_save

**File:** `tools/session_save.zsh`

**Changes:**
- Read `REVIEW_RUN_ID` and `GITDROP_SNAPSHOT_ID` from environment
- Include in telemetry if needed (optional)

---

## Example Workflow

### Successful Chain (One-Record Policy)

```bash
# Unified chain script: tools/unified_chain.zsh

# 1. Chain Start
RUN_ID="run_20251206_193000_a1b2c3"  # Generated at start
ts="2025-12-06T19:30:00Z"
caller="manual"  # Detected from context
chain_start=$(python3 -c "import time; print(time.monotonic())")

# 2. Run Review
export RUN_ID
review_start=$(python3 -c "import time; print(time.monotonic())")
python3 tools/local_agent_review.py staged
review_exit_code=$?
review_end=$(python3 -c "import time; print(time.monotonic())")
duration_ms_review=$(( (review_end - review_start) * 1000 ))

# Capture review data:
# - mode="staged"
# - offline=false
# - review_report_path="g/reports/reviews/review_20251206_193000.md"
# - review_truncated=false
# - security_blocked=false
# - files_included=5, files_excluded=0

# 3. Run GitDrop (if review_exit_code in [0, 1])
if [[ $review_exit_code -le 1 ]]; then
    gitdrop_start=$(python3 -c "import time; print(time.monotonic())")
    gitdrop_output=$(python3 tools/gitdrop.py backup --reason "After review" 2>&1)
    gitdrop_exit_code=$?
    gitdrop_end=$(python3 -c "import time; print(time.monotonic())")
    duration_ms_gitdrop=$(( (gitdrop_end - gitdrop_start) * 1000 ))
    
    # Parse snapshot_id: "Snapshot 20251206_193005 created"
    gitdrop_snapshot_id=$(echo "$gitdrop_output" | grep -oP 'Snapshot \K\d{8}_\d{6}' || echo "null")
    if [[ "$gitdrop_snapshot_id" != "null" ]]; then
        export GITDROP_SNAPSHOT_ID="$gitdrop_snapshot_id"
        gitdrop_status="ok"
    else
        gitdrop_status="skipped"
    fi
else
    gitdrop_status="skipped"
    gitdrop_snapshot_id="null"
    duration_ms_gitdrop=null
fi

# 4. Run Save (if continuing)
if [[ "$gitdrop_status" != "skipped" ]] || [[ $review_exit_code -le 1 ]]; then
    save_start=$(python3 -c "import time; print(time.monotonic())")
    save_stderr=$(tools/session_save.zsh 2>&1)
    save_exit_code=$?
    save_end=$(python3 -c "import time; print(time.monotonic())")
    duration_ms_save=$(( (save_end - save_start) * 1000 ))
    
    if [[ $save_exit_code -eq 0 ]]; then
        save_status="ok"
        errors=null
    else
        save_status="fail"
        errors="$save_stderr"
    fi
else
    save_status="skipped"
    duration_ms_save=null
fi

# 5. Chain End - Append Single Record
chain_end=$(python3 -c "import time; print(time.monotonic())")
duration_ms_total=$(( (chain_end - chain_start) * 1000 ))

# Append to g/telemetry/dev_workflow_chain.jsonl
python3 -c "
import json
record = {
    'ts': '$ts',
    'run_id': '$RUN_ID',
    'caller': '$caller',
    'mode': 'staged',
    'offline': False,
    'review_exit_code': $review_exit_code,
    'review_report_path': 'g/reports/reviews/review_20251206_193000.md',
    'review_truncated': False,
    'security_blocked': False,
    'files_included': 5,
    'files_excluded': 0,
    'gitdrop_snapshot_id': '$gitdrop_snapshot_id' if '$gitdrop_snapshot_id' != 'null' else None,
    'gitdrop_status': '$gitdrop_status',
    'save_status': '$save_status',
    'duration_ms_total': $duration_ms_total,
    'duration_ms_review': $duration_ms_review,
    'duration_ms_gitdrop': $duration_ms_gitdrop if '$duration_ms_gitdrop' != 'null' else None,
    'duration_ms_save': $duration_ms_save if '$duration_ms_save' != 'null' else None,
    'errors': None if '$errors' == 'null' else '$errors',
    'notes': None
}
with open('g/telemetry/dev_workflow_chain.jsonl', 'a') as f:
    f.write(json.dumps(record) + '\n')
"
```

### Security Block Chain (Terminal Record)

```bash
# Review detects secrets (exit code 3)
review_exit_code=3
security_blocked=true

# Skip GitDrop and Save
gitdrop_status="skipped"
save_status="skipped"

# Append terminal record immediately
# → {review_exit_code: 3, security_blocked: true, gitdrop_status: "skipped", save_status: "skipped", ...}
```

### Config Error (Minimal Log)

```bash
# Config validation fails (exit code 2)
review_exit_code=2

# Log minimal error record or nothing
# → {errors: "Config validation failed", review_exit_code: 2, ...}
# OR: skip logging entirely (config errors happen before chain starts)
```

---

## Testing Strategy

### Unit Tests

1. **Run ID Generation:**
   - Test extraction from report filename
   - Test UUID fallback when no report

2. **Caller Detection:**
   - Test `caller="manual"` (default)
   - Test `caller="hook"` (when `$GIT_HOOK` set)
   - Test `caller="ci"` (when `$CI` set)

3. **Snapshot ID Extraction:**
   - Test parsing from GitDrop output
   - Test handling of "No changes" message

4. **Duration Calculation:**
   - Test millisecond precision
   - Test handling of missing timestamps

### Integration Tests

1. **Full Chain:**
   - Run review → GitDrop → save
   - Verify final record has all fields

2. **Partial Chain:**
   - Run review with error
   - Verify record shows skipped steps

3. **Offline Mode:**
   - Run with `--offline`
   - Verify telemetry still logged

---

## Migration Notes

### Existing Telemetry

**Current:**
- `g/telemetry/local_agent_review.jsonl` (review-specific)
- `_gitdrop/index.jsonl` (GitDrop-specific)
- `g/telemetry/workflow_dev_review_save.jsonl` (basic chain)

**Migration:**
- Keep existing telemetry files (backward compatibility)
- Add new unified file: `g/telemetry/dev_workflow_chain.jsonl`
- Gradually migrate queries to unified file

---

## Success Criteria

✅ **Phase 2.3 Complete When:**
- Unified telemetry schema defined and documented (one-record policy)
- Run ID generated at chain start (single source of truth)
- Caller detection working (manual/hook/ci)
- Timing using `time.monotonic()` deltas (millisecond precision)
- One-record policy: single JSONL append at chain end
- All fields populated correctly (use `null` for missing)
- Security block handling: skip GitDrop/Save on exit code 3
- Config error handling: minimal log or nothing
- GitDrop optional: graceful skip if not available
- Tests passing (unit + integration)
- No network calls (offline-safe)
- Schema stable and grep-friendly (no nested objects)

---

**Next Steps:**
1. Review and approve this spec
2. Implement telemetry logging in Local Agent Review
3. Update unified chain script
4. Add unit tests
5. Integration testing

---

**Last Updated:** 2025-12-06
