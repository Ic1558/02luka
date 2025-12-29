# GG Orchestrator Contract

This document outlines the contract and operational principles for the GG Orchestrator.

## 4.0 Engine Routing: CLC vs Codex vs Gemini vs Gemini CLI

### 4.1 High-Level Principle

- CLC = privileged writer for **locked / governance** zones and tight protocol surgery.
- **Codex = primary operational executor** for **non-locked** zones (code review, refactor, analysis).
- Gemini & Gemini CLI = heavy compute offloader for **multi-file bulk** operations when:
  - tasks are multi-file / large / bulk, OR
  - CLC weekly usage is high (Quota Guard active), OR
  - Boss explicitly prefers Gemini to save CLC tokens.

### 4.2 GG's Decision Order (Updated for Codex)

When GG needs to choose between CLC, Codex, Gemini, and Gemini CLI:

1. **Check Zone**
   - If the task touches locked zones (`/core/governance/**`, `/CLC/**`, protocol files) → **CLC only**.
   - Else → non-locked → **Codex preferred** (faster, cheaper).

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

---

### 4.6 Layer 4.6 — Codex CLI (Primary Executor / Non-Locked Zones)

**Status:** ✅ Production Ready (Tier 2 - Expanded Read Access)
**Effective:** 2025-12-30

**Role:**
- Primary operational executor for non-locked zone tasks
- First choice for: code review, refactoring, test generation, debugging, analysis
- Cheaper and faster than CLC for routine operations
- 95% CLC capability with 100% safety (Tier 2 config)

**Capabilities (Tier 2):**
- ✅ Read: Anywhere in system (like CLC)
- ✅ Write: ~/02luka + approved dirs (auto-approved)
- ⚠️ Write elsewhere: Prompts for approval
- ❌ System files (/etc, /System): Protected (safer than CLC)

**When to Use Codex:**

**PREFER Codex for:**
1. Code review in non-locked zones
2. Refactoring (single or multi-file)
3. Error handling improvements
4. Test generation
5. Debugging assistance
6. System analysis (configs, multiple repos)
7. Documentation updates

**Use CLC for:**
1. Locked zones (`/CLC/**`, `/core/governance/**`, `memory/**`)
2. Protocol surgery
3. Plan mode workflows
4. Governance changes
5. Tasks requiring approval workflows

**Commands:**

```bash
# Default for 02luka work (git safety net)
codex-task "refactor tools/session_save.zsh with error handling"

# System-wide analysis
codex-system "analyze ~/.zshrc and suggest optimizations"

# Read-only research
codex-analyze "compare 02luka structure with ~/other-project"

# Quick tasks (no git checkpoint)
codex-auto "review apps/api/auth.ts for security issues"
```

**Routing Decision Flow:**

```
[Task arrives]
    ↓
[1] Zone check
    Locked? → CLC
    Non-locked? → Continue
    ↓
[2] Task type check
    Code review/refactor/test/debug? → Codex
    Plan mode required? → CLC
    Multi-file bulk (>10 files)? → Consider Gemini
    ↓
[3] CLC Quota check
    <60%: Codex OK
    ≥60%: Codex REQUIRED (quota guard)
    ↓
[4] Execute via Codex
    Log metrics → g/reports/codex_routing_log.jsonl
```

**Logging (Required):**

After routing to Codex, GG MUST log:
```bash
zsh ~/02luka/tools/log_codex_task.zsh "task_type" "command" quality_score
```

**Examples:**

```bash
# Log code review task
log_codex_task.zsh "code_review" "codex-system 'review tools/session_save.zsh'" 9

# Log refactor task
log_codex_task.zsh "refactor" "codex-task 'improve error handling in mls_capture.zsh'" 8
```

**GG Response Format:**

When routing to Codex, GG SHOULD state:
```
Engine: Codex
Reason: Non-locked zone + code review task + Tier 2 capabilities sufficient
Command: codex-task "review apps/api/auth.ts"
Expected: Security analysis with actionable suggestions
```

**Metrics Tracking:**

Weekly review via:
```bash
zsh ~/02luka/tools/codex_metrics_summary.zsh week
```

**Target KPIs:**
- Tasks routed to Codex: 70-80% of non-locked tasks
- Success rate: >95%
- Average quality: ≥8/10
- CLC quota savings: 60-80%

**Safety Guarantees:**

1. ✅ Locked zones protected (CLC only)
2. ✅ System files protected (/etc, /System blocked)
3. ✅ Dangerous commands prompt (rm -rf, sudo, etc.)
4. ✅ Git safety net (codex-task creates checkpoints)
5. ✅ Outside workspace writes prompt

**Fallback Policy:**

If Codex fails or quality insufficient:
1. Log failure to metrics
2. Retry with CLC
3. Update routing spec if pattern detected

**Documentation:**
- Full routing spec: `g/docs/CODEX_CLC_ROUTING_SPEC.md`
- Tier 2 setup: `g/reports/feature-dev/codex_enhancement/TIER2_COMPLETE.md`
- Sandbox strategy: `g/docs/CODEX_FULL_SYSTEM_ACCESS.md`

---
