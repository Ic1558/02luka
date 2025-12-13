# Block 6: Test Suites v5 — Implementation Specification

**Date:** 2025-12-10  
**Feature Slug:** `block6_tests_v5`  
**Status:** 📋 SPEC  
**Priority:** P0 (Critical)  
**Owner:** GG (System Orchestrator)  

---

## 🎯 Objective

Build comprehensive, automated test suites for Governance v5 stack, covering lane semantics, safety guards, WO routing, SIP discipline, and health monitoring — fully automatic, with auto-redesign if quality gates fail.

---

## 📐 Test Architecture

### Test Tree (to be created)
```
tests/
  v5_router/            # Router v5 lane/zone tests
  v5_sandbox/           # SandboxGuard v5 path/content tests
  v5_sip/               # SIP single-file (multi-file TBD Block 4)
  v5_clc/               # CLC executor tests
  v5_wo_processor/      # WO Processor v5 routing/local exec tests
  v5_health/            # Health check script tests
```

### Runners & Tools
- Python: `pytest`
- Shell: `zsh` (for health check script)
- Fixtures: `tmp_path/tmpdir`, monkeypatch for env/paths

### Quality Gates (Auto Workflow v1)
- Gate: Score >= 90/100
- Auto-redesign on failure (max 3 retries)
- No Boss approval required

---

## 🔧 Test Suites & Cases

### 1) Router v5 (`bridge/core/router_v5.py`)
- Lane Semantics Matrix:
  - CLI + OPEN → FAST
  - CLI + LOCKED → WARN (auto-approve check)
  - BACKGROUND → STRICT
  - DANGER → BLOCKED
- Mission Scope:
  - Whitelist paths auto-approve = True
  - Blacklist paths auto-approve = False
- Lawset outputs: contains GOVERNANCE_UNIFIED_v5 + HOWTO/AI_OP per world

### 2) SandboxGuard v5 (`bridge/core/sandbox_guard_v5.py`)
- Path Syntax:
  - Block `..`, block `/System`, `/usr`, `/etc`, `~/.ssh`
  - Allow clean rel paths in allowed roots
- Allowed Roots:
  - `apps/`, `tools/`, `agents/`, `g/reports/`, `g/docs/`, `bridge/`, `core/`, `launchd/`
  - Reject outside roots
- Content Safety:
  - Detect `rm -rf`, `sudo`, `curl | sh`, `chmod 777`, `kill -9`
- SIP Compliance (CLI mode):
  - Require temp file + checksums for BACKGROUND/LOCKED

### 3) SIP (Single-File; Multi-file TBD)
- Single-file SIP pattern:
  - mktemp → write full content → mv → checksum verify
- Negative: missing temp, missing checksum → block
- Placeholder: multi-file SIP tests marked xfail (pending Block 4)

### 4) CLC Executor v5 (`agents/clc/executor_v5.py`)
- WO Validation:
  - Missing required fields → fail
  - DANGER zone in zone_summary → fail
- STRICT Execution:
  - Creates audit log
  - Processes operations (add/modify/delete/move) with SIP
- Rollback Hooks:
  - Placeholder tests for rollback strategies (git_revert stub)

### 5) WO Processor v5 (`bridge/core/wo_processor_v5.py`)
- Lane Routing:
  - STRICT → creates CLC WO
  - FAST → executes locally (success path)
  - WARN auto-approve → executes locally
  - WARN no auto-approve → routes to CLC
  - BLOCKED → rejected to error inbox
- Local Execution:
  - Successful write (temp → mv) via SandboxGuard pass
  - Failure path (SandboxGuard block) → error recorded
- CLC WO Schema:
  - Contains required fields, operations, origin.world=BACKGROUND

### 6) Health Check (`tools/check_mary_gateway_health.zsh`)
- LaunchAgent detection (mock launchctl)
- Process detection (mock ps)
- Log activity freshness (mtime < 5m → ACTIVE)
- Inbox consumption (0/ <10 / >=10 files → HEALTHY/BACKLOG/STUCK)
- JSON contract validation

---

## 🧪 Test Data & Fixtures

- Temp repo root fixture (`tmp_path`) to simulate `/Users/icmini/02luka`
- Mock env vars: `LUKA_SOT`, `LUKA_ROOT`
- Sample WO files (YAML/JSON) for processor/CLC
- Sample content files for forbidden pattern checks

---

## 🚦 Execution Commands (Dry-Run Plan)

- Router: `pytest tests/v5_router`
- Sandbox: `pytest tests/v5_sandbox`
- SIP: `pytest tests/v5_sip`
- CLC: `pytest tests/v5_clc`
- WO Processor: `pytest tests/v5_wo_processor`
- Health: `pytest tests/v5_health` (or `zsh` harness)

Aggregated run: `pytest tests/v5_*`

---

## 📊 Quality Gates & Scoring

- Minimum score: 90/100
- Zero critical blockers
- Xfail allowed only for multi-file SIP (Block 4 pending)
- Auto-redesign if gate fails (up to 3 retries)

---

## 🔄 Redesign Policy

Trigger redesign when:
- Lane test fails
- Sandbox DANGER/block tests fail
- Health JSON contract fails
- Score < 90

Redesign steps:
1) Identify failing suite/case
2) Fix test or implementation mock/stub
3) Re-run affected suite

---

## 📈 Metrics

- Pass/fail counts per suite
- Lane correctness rate
- Sandbox block/allow accuracy
- WO routing correctness
- Health check accuracy
- Runtime (<5 minutes target)

---

## ✅ Success Criteria

1. All critical tests pass (router/sandbox/wo processor/health)
2. Score ≥ 90/100
3. No unhandled errors; xfail only for multi-file SIP
4. Test runtime <5 minutes

---

## 🧩 Files to Create (implementation phase)

- Test modules under `tests/v5_router/`, `tests/v5_sandbox/`, `tests/v5_sip/`, `tests/v5_clc/`, `tests/v5_wo_processor/`, `tests/v5_health/`
- Fixtures and sample WO files under `tests/fixtures/`

---

**Status:** 📋 SPEC Complete — Ready for DRYRUN (test skeleton generation)\n

