# Catalog Gate System — Implementation Plan

**Date:** 2025-12-10  
**Feature Slug:** `catalog_gate_system`  
**Status:** 📋 PLAN  
**Priority:** P1 (Critical)  
**Owner:** GG (System Orchestrator)

---

## 🎯 Problem Statement

**Current Issue:**
- LLM agents call tools directly from memory (e.g., `zsh tools/code_review_gate.zsh`)
- Even with catalog + documentation, agents don't follow 100%
- No structural enforcement → agents bypass catalog

**Root Cause:**
- LLM will not follow policy 100% without structural enforcement
- Agents remember paths from training data → use directly
- No "choke point" to force catalog usage

---

## 💡 Solution

**Single Wrapper Approach:**
- Create `run_tool.zsh` as **only** entry point
- All tool calls must go through wrapper
- Catalog lookup first, auto-discovery fallback (prevents blocking/lag)
- Tests enforce no direct tool calls

---

## 📋 Tasks

### Task 1: Create run_tool.zsh Wrapper ✅
- [x] Single entry point for all tools
- [x] Catalog lookup (preferred)
- [x] Auto-discovery fallback (warn but allow)
- [x] Helpful error messages

### Task 2: Update Catalog ✅
- [x] Add `code-review` entry
- [x] Add `run-tool` entry
- [x] Update usage examples to use `run_tool.zsh`

### Task 3: Create Tests
- [x] `test_catalog_integrity.py` — Check entry → file exists
- [x] `test_no_direct_tool_calls.sh` — Enforce wrapper usage
- [ ] Add to CI/Gate 1

### Task 4: Simplify Documentation
- [x] Reduce `AGENT_CATALOG_GATE.md` to 3 simple rules
- [x] Remove overkill sections (cache details, etc.)
- [x] Focus on "what to do" not "how it works internally"

### Task 5: Update All Docs/Specs
- [ ] Replace all `zsh tools/xxx.zsh` with `zsh tools/run_tool.zsh xxx`
- [ ] Update auto workflow spec
- [ ] Update HOWTO guides
- [ ] Update agent prompts

---

## 🧪 Test Strategy

### Test 1: Catalog Integrity
**File:** `tests/test_catalog_integrity.py`
**Checks:**
- Every `entry:` in catalog → file exists
- File is executable (or can be made executable)
- No orphaned entries

### Test 2: No Direct Tool Calls
**File:** `tests/test_no_direct_tool_calls.sh`
**Checks:**
- No `zsh tools/xxx.zsh` patterns in docs/code
- Must use `run_tool.zsh` wrapper
- Exceptions: `run_tool.zsh` itself, comments, tests

### Integration
- Add to Gate 1 (Design Quality)
- Add to Gate 2 (Code Quality)
- Fail PR if direct tool calls found

---

## ✅ Success Criteria

1. ✅ `run_tool.zsh` created and working
2. ✅ Catalog updated with new entries
3. ✅ Tests created and passing
4. ⏸️ All docs updated (in progress)
5. ⏸️ CI integration (pending)

---

## 📝 Notes

**Why Fallback?**
- Prevents blocking/lag when tool not in catalog
- Allows experimental tools without catalog update
- Warns to encourage catalog updates

**Catalog Scope:**
- Curated "official" tools only
- Not index of every file in `tools/`
- Experimental/junk excluded

---

**Status:** ✅ **Core Implementation Complete**  
**Next:** Update all docs/specs to use wrapper

