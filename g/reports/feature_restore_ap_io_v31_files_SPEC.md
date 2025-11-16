# Feature SPEC: Restore AP/IO v3.1 Protocol Files

**Feature:** Restore missing AP/IO v3.1 protocol implementation files  
**Date:** 2025-11-17  
**Status:** Draft  
**Priority:** CRITICAL (Blocking Phase 1 merge)

---

## Executive Summary

Restore 23 missing AP/IO v3.1 protocol files that were lost from the workspace. These files are critical infrastructure for agent event logging and cross-agent communication. Restoration must be completed before merging Phase 1 (Emergency Monitoring).

**Goal:** Restore all AP/IO v3.1 files from git history or recreate from SPEC/PLAN documentation.

---

## Problem Statement

### Critical Issue
- **23 AP/IO v3.1 files missing** from workspace
- **Impact:** System cannot function without these files
- **Status:** CRITICAL - blocking Phase 1 merge

### Missing Files Breakdown

**Core Protocol Tools (6 files):**
- `tools/ap_io_v31/writer.zsh` - Write ledger entries
- `tools/ap_io_v31/reader.zsh` - Read/filter ledger entries
- `tools/ap_io_v31/validator.zsh` - Validate messages
- `tools/ap_io_v31/correlation_id.zsh` - Generate correlation IDs
- `tools/ap_io_v31/router.zsh` - Route events
- `tools/ap_io_v31/pretty_print.zsh` - Pretty print entries

**Schemas (2 files):**
- `schemas/ap_io_v31.schema.json` - Protocol schema
- `schemas/ap_io_v31_ledger.schema.json` - Ledger entry schema

**Documentation (4 files):**
- `docs/AP_IO_V31_PROTOCOL.md` - Main protocol documentation
- `docs/AP_IO_V31_INTEGRATION_GUIDE.md` - Integration guide
- `docs/AP_IO_V31_ROUTING_GUIDE.md` - Routing guide
- `docs/AP_IO_V31_MIGRATION.md` - Migration guide

**Agent Integrations (5 files):**
- `agents/cls/ap_io_v31_integration.zsh`
- `agents/andy/ap_io_v31_integration.zsh`
- `agents/hybrid/ap_io_v31_integration.zsh`
- `agents/liam/ap_io_v31_integration.zsh`
- `agents/gg/ap_io_v31_integration.zsh`

**Tests (6 files):**
- `tests/ap_io_v31/cls_testcases.zsh`
- `tests/ap_io_v31/test_protocol_validation.zsh`
- `tests/ap_io_v31/test_routing.zsh`
- `tests/ap_io_v31/test_correlation.zsh`
- `tests/ap_io_v31/test_backward_compat.zsh`
- `tools/run_ap_io_v31_tests.zsh`

---

## Solution Approach

### Option 1: Restore from Git History (Preferred)
- Search git history for AP/IO v3.1 files
- Restore files from last known good commit
- Verify files are complete and functional

### Option 2: Recreate from SPEC/PLAN (Fallback)
- Use existing SPEC/PLAN documents as source of truth
- Recreate files based on documented requirements
- Ensure compatibility with existing system

### Option 3: Hybrid Approach (Recommended)
- Restore what exists in git history
- Recreate missing files from SPEC/PLAN
- Verify all files are complete

---

## Functional Requirements

### Core Protocol Tools

**writer.zsh:**
- Write AP/IO v3.1 ledger entries to JSONL files
- Generate `ledger_id` (format: `ledger-YYYYMMDD-HHMMSS-<agent>-<seq>`)
- Generate `correlation_id` when needed
- Accept `parent_id` and `execution_duration_ms` as arguments
- Write compact JSON (one object per line)
- Support `LEDGER_BASE_DIR` for test isolation

**reader.zsh:**
- Read JSONL ledger files
- Filter by: agent, event.type, correlation_id, parent_id
- Parse extension fields: ledger_id, parent_id, execution_duration_ms
- Support date-based file selection

