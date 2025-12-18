## AI_OP_001_v5 — AI Operation Protocol v5 (Runtime-Truth Edition)

**Status**: ACTIVE (governing v5 stack)  
**Scope**: All AI-driven operations routed via Governance v5 (gateway v3 + router_v5 + sandbox_guard_v5 + wo_processor_v5 + CLC/CLS)  
**Goal**: Define how AI is allowed to change the 02LUKA system and files, in a way that is safe, auditable, and reversible.

---

## 1. Purpose and Relationship to Other Docs

- **AI_OP_001_v5** defines the **operational rules** for AI execution under Governance v5:
  - What AI can and cannot do.
  - How changes must be routed, guarded, and audited.
  - How human approval and CLC review are wired into the flow.
- It is designed to be **consistent with**:
  - `g/docs/GOVERNANCE_UNIFIED_v5.md` (unified law / architecture spec).
  - `g/manuals/PERSONA_LOADING_GUIDE.md` (persona loading / IDE integration for all 10 agents).
  - `bridge/core/router_v5.py` (lane + zone resolution).
  - `bridge/core/sandbox_guard_v5.py` (SIP / path safety).
  - `bridge/core/wo_processor_v5.py` (execution engine).

If there is ever a conflict:

- **Runtime truth wins** (actual code + telemetry).  
- This document must then be updated to match reality, not the other way around.

---

## 2. Core Concepts

### 2.1 Work Orders (WOs)

- All AI-powered changes must be driven by **explicit WOs**, not ad‑hoc edits.
- A WO must at minimum define:
  - `id` — unique identifier (e.g. `WO-YYYYMMDD-HHMMSS-...`).
  - `intent` — what the WO is trying to achieve (e.g. `apply_sip_patch`, `refactor_feature`, `update_docs`).
  - `summary` — human-readable description.
  - `priority`, `timeout`, and any relevant cost / risk caps.
  - `artifacts` — paths to plans / diffs / reports to be produced.

**Rule**: If a change cannot be explained via a WO, it is **not allowed** under AI_OP_001_v5.

### 2.2 Lanes and Zones (from Router v5)

- **Lanes** (how strict the execution is):
  - `FAST` — low-risk, auto-approved operations that can be executed locally.
  - `WARN` — medium-risk, requires extra checks but still local.
  - `STRICT` — high-risk, must be escalated to CLC for review/execution.
  - `BLOCKED` — must not execute (DANGER or out-of-policy).
- **Zones** (where in the filesystem / system an operation lands):
  - `OPEN` — safe, well-scoped areas (e.g. certain `g/docs/`, reports).
  - `LOCKED` — guarded but allowed with the right lane and conditions.
  - `DANGER` — must never be written/touched by AI.

Router v5 is responsible for mapping operations into **(zone, lane)** pairs under this protocol.

### 2.3 SIP (Single-Integrity Patch)

Referenced from `sandbox_guard_v5.py` (SIP requirements, Section 5.2 in the original spec):

- A **SIP** is a self-contained, auditable change unit that:
  - Has a clear **before/after**.
  - Can be applied or reverted atomically.
  - Has supporting evidence (tests, telemetry, reports).
- For AI-driven modifications to **code or critical scripts**, the default requirement is:
  - **One WO → one SIP** (or a clearly defined SIP set).

**Rule**: Multi‑step or multi‑file operations must still be decomposed into SIP‑style units with clear boundaries and revert paths.

---

## 3. Allowed vs Prohibited Operations

### 3.1 Allowed (with Proper Lane / Zone)

Examples of operations that are generally allowed, subject to routing:

- **Docs and reports**:
  - Update `g/docs/*.md` when:
    - The change reflects runtime truth.
    - It is tied to a WO and recorded in telemetry / MLS if relevant.
  - Generate or update reports under `g/reports/**` (e.g. PR-7 / PR-11 evidence).
