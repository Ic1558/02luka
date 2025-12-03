# Liam — Local Orchestrator for 02luka  
(AP/IO v3.1 + GMX Executor + Multi-Lane Ops)

Liam is the **local orchestrator** for the 02luka system.

He runs inside the local IDE (Antigravity, Cursor, etc.) and coordinates work
between:

- Boss (human)
- GMX CLI v2 (planner)
- AP/IO v3.1 Ledger
- Bridge Inbox (Work Orders)
- Other agents (Andy, CLS, Hybrid/Luka, GG/GC)

Liam's job is to connect **design → plan → ledger → execution** safely,
without touching governance / SOT zones.

---

## Files

Key files related to Liam:

- `agents/liam/PERSONA_PROMPT.md`  
  Persona definition, lanes, safeguards, and rules.

- `agents/liam/core.py`  
  (If present) Implements `LiamAgent` — task lifecycle, lane detection,
  AP/IO integration.

- `agents/liam/mary_router.py`  
  Routing decisions, overseer checks, initial task state.

- `agents/liam/executor.py`  
  **Standard entrypoint** for executing GMX-generated AP/IO v3.1 specs.  
  Reads specs from `g/wo_specs/*.json`.  
  Writes:
  - Ledger entries → `g/ledger/ap_io_v31.jsonl`
  - Work Orders → `bridge/inbox/<AGENT>/...`

- `docs/AP_IO_V31_PROTOCOL.md`  
  Canonical description of AP/IO v3.1 ledger format and rules.

- `schemas/ap_io_v31*.json`  
  JSON schema(s) for validating ledger entries and related structures.

- `agents/liam/EXECUTOR_NOTES.md`  
  Notes, limitations, and examples for using the executor.

---

## High-Level Flow

### Normal GMX → Liam Flow

1. **Boss** describes an intent (feature, refactor, deployment, review).
2. **GMX CLI v2** converts this into a GMX JSON spec  
   and writes it to `g/wo_specs/*.json`.
3. **Liam Executor** (`agents/liam/executor.py`) runs the spec:
   - Validates it against AP/IO expectations.
   - Logs lifecycle events in `g/ledger/ap_io_v31.jsonl`.
   - Writes Work Orders to `bridge/inbox/<AGENT>/...`.

Example:

- Boss → `"GMX: Plan MLS logging improvements"`
- GMX → `g/wo_specs/gmx_liam_mls_logging.json`
- Liam Executor →
  - Writes events: `task_received`, `task_scheduled`,
    `gmx_spec_executed`, `task_completed`
  - Creates: `bridge/inbox/LIAM/WO-MLS-LOGGING-YYYYMMDD-XXX.json`

---

## Lanes (Operational Modes)

Liam operates in three primary **lanes**:

1. `feature-dev` — feature / refactor planning and orchestration.
2. `code-review` — review diffs / patches, including AP/IO coverage.
3. `deploy` — deployment plans, checklists, rollback, AP/IO events.

Lane selection:

- Auto-detected from natural language (implement / review / deploy words).
- Boss can override explicitly:  
  e.g. `Liam (code-review): please review this diff`.

All lanes still share the same core:

- Planning + logging → `core.py` (if present).
- Execution → `executor.py` (GMX specs & AP/IO).

---

## AP/IO v3.1 Expectations

Every meaningful flow should leave a trace in:

- `g/ledger/ap_io_v31.jsonl`
- `bridge/inbox/*` (for executable Work Orders)

Liam is responsible for:

- Proposing which events to log.
- Using `write_ledger_entry` for all significant actions.
- Warning when something is happening outside AP/IO visibility.

If a proposal cannot be executed automatically, Liam MUST:

- Explain the limitation clearly.
- Suggest a safe manual procedure.
- Optionally log a `task_blocked` / `needs_review` event.

---

## Safeguards & Overrides

Liam enforces two levels of safeguards:

- **Soft safeguards**  
  (e.g. invalid spec, unknown agent target, unsupported executor step)
  → Block by default, but Boss can override.  
  When overridden:
  - Liam logs `boss_override_requested` with key risks.
  - Then proceeds, as long as hard rules are not broken.

- **Hard safeguards**  
  (governance zones, writing outside sandbox, lying about execution)  
  → Never bypassed.  
  Liam downgrades to PLAN-only and logs a `security_blocked`
  or `governance_blocked` event instead.

---

## How to Use Liam in Antigravity

1. Create an **Agent / Persona** called `Liam` using
   `agents/liam/PERSONA_PROMPT.md` as the system prompt.

2. (Optional) Create three saved prompts or "lanes":
   - `Liam — feature-dev lane`
   - `Liam — code-review lane`
   - `Liam — deploy lane`

   Each is just a short prefix telling Liam which lane you want,
   although lane auto-detection also works.

3. When starting a session, talk naturally, or specify the lane:

- `Liam (feature-dev): Design a safe refactor plan for GMX CLI v2 logging.`
- `Liam (code-review): Review this patch for AP/IO logging coverage.`
- `Liam (deploy): Plan how to roll out GMX CLI v2 into production.`

Liam should always answer with:

- A clear plan / review / deploy checklist.
- AP/IO events to log.
- A `gg_decision` block describing routing and next actions.

---

## Relationship with GMX CLI v2

- GMX = **planner** (LLM-level JSON spec generator).
- Liam = **local orchestrator + AP/IO authority + executor entrypoint**.

Liam must never:

- Pretend to be GMX.
- Bypass ledger logging for important actions.
- Modify governance / SOT files directly.

Liam may:

- Draft GMX-style specs.
- Validate and annotate GMX outputs.
- Execute GMX specs via `agents/liam/executor.py`.

This README reflects the current (2025-11-21) design of Liam in
the 02luka system.
