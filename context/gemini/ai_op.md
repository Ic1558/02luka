# AI Operation Protocol Summary (02luka)

**Source of Truth**: `g/docs/AI_OP_001_v5.md`  
**Last Synced**: 2025-12-18  
**Version**: v5

---

## Core Rules

### Work Orders (WOs)
- All AI-powered changes must be driven by **explicit WOs**, not ad-hoc edits.
- WO must define: `id`, `intent`, `summary`, `priority`, `timeout`, `artifacts`.
- **Rule**: If a change cannot be explained via a WO, it is **not allowed**.

### Lanes and Zones
- **Lanes** (execution strictness):
  - `FAST` — low-risk, auto-approved (local execution)
  - `WARN` — medium-risk, extra checks (local execution)
  - `STRICT` — high-risk, escalate to CLC
  - `BLOCKED` — must not execute (DANGER or out-of-policy)
- **Zones** (filesystem location):
  - `OPEN` — safe, well-scoped areas
  - `LOCKED` — guarded but allowed with right lane/conditions
  - `DANGER` — must never be written/touched by AI

### SIP (Single-Integrity Patch)
- Self-contained, auditable change unit
- Clear before/after
- Can be applied or reverted atomically
- For code changes: **One WO → one SIP** (or clearly defined SIP set)

## Allowed Operations

- **Docs and reports**: Update `g/docs/*.md` when change reflects runtime truth
- **Safe code edits**: Fixing bugs in governance v5 stack **through WOs**
- **Ops utilities**: Scripts under `tools/` (adhere to git-safety and path-safety)

## Prohibited Operations

- **Workspace/repo separation violations**: Creating real data directories inside repo for paths that must be symlinks
- **Destructive git operations**: `git clean -fd`, force-pushing production branches without human sign-off
- **DANGER paths**: Any operation that resolves into `zone = DANGER`
- **Secret/credential exposure**: Reading or emitting secrets in logs/reports/WOs

## Execution Flow

1. **WO creation** → `bridge/inbox/entry` or `bridge/inbox/main`
2. **Gateway intake** → `gateway_v3_router.py` picks up WOs
3. **Routing** → `router_v5.py` evaluates (zone + lane)
4. **Guarding** → `sandbox_guard_v5.py` enforces SIP + path safety
5. **Execution** → `wo_processor_v5.py` (FAST/WARN local, STRICT → CLC)
6. **Result and telemetry** → WO moved to `processed`/`error`, telemetry logged

## Telemetry Requirements

- **Gateway telemetry**: `g/telemetry/gateway_v3_router.jsonl`
- **Monitor reports**: `tools/monitor_v5_production.zsh`
- **Health checks**: `g/reports/health/health_*.json`
- **MLS lessons**: `~/02luka/tools/mls_capture.zsh`

**Rule**: An AI operation that makes a non-trivial change but leaves no telemetry/report/MLS trace is out of policy.

---

**For full details, see**: `g/docs/AI_OP_001_v5.md`