**validator.zsh:**
- Validate AP/IO v3.1 messages against schema
- Reject non-3.1 messages
- Validate ledger_id format
- Validate parent_id format
- Validate execution_duration_ms type

**correlation_id.zsh:**
- Generate unique correlation IDs
- Format: `corr-YYYYMMDD-NNN`
- Use microseconds or process ID for uniqueness

**router.zsh:**
- Route AP/IO v3.1 events to target agents
- Support single/multiple targets
- Support broadcast

**pretty_print.zsh:**
- Pretty print ledger entries
- Support summary, timeline, grouping, filtering
- Format output for readability

### Schemas

**ap_io_v31.schema.json:**
- Protocol schema for AP/IO v3.1 messages
- Required fields: protocol, version, agent, event
- Optional fields: data, metadata

**ap_io_v31_ledger.schema.json:**
- Schema for ledger entries
- Extension fields: ledger_id, parent_id, execution_duration_ms
- Format validation for each field

### Agent Integrations

**Integration Scripts:**
- Hook into agent execution
- Write ledger entries at key points
- Support correlation_id reuse
- Support parent_id linking

### Tests

**Test Files:**
- Protocol validation tests
- Ledger ID generation tests
- Parent ID support tests
- Execution duration tests
- Backward compatibility tests
- Integration tests

**Test Runner:**
- Run all test files
- Report pass/fail
- Provide summary

---

## Technical Requirements

### File Locations
- **Tools:** `~/02luka/tools/ap_io_v31/`
- **Schemas:** `~/02luka/schemas/`
- **Tests:** `~/02luka/tests/ap_io_v31/`
- **Docs:** `~/02luka/docs/`
- **Agents:** `~/02luka/agents/<agent>/ap_io_v31_integration.zsh`

### Dependencies
- `jq` - JSON processing
- `zsh` - Shell scripting
- Python 3 (for some tests)

### Compatibility
- **Backward Compatible:** Must support v1.0 ledger format
- **Extension Fields:** Optional (backward compatible)
- **Protocol Version:** 3.1 only

---

## Success Criteria

### Restoration
- ✅ All 23 files restored or recreated
- ✅ All files pass syntax validation
- ✅ All files are executable (scripts)
- ✅ All files are in correct locations

### Functionality
- ✅ All tools work correctly
- ✅ All tests pass
- ✅ Integration with agents works
- ✅ Backward compatibility maintained

### Quality
- ✅ Code follows 02LUKA standards
- ✅ Error handling comprehensive
- ✅ Documentation complete
- ✅ Tests comprehensive

---

## Non-Goals

- **Not modifying:** Existing working AP/IO v3.1 files (if any exist)
- **Not changing:** Protocol specification (restore as-is)
- **Not adding:** New features (restore only)

---

## Dependencies

### Existing Infrastructure
- ✅ Git history (for restoration)
- ✅ SPEC/PLAN documents (for recreation)
- ✅ Existing 02LUKA infrastructure

### Required Tools
- `git` - For history search
- `jq` - For JSON processing
- `zsh` - For scripts

---

## Risks & Mitigation

| Risk | Impact | Mitigation |
|------|--------|------------|
| Files not in git history | High | Recreate from SPEC/PLAN |
| Incomplete restoration | Medium | Verify all files exist and work |
| Breaking changes | High | Test backward compatibility |
| Missing dependencies | Medium | Check and install dependencies |

---

## Open Questions

1. **Git History:** Are AP/IO v3.1 files in git history?
2. **Last Known Good:** What commit had working AP/IO v3.1 files?
3. **SPEC/PLAN:** Are SPEC/PLAN documents complete enough for recreation?
4. **Dependencies:** Are all dependencies available?

---

**Status:** Ready for PLAN creation  
**Next Step:** Create detailed implementation PLAN with tasks and test strategy
