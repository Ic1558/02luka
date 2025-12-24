02LUKA OS — L3 Plan P0 (Spec Pack)
==================================

Last updated: 2025-12-24 (Asia/Bangkok)

Purpose
- Single entrypoint to start OS Layer 3 work immediately.
- Includes: P0 Freeze Declaration, L3 Plan P0 spec (schema/event types/CLI/scenario/success criteria), branch+lane guard, and an implementation prompt for Codex with verification requirements.

References
- docs/OS_READINESS_02LUKA.md — Readiness declaration (Kernel + Control Plane P0)
- docs/OS_VS_TOOL_BOUNDARY.md — OS vs Tools boundary rules
- docs/OS_ROADMAP_L3_P1.md — Roadmap (L3 multi-agent, Gateway v3 P1, Truth Sync P1)

----------------------------------------------------------------

1) OS P0 Freeze Declaration (Official)
--------------------------------------

Status
- OS Kernel + Control Plane P0 is considered frozen and ready for sandbox use.

In-scope (P0 frozen)
- L0: SQLite storage substrate (append-only), SHA-256 hash-chain tamper detection
- L1: Universal event log (immutable), verify_chain enforcement
- L2: Query interface (sessions, timelines, summaries, task timelines)
- Gateway v3 Phase 0: MAIN ingress → normalize → route (Mary-centric), sandbox-safe
- Truth Sync P0: runtime truth snapshot → JSON/MD (read-only)

Out-of-scope / Non-blockers
- ATG GC, tool hygiene, janitors/maintenance scripts, utility LaunchAgents (e.g., mcp.fs)

Freeze policy
- No breaking behavior changes to L0/L1/Gateway P0 without versioning and proof.
- New work must be additive: L3, Gateway P1, Truth Sync P1 (see roadmap).

----------------------------------------------------------------

2) L3 Plan P0 — Minimal Shared Plan + Coordination Spec
-------------------------------------------------------

Goal (L3 P0)
- Provide a shared plan/state model that multiple agents can read/write.
- Every plan mutation must be recorded as immutable events in L1.
- Provide a single CLI to query/apply plan operations in sandbox.
- Provide a demo scenario including conflict detection.

Non-goals (L3 P0)
- No scheduling/retry/priority (that is Gateway v3 Phase 1)
- No execution workers orchestration loop (future)
- No production path writes; sandbox-only

Scope / Locations (sandbox only)
- g/sandbox/os_l0_l1/schema/
- g/sandbox/os_l0_l1/tools/
- g/sandbox/os_l0_l1/scenarios/
- g/sandbox/os_l0_l1/logs/ (gitignored)

----------------------------------------------------------------

2.1 Schema (L0 State)
---------------------

File to add
- g/sandbox/os_l0_l1/schema/plan_schema.sql

Tables (minimal)
1) plans
- plan_id TEXT PRIMARY KEY
- title TEXT NOT NULL
- owner_agent TEXT NOT NULL
- status TEXT NOT NULL            -- e.g., ACTIVE / ARCHIVED
- version INTEGER NOT NULL        -- increments on mutation
- created_ts TEXT NOT NULL        -- ISO8601
- updated_ts TEXT NOT NULL        -- ISO8601

2) plan_items
- item_id TEXT PRIMARY KEY
- plan_id TEXT NOT NULL           -- FK to plans(plan_id)
- kind TEXT NOT NULL              -- e.g., TASK / NOTE / CHECK
- title TEXT NOT NULL
- state TEXT NOT NULL             -- TODO / IN_PROGRESS / DONE / BLOCKED
- priority INTEGER NOT NULL
- assigned_to TEXT                -- agent id
- due_ts TEXT                     -- ISO8601 optional
- version INTEGER NOT NULL
- created_ts TEXT NOT NULL
- updated_ts TEXT NOT NULL

3) plan_links (optional minimal)
- link_id TEXT PRIMARY KEY
- from_item_id TEXT NOT NULL
- to_item_id TEXT NOT NULL
- link_type TEXT NOT NULL         -- e.g., DEPENDS_ON / RELATED

Versioning rule
- plans.version increments on any plan-level mutation
- plan_items.version increments on any item-level mutation
- conflict detection uses expected_version vs current_version

----------------------------------------------------------------

2.2 L1 Event Types (Immutable Log)
----------------------------------

Required event_type values
- PLAN_CREATED
- PLAN_ITEM_ADDED
- PLAN_ITEM_UPDATED
- PLAN_ITEM_STATE_CHANGED
- PLAN_CONFLICT_DETECTED

General payload shape (JSON)
{
  "plan_id": "P-L3-DEMO-001",
  "item_id": "I-001",
  "actor": "Liam",
  "action": "STATE_CHANGE",
  "expected_version": 3,
  "new_version": 4,
  "change": { "state": "IN_PROGRESS" }
}

Event logging contract
- Every successful mutation must emit an L1 event.
- Conflict attempts must emit PLAN_CONFLICT_DETECTED.
- verify_chain must pass after running the scenario.

----------------------------------------------------------------

2.3 CLI (Single Entry) — os_l3_plan.py
--------------------------------------

File to add
- g/sandbox/os_l0_l1/tools/os_l3_plan.py

Constraints
- Sandbox allowlist enforcement (same spirit as existing sandbox tools)
- Default DB: g/sandbox/os_l0_l1/data/os_sandbox.db (override via --db allowed)
- Output: JSON to stdout (machine-friendly)

Commands (required)
- list-plans
- show-plan --plan-id <ID>
- list-items --plan-id <ID>
- apply-scenario <path/to/json>