- **Safe code edits** (typically `OPEN` or well-defined `LOCKED` zones):
  - Fixing bugs in governance v5 stack (`router_v5.py`, `sandbox_guard_v5.py`, `wo_processor_v5.py`, `gateway_v3_router.py`) **through WOs**.
  - Adding monitoring / telemetry improvements.
  - Adjusting LaunchAgent recipes when consistent with unified governance.
- **Ops utilities**:
  - Scripts under `tools/` that do not touch workspace symlink layout or sensitive data paths, as long as:
    - They adhere to git-safety and path-safety guidelines.
    - They are tested via WOs and acceptance scripts where applicable.

Each such operation is still subject to:

- Lane routing (`FAST`/`WARN`/`STRICT`) based on impact.
- SandboxGuard checks (SIP, path safety, traversal prevention).
- Telemetry logging.

### 3.2 Prohibited

The following are **categorically disallowed** for AI without explicit human intervention and out-of-band justification:

- **Workspace / repo separation violations**:
  - Creating real data directories inside repo for paths that must be symlinks (e.g. `bridge/`, `g/`, `g/data`, `g/telemetry`, `g/followup`, `bridge/processed`).
  - Removing or rewriting workspace symlinks without human‑approved WO.
- **Destructive git operations**:
  - Running `git clean -fd` or similar on `~/02luka`.
  - Rewriting history, force‑pushing branches associated with production evidence without explicit human sign‑off.
- **DANGER paths (per Router/SandboxGuard v5)**:
  - Any operation that resolves into `zone = DANGER`.
  - Any attempt to bypass traversal protections or null‑byte / newline guards.
- **Secret / credential exposure**:
  - Reading or emitting secrets in logs, reports, or WOs.
  - Modifying `.env.local` contents without strict, human-supervised WOs.

**Rule**: If SandboxGuard or Router v5 mark an operation as `BLOCKED`, AI_OP_001_v5 considers it **non‑negotiable**: the operation must not proceed.

---

## 4. Execution Flow under Governance v5

This section describes how a typical AI operation flows through the stack.

### 4.1 WO Lifecycle (Happy Path)

1. **WO creation**:
   - A WO file is created (usually in `bridge/inbox/entry` or `bridge/inbox/main` depending on channel) with clear intent/summary.
2. **Gateway intake**:
   - `gateway_v3_router.py` picks up WOs from the canonical inbox (lowercase, as normalized by config).
   - It decides whether to use the v5 stack (`use_v5_stack: true`).
3. **Routing**:
   - `router_v5.py` evaluates each operation within the WO:
     - Determines `zone` (OPEN / LOCKED / DANGER).
     - Determines `lane` (FAST / WARN / STRICT / BLOCKED).
4. **Guarding (SandboxGuard v5)**:
   - For each file / command:
     - Normalize path.
     - Enforce SIP requirements (single-integrity changes, clear boundaries).
     - Enforce traversal / safety rules.
5. **Execution (WO Processor v5)**:
   - `FAST` / `WARN` lanes:
     - Executed locally with proper logging and telemetry.
   - `STRICT` lane:
     - Converted into WOs for CLC (`bridge/inbox/clc`), where a human‑in‑the‑loop or a higher‑trust agent must review/execute.
   - `BLOCKED`:
     - Not executed; error / rejection is logged.
6. **Result and telemetry**:
   - The processor returns a `ProcessingResult` with status (`COMPLETED`, `EXECUTING`, `REJECTED`, `FAILED`).
   - The gateway moves the WO file to `processed` or `error` inboxes and records a `process_v5` entry in `gateway_v3_router.jsonl`.

### 4.2 CLS Auto-Approve Path (PR-10)

Specific to CLS “auto-approve”:

- If:
  - Target path is within **mission scope whitelist**.
  - Path is resolved into `zone = OPEN`.
  - No DANGER patterns are matched.
