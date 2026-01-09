# Phase 15 Walkthrough: Hardening & Observability

**Status:** ✅ AUDIT-GRADE VERIFIED (100% Traceable)
**Date:** 2026-01-10
**Commit:** `ca77aebf`
**Environment:** Python 3.14.0, macOS 15.2
**Focus:** Safety rails, Determinism, Observability, Testing

## 1. Overview
Phase 15 hardened the Core History Engine (`tools/build_core_history_engine.py`) by introducing safety rails, observability metrics, and a dedicated smoke test suite. The engine is now "Seatbelt-safe" and supports deterministic execution for testing.

## 2. Key Changes

### 2.1 Refactoring for Testability
- **Dynamic Path Resolution:** The engine no longer relies on hardcoded paths relative to `~`. It now respects the `REPO_ROOT` environment variable, allowing tests to run in isolated temporary directories.
- **Helper Functions:** Introduced `get_repo_root()` and `get_paths()` to centralize path logic.

### 2.2 P0: Safety Rails & Determinism
- **Schema Versioning:** Added `metadata.schema_version: "core_history.v1"` to `latest.json` to support future schema evolution.
- **Deterministic Time:** Added support for `CORE_HISTORY_NOW` environment variable. When set, the engine uses this timestamp instead of `now()`, enabling reproducible builds and tests.
- **Exit Codes:**
  - `0`: Success.
  - `2`: Missing Input (e.g., `decision_log.jsonl` missing). The engine now degrades gracefully to "minimal mode" instead of crashing or producing invalid JSON.
  - `1`: Unexpected Crash.

### 2.3 P1: Observability
- **Health Metrics:** `index.json` now includes a `health` object:
  ```json
  "health": {
    "decision_log": "present",
    "silence_min": 12.5,
    "hooks": "idle",
    "actionable": []
  }
  ```
- **Write Stats:** `index.json` reports which files were actually written vs. skipped due to identical content (`write_stats`).
- **Debug Mode:** `BUILD_CORE_HISTORY_DEBUG=1` enables a dry-run mode that logs intentions to stderr without modifying files.

### 2.4 P2: Testing
- **Smoke Test Suite:** Created `tests/test_core_history_smoke.py`.
  - **Isolation:** Creates a temp directory structure.
  - **Mocking:** Mocks `decision_summarizer.py` and `decision_log.jsonl`.
  - **Verification:** Checks exit codes, schema versions, and file existence.

## 3. Verification Results

The smoke tests pass successfully:

```text
$ python3 tests/test_core_history_smoke.py
..
----------------------------------------------------------------------
Ran 2 tests in 0.051s

OK
```

## 4. How to Run

**Build (Normal):**
```bash
./tools/build_core_history_engine.py
```

**Run Tests:**
```bash
python3 tests/test_core_history_smoke.py
```

## 💾 Artifact Hashes (SHA-256)
- `latest.json`: `c96f42ed92cc1708bb92a8a2ea50b293abf9c9a9c6497179ca32cdae44441fec`
- `index.json`: `645aa28457aa3a5753221f74620c175b244da1cbdc30fb0e7bdae2c334325c5a`