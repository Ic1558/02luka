# Feature Plan — Gemini Routing + WO Integration (Phase 2–3)

- **Feature ID**: feature_gemini_routing_wo_integration_phase2_3
- **Owner**: GG / CLS / Gemini Routing lane
- **Status**: DRAFT (skeleton created, implementation pending)
- **Scope**: Phase 2 (Dry-Run), Phase 3 (WO Integration)
- **Related PRs**: 
  - PR #381 — sandbox + path guard compliance (precondition)
  - `feature_gemini_routing_wo_integration_phase1` (if exists, as prior art)

---

## 1. Background & Problem Statement

We want Gemini-based commands to be routed into the 02luka Work Order (WO) system in a safe, auditable, and CI-compliant way. Right now:

- Gemini / Codex can **understand** natural language requests.
- The WO pipeline is **already the canonical way** to change files, run agents, and apply patches.
- However, the connection between **Gemini routing → WO creation → CLS/CLC processing** is incomplete and scattered across reports / specs.

This feature plan defines **Phase 2 (Dry-Run)** and **Phase 3 (Full WO Integration)** for Gemini routing, focusing on:

- Safe conversion from NL → structured WO.
- Clear guardrails (no direct file writes, no arbitrary shell).
- CI visibility via existing Codex and Path Guard checks.

---

## 2. Goals and Non-Goals

### 2.1 Goals

- Provide a **single, documented flow** for:
  1. Gemini (or another LLM) receiving a user request.
  2. Converting that request into a **structured WO** in the correct format.
  3. Dropping it into the appropriate `bridge/inbox/…` directory.
  4. Letting CLS/CLC process it under existing governance.

- Ensure:
  - No violation of **sandbox rules** (e.g., no `rm -rf`, no `sudo`).
  - No violation of **Path Guard** (all reports / specs in allowed folders).
  - Easy **CI reasoning**: Codex CI can see *what* Gemini is allowed to do and *where*.

- Make Phase 2 & 3 **small, reviewable steps** with clear “Definition of Done”.

### 2.2 Non-Goals

- Not redesigning the WO schema from scratch.
- Not changing CLS/CLC authority or AI:OP-001 governance.
- Not wiring Gemini directly to shell or file writes — **all changes go via WO → CLS/CLC**.

---

## 3. Phase 2 — Gemini Dry-Run Routing

**Objective**: Prove that Gemini can generate valid WOs **without any real execution**. Everything is dry-run / no-op from the system’s perspective.

### 3.1 Scope

- Define the **minimal WO schema** Gemini must produce (fields, paths, action types).
- Create a **“Dry-Run” target** (e.g., a `bridge/inbox/…/DRY_RUN` lane or a flag) where WOs are:
  - Parsed
  - Validated
  - Logged
  - **Not executed**.

- Integrate with CI so that:
  - Example WOs live under `g/reports/system/` or `g/reports/feature/`.
  - Codex can lint them and confirm schema compliance.

### 3.2 Deliverables

- **Doc**: This PLAN file + a short `*_SUMMARY.md` if needed.
- **Examples**: 2–3 sample Gemini-generated WOs:
  - Simple doc update.
  - Small code patch (single file).
  - LaunchAgent-related config change (non-destructive).

- **Validation script** (can be minimal):
  - Reads a sample WO.
  - Validates schema (keys, types, required fields).
  - Prints success/failure.

### 3.3 Definition of Done (Phase 2)

- Gemini can produce a WO JSON/YAML that:
  - Parses successfully.
  - Passes schema validation.
  - Lands in a **non-executing** lane.
- CI contains at least:
  - One job that validates example WOs.
  - No sandbox / path guard violations triggered by this feature.

---

## 4. Phase 3 — Full WO Integration

**Objective**: Move from “dry-run only” to **real WO execution** via the existing WO/CLS/CLC pipeline, still under strict governance.

### 4.1 Scope

- Define which **intent types** Gemini is allowed to convert into WOs (e.g., `fix_launchagent`, `update_ci_spec`, `add_report`, etc.).
- Wire **Gemini → WO** into the same bridge used by existing WO flows:
  - `~/02luka/bridge/inbox/CLC/…` (or the canonical inbox path).
- Ensure:
  - CLS/CLC still own the actual file modifications.
  - Gemini cannot bypass WO or create arbitrary shell commands.

### 4.2 Guardrails

- WO intents must be **whitelisted**, not free-form.
- Any “high-risk” actions (e.g., deletion, moving directories) require:
  - Clear flags in the WO.
  - Optional manual approval or a specific CLS route.

- Logs:
  - Every Gemini-originated WO should be tagged (e.g., `origin: gemini`).
  - Easy to filter in telemetry / reports.

### 4.3 Deliverables

- **Routing logic** (implementation detail is for code/CLs; here we just define behavior):
  - Mapping of **NL intent → WO template**.
  - Config file for intent → target inbox path.

- **Docs**:
  - Section in system docs under `g/reports/system/` explaining:
    - How Gemini routing decisions are made.
    - Which intents are allowed in Phase 3.
    - How to extend the intent list safely.

- **Tests / CI**:
  - At least one test scenario where:
    - A sample Gemini request is turned into a WO.
    - That WO passes validation and is ready for CLS to execute.

### 4.4 Definition of Done (Phase 3)

- Gemini → WO path is **active** for a limited, approved intent set.
- All Gemini-generated WOs:
  - Are schema-valid.
  - Go through CLS/CLC.
  - Are visible/auditable (logs, reports).
- CI green:
  - No new sandbox violations.
  - No new Path Guard violations.

---

## 5. Risks, Constraints, and Open Questions

### 5.1 Risks

- **Overbroad intents**:
  - If intents are too free-form, Gemini may generate WOs that are too powerful or ambiguous.

- **Spec drift**:
  - The WO schema may evolve; Gemini mappings must track it.
  - Need a single SOT (this file + referenced spec) to avoid divergence.

- **CI brittleness**:
  - Codex rules (sandbox/path guard) may need updates if Gemini routing touches new paths.

### 5.2 Constraints

- Must comply with:
  - AI:OP-001 and 02luka governance (CLS/CLC as only file writers).
  - Existing Codex sandbox rules (no `rm -rf`, no `sudo`, path restrictions).
  - Report placement rules (only allowed folders under `g/reports/`).

### 5.3 Open Questions / TODOs

- [ ] Confirm exact WO schema SOT file and link it here.
- [ ] Confirm final Gemini → WO intent mapping file and its path.
- [ ] Decide whether Phase 3 includes Telegram/Kim routing or only local Gemini.
- [ ] Decide log/telemetry format for Gemini-originated WOs.

---

## 6. Timeline & Milestones (Draft)

> This is a planning sketch; actual dates to be filled once resource availability is known.

- **T0** — PLAN accepted
  - This file reviewed and merged.
  - SOT for WO schema linked.

- **T0 + 2–3 days** — Phase 2
  - Dry-run schema validation.
  - Example WOs.
  - CI job green.

- **T0 + 1–2 weeks** — Phase 3
  - Intent mapping implementation.
  - Bridge inbox routing live for selected intents.
  - Audit/logging path confirmed.

---

## 7. References

- Existing WO specs (TBD: insert paths).
- Codex CI configuration for sandbox/path guard.
- 02luka Master Engineering & Operational Protocol (AI:OP-001).