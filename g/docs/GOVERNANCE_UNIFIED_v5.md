## Governance v5 — Unified Law (Runtime-Truth Edition)

**Status**: WIRED (integrated in production), battle-tested, in stability window (PR-11)  
**Scope**: Gateway v3 router, Router v5, SandboxGuard v5, WO Processor v5, Mary-COO, inbox / telemetry infrastructure  
**Goal**: 02LUKA governance must not lie — this document reflects what actually runs today.

---

## 1. Big Picture

- **Single gateway**: Exactly **one** `gateway_v3_router.py` process owns the main inbox.
- **Mary-COO separation**: `agents/mary/mary.py` runs as COO only; it **does not** run the gateway router.
- **v5 routing stack**:
  - `bridge/core/router_v5.py` = lane + zone resolution (FAST / WARN / STRICT / BLOCKED).
  - `bridge/core/sandbox_guard_v5.py` = path/content guard for filesystem and command safety.
  - `bridge/core/wo_processor_v5.py` = lane execution engine (FAST/WARN local, STRICT → CLC).
- **Lowercase inbox standard**:
  - Canonical directories are **lowercase**: `main`, `clc`, `cls`, `entry`, `gemini`, `lpe`, `rnd`, `llm`, `rd`, `lac`, `liam`, `hybrid`, etc.
  - Uppercase names (e.g. `CLC`, `MAIN`, `GEMINI`) are **symlinks only**, never primary paths.
- **Telemetry**:
  - Canonical gateway telemetry file: `g/telemetry/gateway_v3_router.jsonl` (NDJSON).
  - `tools/monitor_v5_production.zsh` reads from this JSONL and from the gateway config.

---

## 2. Core Components and Responsibilities

### 2.1 Gateway v3 Router

- **File**: `agents/mary_router/gateway_v3_router.py`
- **LaunchAgent**: `com.02luka.mary-gateway-v3`
- **Responsibilities**:
  - Watch **main inbox** and dispatch WOs via the v5 stack (when `use_v5_stack: true`).
  - Move processed WOs to `processed` or `error` directories.
  - Emit telemetry events (**JSONL**) describing each operation.
- **Key guarantees**:
  - Exactly **one** process active in production.
  - No hidden/duplicate gateway via Mary-COO.
  - Consistent telemetry format and file path.

#### 2.1.1 Configuration (Source of Truth)

- **File**: `g/config/mary_router_gateway_v3.yaml`
- **Important fields**:
  - `telemetry.log_file`: `"g/telemetry/gateway_v3_router.jsonl"`
  - `directories.inbox`: e.g. `"bridge/inbox_local/main"` (normalized to lowercase)
  - `directories.processed`: e.g. `"bridge/processed_local/main"` (normalized)
  - `directories.error`: e.g. `"bridge/error_local/main"` (normalized)
  - `use_v5_stack`: `false` or `true`

**Rule**: All ops / monitor tooling must **read inbox/processed/error paths from this config**, then normalize to lowercase, instead of hardcoding `bridge/inbox/MAIN`, `bridge/inbox/CLC`, etc.

#### 2.1.2 Status Handling (v5)

For v5 stack operations, the gateway must treat **all** statuses explicitly:

- `COMPLETED` — move WO to processed, emit success telemetry.
- `EXECUTING` — long-running; mark appropriately in telemetry.
- `REJECTED` — move WO to error, **still** log as v5 processing attempt (no silent drop).
- `FAILED` — move WO to error, log failure with reason.

All four statuses must be **visible** as `action="process_v5"` telemetry entries; no status may silently bypass logging.

---

### 2.2 Router v5

- **File**: `bridge/core/router_v5.py`
- **Purpose**: Kernel-grade routing logic for governance v5.
- **Responsibilities**:
  - Resolve **zone** for each path / operation: `OPEN`, `LOCKED`, `DANGER`.
  - Resolve **lane** for each operation: `FAST`, `WARN`, `STRICT`, `BLOCKED`.
  - Implement CLS auto-approve semantics (PR-10).

#### 2.2.1 DANGER Patterns

`DANGER_PATTERNS` defines **hard-block** conditions for paths or commands that are never safe.

- **Must NOT** include:
  - Extremely broad or ineffective patterns like `r"^/$"` or unanchored `rm -rf.*02luka` that are never actually matched or are mis-placed.