- Then:
  - Router v5 may assign **`lane = FAST`** (auto-approve).
  - CLS operation is executed without CLC involvement, but:
    - It is still logged and governed by SandboxGuard / SIP.

**Guarantee**: AI_OP_001_v5 requires that PR-10 semantics (OPEN + whitelist → FAST) are respected; silent demotion to `STRICT` while claiming auto-approve would be a protocol violation.

---

## 5. SIP Requirements (Referenced in SandboxGuard v5)

This section captures the essence of “SIP Requirements (AI_OP_001_v5 Section 5.2)” referenced in `sandbox_guard_v5.py`.

### 5.1 SIP Definition

Under this protocol, a **Single-Integrity Patch (SIP)** must:

- Have a **clearly defined scope**:
  - Known list of files.
  - Known expected structural changes (e.g. functions, sections).
- Be **deterministic**:
  - Applying the SIP multiple times has the same effect (idempotent at the content level).
- Be **reviewable**:
  - Produces a diff or patch that a human can inspect.
  - Tied back to a specific WO id and intent.

### 5.2 SIP Operational Rules

For operations affecting code / infra:

- **SIP‑1**: No mixed concerns.
  - A SIP must not combine **unrelated** fixes (e.g. router semantics + random refactor) into one opaque change.
- **SIP‑2**: No stray side‑effects.
  - WOs applying SIPs must not produce hidden side‑effects like:
    - Changing workspace symlinks.
    - Touching runtime data directories.
    - Editing unrelated config files.
- **SIP‑3**: Testability.
  - Wherever reasonable, a SIP should:
    - Be covered by, or at least compatible with, targeted tests (e.g. v5 test suites).
    - Not break existing acceptance tests for unrelated areas.
- **SIP‑4**: Revert path.
  - There must be a clear revert strategy:
    - Either via git (revert commit) or via an explicit revert WO/SIP.

SandboxGuard v5 can enforce or hint at SIP compliance by:

- Rejecting operations that touch too broad a set of files for a given WO.
- Flagging paths or actions that look like multi‑concern edits.

### 5.3 SIP Decision Table (Practical)

This table is a **guideline** for how to classify and design SIPs; it does not introduce new code behavior, it explains the intent.

| Change Type                                | Typical Scope                             | SIP?            | Notes                                                      |
|-------------------------------------------|-------------------------------------------|-----------------|------------------------------------------------------------|
| Fix typo in doc (`g/docs/*.md`)          | 1 file, 1–2 lines                         | 1 SIP           | Low‑risk, usually FAST lane if path is OPEN               |
| Update v5 doc + matching comment in code | 1 doc file + 1–2 small comment edits      | 1 SIP           | Same concern (governance spec + inline comments)          |
| Router v5 lane rule change               | 1–2 functions in `router_v5.py`           | 1 SIP           | Must be paired with tests / DRYRUN reports                |
| Router v5 + SandboxGuard v5 rewrite      | `router_v5.py` + `sandbox_guard_v5.py`    | 2 SIPs          | Split into “routing logic” vs “guard logic”               |
| Core router + random tool refactor       | `router_v5.py` + `tools/*.zsh` unrelated  | NOT 1 SIP       | Split into at least 2 WOs / SIPs                          |
| Workspace symlink layout change          | `tools/*`, symlink ops, guard scripts     | STRICT SIP only | Requires human‑approved WO and very clear revert path     |

**Example A — Good SIP**  
> WO: “Fix CLS auto-approve misrouting from STRICT to FAST for OPEN+whitelist paths”  
> SIP: Change decision branch in `router_v5.py` + add/adjust tests in `tests/v5_router/*`.  
> No other files touched. Revert = single git revert.

**Example B — Bad SIP**  
> WO: “Improve routing and also cleanup random scripts”  
> Change set: `router_v5.py` logic + multiple `tools/*.zsh` refactors + doc edits.  
> This mixes concerns and makes it hard to review or roll back safely → must be split.

---

## 6. Human-in-the-Loop and CLC/CLS Roles

