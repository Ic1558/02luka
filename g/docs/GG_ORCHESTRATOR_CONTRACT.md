# GG Orchestrator Contract

This document outlines the contract and operational principles for the GG Orchestrator.

## 4.0 Engine Routing: CLC vs Gemini vs Gemini CLI

### 4.1 High-Level Principle

- CLC = privileged writer for **locked / governance** zones and tight protocol surgery.
- Gemini & Gemini CLI = primary operational writers for **non-locked** zones when:
  - tasks are multi-file / large / bulk, OR
  - CLC weekly usage is high (Quota Guard active), OR
  - Boss explicitly prefers Gemini to save CLC tokens.

### 4.2 GG’s Decision Order

When GG needs to choose between CLC, Gemini, and Gemini CLI:

1. **Check Zone**
   - If the task touches locked zones (`/core/governance/**`, `/CLC/**`, protocol files) → **prefer CLC**.
   - Else → non-locked → Gemini or Gemini CLI are allowed.

2. **Check CLC Weekly Usage**
   - If CLC weekly usage ≥ 60%:
     - For non-locked tasks → **route to Gemini or Gemini-CLI** (via WO or patch) by default.
     - For locked/gov tasks → CLC only if necessary and surgical.
   - If CLC weekly usage < 60%:
     - Use task-type rules (docs/security/multi-file → Gemini, urgent bug/interactive → CLC).

3. **Check Task Type**
   - Large docs, security sweep, multi-file refactor, big scripts → Gemini or Gemini CLI.
   - Urgent bugfix, interactive step-by-step work, protocol edits → CLC.

4. **Record the Choice**
   - GG SHOULD state in the response:
     - which engine was chosen,
     - and *why* (quota, zone, task type).

### 4.3 Example

- “Generate internal API docs for 5 modules” → Gemini (multi-file, non-locked).
- “Fix security bug in auth core, protocol-linked” → CLC (locked / sensitive).
- “Build one-off bulk script over 20 files” + CLC usage at 65% → Gemini (Quota Guard).
-- “`/02luka/gemini-cli apply patch <patch_file>`” → Gemini CLI (direct patch application).
-- Gemini CLI reads the filtered `g/knowledge/mls_lessons_cli.jsonl` feed before each patch, keeps that guidance read-only, and routes any new patterns back as `mls_suggestion` proposals instead of writing directly to the canonical ledger.

---

### 4.4 Layer 4.5 — Gemini (Heavy Compute / Non-Locked Zones)

**Role:**

- Heavy compute offloader for multi-file bulk operations, tests, and analysis.
- Handling non-locked refactors that would tax CLC tokens or time.
- Producing patch/spec output for GG to review before canonical apply.

**Input:**

- Work Order tagged `engine: gemini` and delivered through `bridge/inbox/GEMINI/`.
- Target files contained entirely in non-locked zones (`apps`, `tools`, `tests`, `docs`).
- Constraints for tokens, temperature, timeout, and write mode (patch-only).

**Output:**

- Patch/spec artifacts placed in `bridge/outbox/GEMINI/`.
- Review notes delivered to Andy/CLS prior to any SOT write.
- No direct writes to SOT; Gemini output is always diff/patch based.

**Constraints:**

- **May NOT touch:** `/CLC`, `/CLS`, governance docs, or bridge/core directories.
- **Must NOT bypass:** SIP/WO system or review guardrails (Andy/CLS review required).
- **Must:** Respect Protocol v3.2 locked-zone rules, log all operations into MLS, and publish revision metadata (tags, `review_required_by`, `locked_zone_allowed: false`).
- **Must produce:** Unified patch artifacts and an implementation review note referencing the WO ID.

**Fallback:**

- If Gemini quota is exhausted or blocked → route to CLC or Gemini IDE (with clear rationale).
- If a locked zone sneaks in → fall back to CLC specs immediately, never route to Gemini.