- **Must** include:
  - Path traversal and null-byte / newline variants that have been observed or fuzz-tested.
  - Examples (conceptual, not exhaustive):
    - `../` / `..\` patterns escaping repositories.
    - Mixed traversal like `./../` chains used to escape `LUKA_SOT`.
    - Dangerous byte sequences such as embedded `\0` or `\n` in path segments.

**Rule**: Any path matching `DANGER_PATTERNS` must:

- Resolve to `zone = DANGER`.
- Force `lane = BLOCKED` regardless of hints or whitelist.
- Emit explicit telemetry describing the block reason.

#### 2.2.2 CLS Auto-Approve (PR-10)

**Intent**: Certain CLS operations are safe enough to **auto-approve** into the `FAST` lane when:

- The path is in an allowed mission scope (e.g. `MISSION_SCOPE_WHITELIST`).
- The path's zone is **OPEN**.
- Other policy checks (e.g. no DANGER pattern, no privileged paths) pass.

**Rule**:

- `check_cls_auto_approve_conditions`:
  - **Must** allow auto-approve when **zone is OPEN** and path is in `MISSION_SCOPE_WHITELIST`.
  - **Must NOT** silently downgrade to `STRICT` if all auto-approve conditions pass.

**Expected behavior**:

- CLS auto-approve WOs should be routed:
  - `lane = FAST`
  - Reflected in telemetry and in PR-10 validation tools

#### 2.2.3 Lane Decision Table (Intent)

This table summarizes the **intended** mapping from risk profile to lanes. The actual implementation lives in `router_v5.py`; this section documents it for humans.

| Scenario / Risk Level                                       | Example                                      | Expected Lane | Notes                                                               |
|-------------------------------------------------------------|----------------------------------------------|---------------|---------------------------------------------------------------------|
| Low‑risk, OPEN zone, within CLS mission scope whitelist    | CLS auto-approve on allowed doc path         | FAST          | PR-10: OPEN + whitelist → FAST (no silent downgrade)               |
| Low‑risk, OPEN zone, non‑CLS (e.g. simple doc update)      | Update `g/docs/*.md` spec text               | FAST/WARN     | Depends on intent; often FAST if clearly safe                       |
| Medium‑risk config / monitoring change in LOCKED zone      | Tweak `tools/monitor_v5_production.zsh`      | WARN          | Needs extra scrutiny but can be local when guarded                  |
| High‑risk governance or security logic change              | Change in `router_v5.py` or `sandbox_guard_v5.py` | STRICT        | Must create CLC WO and go through STRICT lane                       |
| Workspace / symlink layout modification                    | Changing `bridge` / `g` symlinks             | STRICT/BLOCKED| Generally out of scope for AI; requires human‑owned, audited WOs    |
| Any operation matching `DANGER_PATTERNS` or DANGER zone    | Path traversal out of SOT / null‑byte path   | BLOCKED       | Must never execute; router and SandboxGuard enforce hard block      |

**Rule**: If a change’s effective risk profile does not match the lane it is routed to, that is a **governance bug** and must be corrected either in `router_v5.py` or in this table (if the risk classification itself changes).

---

### 2.3 SandboxGuard v5

- **File**: `bridge/core/sandbox_guard_v5.py`
- **Purpose**: Security and safety guard for filesystem and command operations.
- **Responsibilities**:
  - Sanitize and normalize paths.
  - Enforce workspace boundaries (`/Users/icmini/02luka` and workspace symlinks).
  - Reject clearly unsafe operations before execution.

**Key principles**:

- **Normalize first**, then decide:
  - Resolve `..`, symlinks (where safe), and redundant segments.
  - Evaluate against **post-normalization** path, not raw user input.
- **Explicitly guard**:
  - Traversal outside of allowed roots.
  - Writes into workspace roots that should only be symlinks (e.g. `bridge`, `g` inside repo).
  - Dangerous byte patterns (null/newline) that can break shell or tooling.

---

### 2.4 WO Processor v5

- **File**: `bridge/core/wo_processor_v5.py`
- **Purpose**: Execute WOs under the lane-based governance model.
- **Main flow** (`process_wo_with_lane_routing`):
  1. Read WO from `bridge/inbox/main/` (lowercase).
  2. Use Router v5 to compute lane per operation.
  3. Route `STRICT` operations to CLC.
  4. Execute `FAST` and `WARN` operations locally.
  5. Emit telemetry and result object to the gateway.

**Important path guarantees**:

- `read_wo_from_main` reads strictly from `bridge/inbox/main/` (not `MAIN`).
- `create_clc_wo` writes CLC WOs to `bridge/inbox/clc/` (not `CLC`).

**Rule**: All v5 processors must treat lowercase inbox names as canonical. Any uppercase forms are **aliases only** (symlinks).

---

### 2.5 Mary-COO

- **File**: `agents/mary/mary.py`
- **LaunchAgent**: `com.02luka.mary-coo`
- **Purpose**: COO / dispatcher / coordinator, not a router.

**Hard separation**:

- Mary-COO:
  - **Must only** run `agents/mary/mary.py`.
  - **Must not** import or execute `gateway_v3_router.py` directly.
- Gateway:
  - Single-process, separate LaunchAgent (`com.02luka.mary-gateway-v3`).

This separation prevents:

- Duplicate gateway processes.
- Routing races and inconsistent lane decisions.

Reference doc: `g/reports/system/launchagent_repair_PHASE2C_MINI_RECIPE_MARY_COO.md`.

---

## 3. Inbox & Channel Model

### 3.1 Canonical Directories (Lowercase)

Runtime canonical inbox layout (in workspace, e.g. `~/02luka_ws/bridge/inbox`):

- `main/` — primary governance inbox (owned by gateway v3).
- `clc/` — CLC inbox (STRICT lane operations, escalations).
- `cls/` — CLS decision channel.
- `entry/` — high-level WO entrypoint (Mary / meta-ops).
- `gemini/` — Gemini-related WOs.
- `lpe/` — LPE engine.
- `rnd/` — R&D autopilot proposals.
- `llm/`, `rd/`, `lac/`, `liam/`, `hybrid/` — as defined in runtime tools and agents.

**Rule**:

- All **code** (Python + shell) must reference **lowercase** directory names.
- Uppercase equivalents (e.g. `CLC`, `ENTRY`, `GEMINI`, `RND`, `LAC`) may exist as symlinks for backward compatibility, but:
  - Must never be created as real directories inside repo.
  - Must not be used as primary truth in new code.

### 3.2 Symlink Model (Repo vs Workspace)

- Repo root: `~/02luka`
  - `bridge` → symlink → `~/02luka_ws/bridge`
  - `g` → symlink → `~/02luka_ws/g`
  - `.env.local` → symlink → `~/02luka_ws/env/.env.local` (if present)
- Inside `g/` (real dir in repo), data dirs are symlinks:
  - `g/data` → `~/02luka_ws/g/data`
  - `g/telemetry` → `~/02luka_ws/g/telemetry`
  - `g/followup` → `~/02luka_ws/g/followup`
- Inside `bridge/`:
  - `bridge/processed` → `~/02luka_ws/bridge/processed`

**Guard**:

- `tools/guard_workspace_inside_repo.zsh` enforces:
  - These paths **must be symlinks** if they exist in repo.
  - No real data directories are allowed inside repo for these locations.

---

## 4. Telemetry & Monitoring

### 4.1 Gateway Telemetry

- **Canonical file**: `g/telemetry/gateway_v3_router.jsonl`
- **Format**: NDJSON (one JSON object per line).
- **Key fields** (conceptual):
  - `timestamp` — ISO 8601 or epoch ms.
  - `action` — e.g. `"process_v5"`, `"route"`.
  - `wo_id` — WO identifier.
  - `lane`, `zone` — if applicable.
  - `status` — `COMPLETED`, `EXECUTING`, `REJECTED`, `FAILED`.
  - `target` — e.g. `clc`, `main`, `entry`.

**Rule**:

- New work should use the `.jsonl` file only; the old `.log` file is legacy and should not be relied on.

### 4.2 Production Monitor

- **Script**: `tools/monitor_v5_production.zsh`
- **Responsibilities**:
  - Read gateway telemetry and compute:
    - `v5_activity_24h`
    - Lane distribution
    - Backlog metrics for `main` and `clc`
    - Error stats (processed vs error)
  - Output machine-readable JSON for automation and PR evidence.

**Key behavior**:

- Log file resolution:
  1. Prefer `g/telemetry/gateway_v3_router.jsonl`.
  2. Fallback to `g/telemetry/gateway_v3_router.log` only if JSONL not present.
- Path resolution:
  - Read `directories` from `g/config/mary_router_gateway_v3.yaml`.
  - Normalize any `.../MAIN`/`.../CLC` to lowercase equivalents.
  - Use these paths for counting inbox / processed / error volumes.
- Time window:
  - 24h activity is based on **timestamp filtering**, not naive `tail`.

---

## 5. PR & Stability Model (v5)

This section captures the governance around how v5 was introduced and validated.

- **PR-7**: 30+ production operations.
  - Evidence: gateway telemetry, monitor reports, health checks.
  - Status: In progress at last adjustment (e.g. 8/30), to be driven via real usage.
- **PR-10**: CLS auto-approve semantics.
  - Requirement: `OPEN` zone + mission-scope whitelist → `FAST` lane.
  - Validated by tools (e.g. `tools/pr10_cls_auto_approve.zsh`) and telemetry inspection.
- **PR-11**: 7-day stability window.
  - Requirement: 7 days with:
    - Single gateway process.
    - Mary-COO separation intact.
    - No critical routing regressions / legacy fallback.
    - Telemetry and monitor behaving honestly (no “fake green”).
  - Evidence:
    - Daily health reports in `g/reports/pr11_healthcheck/`.
    - `g/docs/PR11_WEEK1_SEAL_TEMPLATE.md` and related checklist.
- **PR-12**: Post-mortem / sign-off.
  - Final report after PR-7 and PR-11 succeed.
  - Captures lessons, residual risks, and next-phase recommendations.

Supporting docs:

- `MERGE_NOTE_v5_battle_tested.md`
- `RELEASE_NOTE_v5_battle_tested.md`
- `PR11_PR12_CHECKLIST.md`
- `g/docs/PR11_WEEK1_SEAL_TEMPLATE.md`
- `g/docs/V5_ACTIVATION_CHECKLIST.md`

---

## 6. Invariants & “Must Not Lie” Rules

These are the **non-negotiable** invariants for governance v5.

1. **Single Gateway Invariant**
   - There must be exactly **one** `gateway_v3_router.py` process running in production.
   - Any duplicate process is a bug and must be treated as a P1.

2. **Mary-COO Separation Invariant**
   - `com.02luka.mary-coo` must **only** run `agents/mary/mary.py`.
   - It must never import or execute the gateway router.

3. **Lowercase Inbox Invariant**
   - All code paths use lowercase inbox directory names as canonical.
   - Uppercase directories under `bridge/inbox` are **symlinks only** (if needed), never the truth.

4. **Workspace / Repo Separation Invariant**
   - `bridge` and `g` at repo root are symlinks into `~/02luka_ws/`.
   - No bulk runtime data is stored directly in the repo.
   - `tools/guard_workspace_inside_repo.zsh` must pass before critical operations.

5. **Telemetry Honesty Invariant**
   - Telemetry must reflect actual behavior:
     - No “fake green” metrics.
     - All v5 statuses logged (COMPLETED / EXECUTING / REJECTED / FAILED).
   - Monitor scripts must use timestamp filtering for time windows.

6. **DANGER Handling Invariant**
   - Paths matching `DANGER_PATTERNS` are **never** executed.
   - They are always resolved to `zone = DANGER` and `lane = BLOCKED` with explicit logging.

7. **CLS Auto-Approve Invariant**
   - When all auto-approve conditions pass (OPEN zone + mission scope whitelist + no DANGER), CLS requests are routed to `FAST` lane.
   - They must not silently fall back to `STRICT`.

---

## 7. Future Extensions / TODOs

These are deliberate **follow-ups**, not gaps that break current stability.

- **v5 test suites PR**:
  - Create `v5-tests-clean` branch with `tests/v5_*` and `tests/v5_battle/*`.
  - Keep tests separate from core runtime PRs for clarity.

- **Hard guard against `git clean` accidents**:
  - Strengthen `safe_git_clean.zsh` + `.git-command-best-practices.md` + pre-commit hooks.
  - Ensure any future git operations cannot silently destroy workspace symlinks.

- **System truth sync**:
  - Regenerate / implement `system_truth_sync` pipeline (`g/tools/system_truth_sync_p0.py`, etc.).
  - Keep `02luka.md` and this governance doc automatically aligned with runtime reality.

- **Regenerate / refine supporting docs**:
  - If needed, add more focused ADRs or phase notes under `g/docs/` for:
    - SandboxGuard v5 design.
    - Router v5 decision tables.
    - CLC / CLS contract under v5 lanes.

---

## 8. How to Use This Document

- **For coding**:
  - Use this as the **reference spec** for any change that touches:
    - Routing
    - Inbox / channel paths
    - Gateway / Mary separation
    - Telemetry and monitoring
  - If a proposed change would violate any invariant in §6, it must:
    - Be explicitly documented.
    - Be justified via PR + review.

- **For ops / incident response**:
  - Use this as the ground truth to check:
    - Gateway count
    - LaunchAgent wiring
    - Inbox casing and symlink correctness
    - Telemetry and monitor behavior

- **For governance / review**:
  - Pair this file with:
    - `MERGE_NOTE_v5_battle_tested.md`
    - `RELEASE_NOTE_v5_battle_tested.md`
    - PR-7 / PR-11 / PR-12 reports
  - Together, they form the **audit trail** for governance v5.