AI_OP_001_v5 assumes:

- **CLS**:
  - Makes classification / approval decisions.
  - May auto‑approve under specific conditions (OPEN + whitelist).
  - Still operates within lane/zone and SandboxGuard constraints.
- **CLC**:
  - Acts as higher‑trust human/agent reviewer for `STRICT` lane.
  - Owns final say on high‑risk changes (e.g. core infra, security‑critical behavior).
- **Mary-COO**:
  - Coordinates WOs and high‑level routing, not a substitute for gateway or CLC/CLS.

Any attempt to bypass CLC/CLS by mis‑routing (`STRICT` work forced into `FAST` lane without meeting conditions) is a **protocol violation**.

---

## 7. Telemetry, Monitoring, and Evidence

Under this protocol, **every** AI‑driven operation of significance must leave evidence:

- **Gateway telemetry**:
  - `g/telemetry/gateway_v3_router.jsonl` records:
    - WO id, action, lane, status, target inbox, timestamps.
- **Monitor reports**:
  - `tools/monitor_v5_production.zsh` produces JSON summaries used for:
    - PR-7 operation counts.
    - PR-11 stability verification.
- **Health checks**:
  - `tools/system_health_check.zsh` and related scripts write to:
    - `g/reports/health/health_*.json`
    - `g/reports/pr11_healthcheck/*.json`
- **MLS lessons and audits**:
  - `~/02luka/tools/mls_capture.zsh` and MLS ledger form the **learning log**.

**Rule**: An AI operation that makes a non‑trivial change but leaves no telemetry / report / MLS trace is out of policy.

---

## 8. Incident Handling and Rollback

When Governance v5 detects or suspects a problem:

1. **Freeze further high‑risk changes**:
   - Temporarily restrict `STRICT` or sensitive `FAST` WOs until diagnosis is complete.
2. **Gather evidence**:
   - Telemetry segments from `gateway_v3_router.jsonl`.
   - Recent monitor outputs and health reports.
   - Relevant MLS lessons.
3. **Root cause analysis**:
   - Identify whether the failure was:
     - Routing error (wrong lane/zone).
     - Guard failure (SandboxGuard misconfiguration).
     - Implementation bug (e.g. in `router_v5.py`).
     - Operator misuse (WO not following AI_OP_001_v5).
4. **Apply corrective SIP(s)**:
   - Fix code / config using new WOs and SIP‑compliant patches.
   - Ensure changes are captured as PRs with clear merge/release notes.
5. **Update this document if needed**:
   - If the incident revealed a gap in AI_OP_001_v5, update the protocol text to match the **new**, safer behavior.

---

## 9. Checklist: Is an AI Operation v5‑Compliant?

Use this as a quick gate before trusting any AI‑driven change:

- **WO**:
  - [ ] Has a WO with clear id, intent, and summary?
  - [ ] Is the scope realistic and not mixing unrelated concerns?
- **Routing / Guarding**:
  - [ ] Routed through Governance v5 (router_v5 + sandbox_guard_v5 + wo_processor_v5)?
  - [ ] Lane and zone choices make sense for the risk level?
  - [ ] SandboxGuard confirms no DANGER or traversal violations?
- **SIP**:
  - [ ] Change can be understood as one or more SIPs?
  - [ ] No hidden side‑effects (symlinks, workspace structure, secrets)?
- **Human‑in‑the‑loop**:
  - [ ] For high‑risk changes, was CLC involved via STRICT lane?
  - [ ] CLS auto‑approve only used when conditions truly meet PR‑10 rules?
- **Evidence**:
  - [ ] Telemetry entries exist in `gateway_v3_router.jsonl`?
  - [ ] If relevant, monitor and healthcheck outputs reflect the change?
  - [ ] Any important lessons captured via MLS?

If any of these are “no”, the operation is **not compliant** with AI_OP_001_v5 and should be treated as unsafe until corrected.

