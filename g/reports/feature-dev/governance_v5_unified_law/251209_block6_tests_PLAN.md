# Block 6: Test Suites v5 — Implementation Plan

**Date:** 2025-12-10  
**Feature Slug:** `block6_tests_v5`  
**Status:** 📋 PLAN  
**Priority:** P0 (Critical for release)  
**Owner:** GG (System Orchestrator)  

---

## 🎯 Executive Summary

Goal: Build comprehensive test suites for Governance v5 stack (Router v5, SandboxGuard v5, SIP, CLC Executor v5, WO Processor v5, Health Checks) with fully automatic workflow and auto-redesign.

Impact: Ensures lane semantics, safety invariants, SIP discipline, WO routing correctness, and health monitoring are verified before production use.

---

## 📋 Scope

Components under test:
- Router v5 (`bridge/core/router_v5.py`)
- SandboxGuard v5 (`bridge/core/sandbox_guard_v5.py`)
- SIP (single-file; multi-file pending Block 4)
- CLC Executor v5 (`agents/clc/executor_v5.py`)
- WO Processor v5 (`bridge/core/wo_processor_v5.py`)
- Health check (`tools/check_mary_gateway_health.zsh`)

Out of scope:
- Multi-file SIP engine (Block 4) — add placeholder tests; full coverage later
- Performance/scale tests beyond smoke-level

---

## 📝 Tasks

### Task 1: Test Architecture
- [ ] Define test tree under `tests/v5_*`
- [ ] Select runners: `pytest` for Python, `zsh` harness for shell
- [ ] Add fixtures/mocks for filesystem and temp dirs

### Task 2: Router v5 Tests
- [ ] Lane semantics matrix (FAST/WARN/STRICT/BLOCKED)
- [ ] Mission Scope auto-approve
- [ ] DANGER invariant

### Task 3: SandboxGuard v5 Tests
- [ ] Path syntax (.. traversal, forbidden abs paths)
- [ ] Allowed roots
- [ ] Content forbidden patterns
- [ ] SIP compliance check (CLI mode)

### Task 4: CLC Executor v5 Tests
- [ ] WO validation
- [ ] STRICT execution path
- [ ] Rollback handler stubs
- [ ] Error handling

### Task 5: WO Processor v5 Tests
- [ ] Lane-based routing (STRICT→CLC, FAST/WARN→local, BLOCKED→reject)
- [ ] Local execution success/failure
- [ ] CLC WO creation schema
- [ ] Error paths

### Task 6: Health Check Tests
- [ ] LaunchAgent/process detection (mocked)
- [ ] Log activity freshness
- [ ] Inbox backlog thresholds
- [ ] JSON output contract

### Task 7: Reporting & CI
- [ ] Test summary report
- [ ] Hook into CI (if available) or manual runner script

---

## 🧪 Test Strategy

- **Unit:** Pure function tests (router decisions, path validation)
- **Integration:** WO routing end-to-end (MAIN inbox → lane → destination)
- **Contract:** JSON outputs (health check), WO schema
- **Negative:** DANGER paths, forbidden content, invalid WO
- **Smoke:** Minimal runs for each suite

Tools: `pytest`, `python -m pytest`, `zsh` for shell script checks; `tmpdir` fixtures.

---

## 📊 Success Criteria

1. ✅ All lane semantics validated (FAST/WARN/STRICT/BLOCKED)
2. ✅ SandboxGuard blocks DANGER/forbidden patterns; allows valid paths
3. ✅ STRICT lanes only → CLC; FAST/WARN execute locally
4. ✅ Health check outputs correct status JSON
5. ✅ Test suites run in <5 minutes locally
6. ✅ Zero failing tests; coverage on critical paths

---

## 🔗 Dependencies

- Block 1-3,5 DRYRUN specs (for reference)
- Auto Workflow v1 (fully automatic, no Boss approval)
- Block 4 (multi-file SIP) pending — add placeholder tests

---

## 📅 Timeline

- Phase 1: Test design + scaffolding (1-2h)
- Phase 2: Router/Sandbox/WO Processor tests (2-3h)
- Phase 3: CLC/Health check tests (1-2h)
- Phase 4: Report + CI hook (1h)

Total: ~5-8 hours

---

**Status:** 📋 PLAN Complete — Ready for SPEC