Behavior requirements
- apply-scenario:
  - reject absolute paths and repo-prefixed paths
  - validate required fields and version expectations
  - write DB state + emit L1 events per step
  - produce a clear JSON result including counts and any conflicts

----------------------------------------------------------------

2.4 Scenario (Demo) — L3_PLAN_FLOW_001
--------------------------------------

File to add
- g/sandbox/os_l0_l1/scenarios/L3_PLAN_FLOW_001.json

Scenario steps (example outline)
1) Create plan P-L3-DEMO-001 (owner: Liam)
2) Add two plan_items:
   - I-001: "Create schema + CLI skeleton" (assigned_to: Codex)
   - I-002: "Run scenario + verify_chain" (assigned_to: Liam)
3) State change:
   - I-001 TODO → IN_PROGRESS
   - I-001 IN_PROGRESS → DONE
4) Conflict simulation:
   - Attempt to update I-002 with a stale expected_version
   - Expect: PLAN_CONFLICT_DETECTED event

----------------------------------------------------------------

2.5 Success Criteria (L3 P0)
----------------------------

Must pass
- init_db + apply scenario completes without manual intervention
- verify_chain passes (no tamper / broken chain)
- list-plans returns the created plan
- show-plan and list-items return consistent state + versions
- conflict attempt produces PLAN_CONFLICT_DETECTED in L1 timeline

Non-blocking
- Performance, caching, UX polish
- Scheduler/dispatching integration

----------------------------------------------------------------

3) Branch + Lane Guard (Codex CLI)
----------------------------------

Branch
- feat/os-l3-plan-p0

Commit tag convention
- Prefix commits with: [OS:L3:P0]

File scope guard
- Allowed paths:
  - g/sandbox/os_l0_l1/**
  - docs/** (only if updating docs; avoid unless needed)
- Disallowed:
  - core runtime prod paths
  - any non-sandbox service configs

----------------------------------------------------------------

4) Prompt for Codex (Implementation + Verification)
---------------------------------------------------

Task
- Implement 02LUKA OS Layer 3 Plan P0 in sandbox only.

Branch
- feat/os-l3-plan-p0

Constraints
- Sandbox-only: do not touch production paths.
- Preserve OS integrity: verify_chain must pass after scenario run.
- Do not claim completion without proof outputs.

Deliverables
1) Add schema:
   - g/sandbox/os_l0_l1/schema/plan_schema.sql
   - tables: plans, plan_items, plan_links (minimal)
2) Add CLI:
   - g/sandbox/os_l0_l1/tools/os_l3_plan.py
   - commands: list-plans, show-plan, list-items, apply-scenario
   - sandbox allowlist enforced; JSON output
3) Add scenario:
   - g/sandbox/os_l0_l1/scenarios/L3_PLAN_FLOW_001.json
   - includes conflict simulation step
4) Ensure every plan mutation emits an L1 event with event_type:
   - PLAN_CREATED, PLAN_ITEM_ADDED, PLAN_ITEM_UPDATED, PLAN_ITEM_STATE_CHANGED, PLAN_CONFLICT_DETECTED
5) Healthcheck wiring:
   - include L3 scenario in "extended" mode only (not default)
   - e.g., tools/healthcheck.zsh --extended runs L3

Verification (must show output)
- From sandbox root:
  - tools/init_db.zsh
  - python tools/os_l3_plan.py apply-scenario scenarios/L3_PLAN_FLOW_001.json
  - tools/verify_chain.zsh data/os_sandbox.db  → chain_status: OK
  - python tools/os_l3_plan.py list-plans
  - python tools/os_l3_plan.py list-items --plan-id P-L3-DEMO-001
- Show evidence that conflict step emitted PLAN_CONFLICT_DETECTED:
  - python tools/os_l2_query.py session-timeline --session-id <session_id_used_in_scenario>
    OR
  - python tools/os_l2_query.py task-timeline --task-id <task_id_used_in_scenario>

End
- If all verifications pass, summarize exactly what changed (paths + commands + outputs).

----------------------------------------------------------------

4.1 Evidence (2025-12-24 sandbox run)
-------------------------------------
- Commands run:
  - zsh g/sandbox/os_l0_l1/tools/init_db.zsh
  - (cd g/sandbox/os_l0_l1 && python3 tools/os_l3_plan.py --db data/os_sandbox.db apply-scenario scenarios/L3_PLAN_FLOW_001.json)
  - zsh g/sandbox/os_l0_l1/tools/verify_chain.zsh
  - (cd g/sandbox/os_l0_l1 && python3 tools/os_l3_plan.py --db data/os_sandbox.db list-plans)
  - (cd g/sandbox/os_l0_l1 && python3 tools/os_l3_plan.py --db data/os_sandbox.db list-items --plan-id P-L3-DEMO-001)
  - zsh g/sandbox/os_l0_l1/tools/healthcheck.zsh --extended
- Key outputs:
  - apply-scenario: plan_created=true, items_added=2, item_updates=1, state_changes=2, conflicts=1, events_written=7
  - verify_chain: chain_status=OK, events=7, mismatches=[]
  - list-plans: P-L3-DEMO-001 ACTIVE, version=1
  - list-items: I-001 DONE version=3; I-002 TODO version=2
  - healthcheck --extended: re-ran init + scenario + verify-chain + list commands, all OK (reproducible)

----------------------------------------------------------------

5) Start Work (Operator Steps)
------------------------------

If starting immediately:
1) git checkout -b feat/os-l3-plan-p0
2) open docs/OS_L3_PLAN_P0.md
3) run the prompt in section (4) in Codex CLI
