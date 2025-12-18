# Gemini Persona Full Performance — PLAN (Codex Revised)
**Feature:** Gemini CLI `GEMINI.md` (Behavioral Contract) + 02luka Persona v3 (Full Performance + Safety Belt + Auto-Update)  
**Date:** 2025-12-18  
**Status:** 📋 PLAN

---

## Goals (Pinned)

1) **Full Performance**
- Enable deep reasoning + multi-opinion output (Explorer/Skeptic/Decider pattern).
- Avoid “artificial blocks” (tool bans / read-only forever / identity locks).

2) **Safety Belt**
- Keep real safety: sandbox/approval, danger/destructive guardrails, Two Worlds/zone rules.
- Do not embed governance “law” into the main contract; reference SOT.

3) **Auto-Update**
- Keep context fresh via modular imports and a generated snapshot.
- Prefer explicit reload (`/memory refresh`) over hidden magic.

---

## Phase 1 — Create Behavioral Contract (Gemini CLI)

### 1.1 Add project `~/02luka/GEMINI.md`
**Intent:** project-scoped HUMAN mode contract that does not self-block.

Checklist:
- Encourage full reasoning/opinions.
- Allow tools by default.
- Ask before destructive/irreversible actions.
- Import modular context:
  - `@./context/gemini/ai_op.md`
  - `@./context/gemini/gov.md`
  - `@./context/gemini/tooling.md`
  - `@./context/gemini/system_snapshot.md`

Acceptance:
- Gemini CLI shows increased context file count (global + project).
- `/memory show` includes the expected sections.

### 1.2 Keep `~/.gemini/GEMINI.md` neutral (manual user action)
**Intent:** prevent global “always gmx/system” bias.

Acceptance:
- Global file contains no forced identity (e.g., “always gmx”).
- Any heavy governance is removed from global and moved to repo modules.

---

## Phase 2 — Create Modular Context (Repo-managed)

### 2.1 Create module directory
`context/gemini/`

### 2.2 Add modules (thin summaries + references)
- `context/gemini/ai_op.md`
  - short operational rules; link to `g/docs/AI_OP_001_v5.md` (SOT)
- `context/gemini/gov.md`
  - Two Worlds reminder; link to `g/docs/GOVERNANCE_UNIFIED_v5.md` / Two Worlds SOT
- `context/gemini/tooling.md`
  - “catalog first” rule and correct entrypoints:
    - `zsh tools/catalog_lookup.zsh <command>`
    - `zsh tools/run_tool.zsh <tool-id> ...`
    - save-now uses `tools/save.sh` (gateway) per catalog
- `context/gemini/system_snapshot.md`
  - short, 1-page runtime truth (P0 health, gateway telemetry presence, last update ts)

Acceptance:
- Modules are readable (≤1 page each).
- No duplicated “law text walls”; references point to SOT.

---

## Phase 3 — Restore/Upgrade 02luka Persona v3 (IDE/Routing)

### 3.1 Restore `personas/GEMINI_PERSONA_v3.md`
**Intent:** make 02luka persona loader functional for gemini.

Constraints:
- Must satisfy `tools/load_persona_v5.zsh gemini verify` required headings:
  - Identity & Mission
  - Two Worlds Model
  - Zone Mapping
  - Identity Matrix
  - Mary Router Integration
  - Work Order Decision Rule
  - Key Principles

### 3.2 Sync into Cursor commands
- `zsh tools/load_persona_v5.zsh gemini sync`

Acceptance:
- `.cursor/commands/gemini.md` exists and includes the persona content.

---

## Phase 4 — Full Performance Rules (No Artificial Blocks)

### 4.1 Encode “multi-opinion, single decider” pattern
Add to project `GEMINI.md` (or a module):
- Explorer: propose 2–3 options + tradeoffs
- Skeptic: risks/failure modes + governance concerns
- Decider: choose one path with evidence (files/logs/catalog)

### 4.2 Remove self-blocking phrases
Audit:
- `~/.gemini/GEMINI.md` (manual)
- repo `GEMINI.md`
- persona v3

Acceptance:
- No “never use tools” / “read-only forever” / “always gmx” language in human contract.

---

## Phase 5 — Safety Belt Placement (Correct Layering)

### 5.1 Confirm safety belongs to execution controls
- CLI flags: sandbox on/off, approval mode
- Governance: Two Worlds, zones/lanes
- Catalog discipline for commands

Acceptance:
- Safety rules constrain *execution*, not cognition.
- Reasoning/opinion-giving remains enabled.

---

## Phase 6 — Auto-Update Mechanism (Lightweight)

### 6.1 Generate `context/gemini/system_snapshot.md`
Input sources (existing truth tools):
- LaunchAgent P0 status summary
- System truth sync snapshot
- Gateway telemetry presence

Mechanism options:
- Manual: run a script and commit/update the snapshot
- Periodic: LaunchAgent writes snapshot (later)

Acceptance:
- Snapshot contains timestamp + key green/yellow/red indicators.

### 6.2 Reload story (explicit)
- Use `/memory refresh` after updates.

---

## Integration Tests (Minimal)

1) **Human full feature**
- Run: `gemini --sandbox --approval-mode=auto_edit`
- Expect: sandbox enabled; context files loaded; can use tools with approvals.

2) **System/plain**
- Run: `gmx` profile (sandbox=false)
- Expect: no sandbox; conservative execution; still can reason and propose.

3) **Persona sync**
- Run: `zsh tools/load_persona_v5.zsh gemini verify` then `... sync`
- Expect: `.cursor/commands/gemini.md` updated.

