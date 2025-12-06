# Local Agent Review - Unified Chain Telemetry & Future Enhancements Plan

**Feature:** Telemetry completeness + Future enhancements menu  
**Date:** 2025-12-06  
**Status:** Plan (Tightened)  
**Version:** 1.1

---

## Overview

This plan covers:
1. **Phase 2.3:** Unified chain telemetry (review → GitDrop → session_save)
2. **Future Enhancements Menu:** 5 optional enhancements for Phase 3+

---

## Phase 2.3: Unified Chain Telemetry

### Goal

Create single JSONL schema (`g/telemetry/dev_workflow_chain.jsonl`) that tracks complete workflow chain with run IDs, snapshot IDs, and durations.

### Tasks

#### T1: Define Telemetry Schema ✅
- [x] Create SPEC document with field definitions
- [x] Define JSONL format
- [x] Document ID propagation strategy

#### T2: Implement Run ID Generation (Chain Script)
- [ ] Generate `run_id` at chain start: `run_YYYYMMDD_HHMMSS_<short_hash>`
- [ ] Format: timestamp + 6-char hash (UUID prefix or random hex)
- [ ] Export `RUN_ID` environment variable
- [ ] Add unit tests

**Files:**
- `tools/workflow_dev_review_save.zsh` or `tools/unified_chain.zsh`

#### T3: Implement Caller Detection Helper
- [ ] Create `determine_caller()` helper function:
  ```python
  def determine_caller() -> str:
      if os.getenv("CI"):
          return "ci"
      if os.getenv("LOCAL_REVIEW_ENABLED") or os.getenv("GIT_HOOK"):
          return "hook"
      return "manual"  # default
  ```
- [ ] Use in both review script and chain script
- [ ] Add unit tests

**Files:**
- `tools/local_agent_review.py` (helper function)
- `tools/workflow_dev_review_save.zsh` (use helper)

