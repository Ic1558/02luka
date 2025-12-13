# System Truth Sync P0 — Implementation Plan

**Date:** 2025-12-10  
**Feature Slug:** `system_truth_sync_p0`  
**Status:** ✅ COMPLETE  
**Priority:** P0 (Sandbox-Safe, Read-Only)

---

## 🎯 Executive Summary

**Objective:** Create a read-only tool that generates system truth snapshots from sandbox health, gateway telemetry, and work order statuses.

**Solution:** Python CLI script that reads from allowlisted paths and outputs JSON + Markdown (no file writes).

**Impact:** Enables manual sync of system status into `02luka.md` without risk of automatic overwrites.

---

## 📋 Current State

### Before P0
- No automated way to sync system status
- Manual checking of multiple sources
- Risk of stale information in `02luka.md`

### Problems Solved
1. ✅ Centralized status collection
2. ✅ Structured output (JSON + Markdown)
3. ✅ Read-only safety (no accidental overwrites)

---

## 🎯 Target State

### After P0
- Single command generates complete snapshot
- JSON for automation/analysis
- Markdown block ready for paste
- Zero risk (read-only)

### Benefits
1. ✅ Fast status overview
2. ✅ Automation-ready (JSON)
3. ✅ Human-readable (Markdown)
4. ✅ Sandbox-safe (no writes)

---

## 📝 Implementation Tasks

### ✅ Task 1: Core Script Structure
- [x] Create `g/tools/system_truth_sync_p0.py`
- [x] Implement path helpers (`repo_root()`, `safe_under()`)
- [x] Define data models (dataclasses)
- [x] CLI argument parsing

### ✅ Task 2: Sandbox Health Reader
- [x] Implement `load_latest_sandbox_report()`
- [x] Handle missing files gracefully
- [x] Parse JSON health reports
- [x] Extract status, message, timestamp

### ✅ Task 3: Gateway Telemetry Reader
- [x] Implement `load_gateway_status()`
- [x] Read JSONL file (tail limit: 2000 lines)
- [x] Parse latest event
- [x] Extract telemetry metadata

### ✅ Task 4: Work Order Status Reader
- [x] Implement `extract_wo_status()`
- [x] Load YAML files (with PyYAML fallback)
- [x] Extract status, priority, owner, title
- [x] Handle missing files (report as unknown)

### ✅ Task 5: Output Generation
- [x] Implement `build_summary()`
- [x] Implement `render_markdown()`
- [x] JSON serialization (with `asdict()`)
- [x] Markdown block with clear markers

### ✅ Task 6: CLI Interface
- [x] `--json` flag (JSON only)
- [x] `--md` flag (Markdown only)
- [x] `--mode` flag (future use)
- [x] Default: both outputs

### ✅ Task 7: Testing & Validation
- [x] Test with real data sources
- [x] Verify JSON output structure
- [x] Verify Markdown format
- [x] Test error handling (missing files)

---

## 🧪 Test Strategy

### Unit Tests (Future)
- Path validation (`safe_under()`)
- JSON parsing (sandbox reports)
- JSONL parsing (gateway telemetry)
- YAML parsing (work orders)
- Markdown rendering

### Integration Tests (Manual)
- ✅ End-to-end execution
- ✅ Real file system paths
- ✅ Missing file handling
- ✅ Output format validation

### Test Results
```
✅ Markdown output: Valid format with markers
✅ JSON output: Valid structure
✅ Sandbox status: Correctly reads latest health report
✅ Gateway status: Correctly reads telemetry
✅ Work orders: Correctly extracts status from YAML
```

---

## 📊 Success Criteria

1. ✅ Script executes without errors
2. ✅ JSON output is valid and parseable
3. ✅ Markdown block has clear markers
4. ✅ No file writes (read-only verified)
5. ✅ Handles missing files gracefully
6. ✅ Path validation prevents directory traversal

**All criteria met.** ✅

---

## 🚀 Deployment

### Files Created
- `g/tools/system_truth_sync_p0.py` (executable)

### Dependencies
- Python 3.11+ (for `is_relative_to()`)
- PyYAML (optional, graceful fallback)

### Usage
```bash
cd ~/02luka
python g/tools/system_truth_sync_p0.py --md
```

---

## 🔄 Next Steps (P1)

### P1: Automated Writer Flow
- Design CLC/pipeline integration
- Scheduled execution (LaunchAgent)
- Automatic `02luka.md` updates
- Approval workflow

### P1: Extended Data Sources
- Agent status (Liam, Mary, etc.)
- Queue depths (Redis)
- LaunchAgent health
- System metrics

### P1: Enhanced Features
- Historical trends
- Status comparisons
- Alert generation
- Dashboard integration

---

## 📚 Related Work Orders

- **WO-20251113-SYSTEM-TRUTH-SYNC** (P0: ✅ Complete)
- Future: P1 writer flow (TBD)

---

## ✅ Completion Checklist

- [x] Script implemented
- [x] All data sources integrated
- [x] CLI interface complete
- [x] Error handling robust
- [x] Path validation secure
- [x] Output formats validated
- [x] Documentation created
- [x] Tested with real data

**P0 Status: ✅ COMPLETE**