#### T4: Add Data Collection to Local Agent Review
- [ ] Read `RUN_ID` from environment (if set by chain)
- [ ] If not set, generate `run_id` (for standalone runs)
- [ ] Collect review data in-memory (don't log yet):
  - `mode`, `offline`, `review_exit_code`, `review_report_path`
  - `review_truncated`, `security_blocked` (exit_code == 3)
  - `files_included`, `files_excluded`
  - `duration_ms_review` (using `time.monotonic()`)
- [ ] Return review data dict (for chain script) or log standalone
- [ ] Add unit tests

**Files:**
- `tools/local_agent_review.py`

#### T5: Update Unified Chain Script (One-Record Policy)
- [ ] **Chain Start:**
  - Generate `RUN_ID`, capture `ts`, detect `caller`
  - Start total timer: `chain_start = time.monotonic()`
  - Initialize in-memory record dict

- [ ] **Run Review:**
  - Export `RUN_ID` to review script
  - Start review timer
  - Run review, capture all review fields
  - Calculate `duration_ms_review`
  - Decision: if exit_code == 3, skip GitDrop/Save; if exit_code == 2, log minimal or nothing

- [ ] **Run GitDrop (if continuing):**
  - Start GitDrop timer
  - Run GitDrop, parse `snapshot_id` from stdout (regex: `Snapshot (\d{8}_\d{6})`)
  - Set `gitdrop_status` (ok/fail/skipped)
  - Calculate `duration_ms_gitdrop`
  - Export `GITDROP_SNAPSHOT_ID`

- [ ] **Run Save (if continuing):**
  - Start save timer
  - Export `RUN_ID` and `GITDROP_SNAPSHOT_ID` to session_save
  - Run session_save, capture exit code and stderr
  - Set `save_status`, include stderr in `errors`
  - Calculate `duration_ms_save`

- [ ] **Chain End:**
  - Calculate `duration_ms_total`
  - Append single JSONL record with all fields
  - Handle hard-fails: append terminal record with last-known state

**Files:**
- `tools/workflow_dev_review_save.zsh` (update existing)
- Or create new: `tools/unified_chain.zsh`

#### T6: GitDrop Integration (Optional)
- [ ] Treat GitDrop as optional step
- [ ] If GitDrop not available: `gitdrop_status: "skipped"`, `gitdrop_snapshot_id: null`
- [ ] Parse snapshot ID from stdout: `[GitDrop] Snapshot (\d{8}_\d{6}) created`
- [ ] Capture include/exclude sets in `notes` field (optional)
- [ ] Export `GITDROP_SNAPSHOT_ID` environment variable (if created)

**Files:**
- `tools/gitdrop.py` (verify output format is parseable - already done)

#### T7: session_save Integration
- [ ] Pass `RUN_ID` and `GITDROP_SNAPSHOT_ID` via environment
- [ ] Capture exit code → `save_status` (ok/fail)
- [ ] Capture stderr → `errors` field
- [ ] Handle save failures gracefully

**Files:**
- `tools/session_save.zsh` (read env vars, optional)

#### T8: Testing
- [ ] Unit tests for run_id generation (format validation)
- [ ] Unit tests for caller detection (CI, hook, manual)
- [ ] Unit tests for snapshot_id extraction (regex parsing)
- [ ] Unit tests for timing (time.monotonic() deltas)
- [ ] Integration test: full chain (review → GitDrop → save)
- [ ] Integration test: security block (exit 3) → skip GitDrop/Save
- [ ] Integration test: config error (exit 2) → minimal log
- [ ] Integration test: offline mode → still log
- [ ] Integration test: GitDrop optional → skip gracefully

**Files:**
- `tests/test_local_agent_review.py` (extend)
- `tests/test_unified_chain.py` (new)

---

## Future Enhancements Menu

### 1. Multi-Provider Support (OpenAI + Local Models)

**Priority:** Medium  
**Complexity:** High

#### Tasks
- [ ] Add `provider` field to config (anthropic, openai, ollama, lmstudio)
- [ ] Create `LLMClient` abstraction layer
- [ ] Implement `OpenAIClient` (parallel to `AnthropicClient`)
- [ ] Implement `OllamaClient` (local HTTP API)
- [ ] Implement `LMStudioClient` (local HTTP API)
- [ ] Prompt tuning per provider
- [ ] Config validation for provider-specific settings
- [ ] Unit tests with mocks
- [ ] Integration tests

**Files:**
- `tools/lib/local_review_llm.py` (refactor)
- `tools/lib/local_review_openai.py` (new)
- `tools/lib/local_review_ollama.py` (new)
- `g/config/local_agent_review.yaml` (update)

**Estimated Effort:** 2-3 days

---

### 2. Caching Reviews

**Priority:** Medium  
**Complexity:** Medium

#### Tasks
- [ ] Create cache key: `hash(diff_text + config_hash)`
- [ ] Store cache under `g/cache/local_agent_review/`
- [ ] Check cache before LLM call
- [ ] Return cached result if found
- [ ] Invalidate cache on config change
- [ ] Add `--no-cache` flag
- [ ] Cache TTL (optional: expire after N days)
- [ ] Unit tests

**Files:**
- `tools/lib/local_review_cache.py` (new)
- `tools/local_agent_review.py` (integrate)
- `g/cache/local_agent_review/` (directory)

**Estimated Effort:** 1-2 days

---

### 3. Batch Reviews & History

**Priority:** Low  
**Complexity:** Medium

#### Tasks
- [ ] Add `batch` mode: review multiple commits
- [ ] Add `range` queue: review commit range
- [ ] Create `g/reports/reviews/history.jsonl` (summarized)
- [ ] History format: `{ts, run_id, mode, exit_code, issues_count, files_count}`
- [ ] CLI command: `local_agent_review history`
- [ ] CLI command: `local_agent_review batch <commit1> <commit2> ...`
- [ ] Unit tests

**Files:**
- `tools/local_agent_review.py` (add modes)
- `g/reports/reviews/history.jsonl` (new)

**Estimated Effort:** 2 days

---

### 4. Retention Details Logging

**Priority:** Low  
**Complexity:** Low

#### Tasks
- [ ] Log which reports were deleted during rotation
- [ ] Add to telemetry: `retention_deleted: ["review_20251201_120000.md", ...]`
- [ ] Optional: log to `g/reports/reviews/retention_log.jsonl`
- [ ] Unit tests

**Files:**
- `tools/local_agent_review.py` (ReportGenerator._rotate_reports)

**Estimated Effort:** 0.5 days

---

### 5. Config UX Improvements

**Priority:** Low  
**Complexity:** Low

#### Tasks
- [ ] Support API key file path in config:
  ```yaml
  api:
    api_key_file: "~/.config/02luka/api_keys.yaml"
  ```
- [ ] Add `LOCAL_REVIEW_STRICT` environment variable default
- [ ] Config validation for file paths
- [ ] Unit tests

**Files:**
- `tools/lib/local_review_llm.py` (load from file)
- `tools/local_agent_review.py` (env var default)
- `g/config/local_agent_review.yaml` (documentation)

**Estimated Effort:** 0.5 days

---

## Implementation Priority

### Phase 2.3 (Current)
1. ✅ T1: Define schema (done, tightened)
2. T2-T8: Implement telemetry logging (one-record policy)

### Phase 3 (Future)
- Option 1: Multi-provider support (if needed)
- Option 2: Caching (if cost is concern)
- Option 3: Batch reviews (if workflow needs it)

### Phase 4 (Nice to Have)
- Retention details
- Config UX improvements

---

## Testing Strategy

### Phase 2.3 Tests

**Unit Tests:**
- Run ID generation (filename extraction, UUID fallback)
- Caller detection (manual, hook, ci)
- Snapshot ID extraction (from GitDrop output)
- Duration calculation (millisecond precision)

**Integration Tests:**
- Full chain: review → GitDrop → save
- Partial chain: review fails → skip GitDrop/save
- Offline mode: review with `--offline` → still log

**Test Files:**
- `tests/test_local_agent_review.py` (extend)
- `tests/test_unified_chain.py` (new)

---

## Dependencies

### Phase 2.3
- ✅ Local Agent Review (Phase 1 + 2.1 + 2.2)
- ✅ GitDrop (Phase 1)
- ✅ session_save.zsh (existing)

### Future Enhancements
- No blocking dependencies
- Can be implemented independently

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Telemetry file locking | Low | Use append-only (no locking needed) |
| ID propagation failures | Medium | Fallback to UUID, log warnings |
| Performance overhead | Low | Telemetry writes are fast (<1ms) |
| File size growth | Low | Rotate telemetry file (future) |

---

## Success Criteria

### Phase 2.3
- ✅ Unified telemetry schema defined (one-record policy, tightened)
- [ ] Run ID generated at chain start (single source of truth)
- [ ] Caller detection implemented (manual/hook/ci from context)
- [ ] Timing using `time.monotonic()` (millisecond precision)
- [ ] One-record policy: single JSONL append at chain end
- [ ] Local Agent Review collects data in-memory (returns dict)
- [ ] Unified chain script logs complete records
- [ ] Security block handling: skip GitDrop/Save on exit 3
- [ ] Config error handling: minimal log or nothing
- [ ] GitDrop optional: graceful skip
- [ ] All fields populated correctly (use `null` for missing)
- [ ] Tests passing (unit + integration)
- [ ] No network calls (offline-safe)
- [ ] Schema stable and grep-friendly

### Future Enhancements
- Implemented as needed based on usage feedback

---

## Related Documents

- [Telemetry Chain SPEC](./251206_local_agent_review_telemetry_chain_SPEC_v01.md)
- [Local Agent Review STATUS](./251206_local_agent_review_STATUS.md)
- [GitDrop SPEC](../gitdrop/251206_gitdrop_SPEC_v03.md)

---

**Next Steps:**
1. Review and approve SPEC
2. Begin Phase 2.3 implementation (T2-T7)
3. Consider future enhancements based on usage

---

**Last Updated:** 2025-12-06
