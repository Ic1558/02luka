# CLI vs Background Governance Separation

## Problem Statement
Overlapping governance stacks (AI:OP v4, governance v4.x, context-engineering legacy rules, CLC/CLS/Mary/LAC policies, and recent CLI-specific directives) currently compete for authority. Each layer assumes primacy, no retirement path exists for legacy rules, and interactive work is repeatedly constrained by background-only controls.

## Principle: Two Worlds
- **Interactive / CLI World** — GMX, Codex, Cursor agent, Antigravity, Boss on terminal.
  - Mode: **Full Power with safety belt** (prevent destructive ops like `rm -rf /` or accidental repo wipes).
  - Governance: **RULE 1 (CLI = Full Power)** + minimal safeguards; other governance specs are guidance only.
- **Background / Autonomous World** — Mary, LAC, CLC, LaunchAgents, workers, nightly jobs.
  - Mode: **Strict Governance**.
  - Governance: **AI:OP v4, governance v4.x, LAC/CLC rules** fully enforced.

## Hierarchy of Authority
1. **Layer 0 — Boss Live Command**: Explicit instructions in-session override other governance except basic safety/physical constraints.
2. **Layer 1 — CLI Full Power**: Applies to interactive agents; downgrades AI:OP/governance v4 from mandatory to advisory for CLI sessions.
3. **Layer 2 — Background Governance**: AI:OP v4 + governance v4.x remain mandatory for autonomous/background agents.

## Operational Guardrails (Interactive World)
- Keep only essential protections: prevent catastrophic deletions, require confirmation/backups for destructive actions, avoid corrupting git state.
- Do **not** auto-apply CLC/AI:OP write restrictions to user-driven CLI work.
- Treat background governance text as reference docs for CLI, not blockers.

## Retirement & Scope Clarity
- Mark legacy prompt/context rules as **retired for CLI** unless explicitly re-enabled.
- Tag new governance rules with scope (`cli` vs `background`) and priority (Layer 0/1/2).
- Maintain a registry/table of active governance by scope to avoid rule creep.

## Implementation Steps
- Add routing logic in agent/router layers to tag sessions as `interactive` or `background` and load governance accordingly.
- Centralize safety belt checks for CLI (e.g., destructive command intercepts, backup hooks) separate from governance enforcement modules.
- Update documentation/playbooks for GMX/Codex/Cursor/Antigravity to reference Layer 1 behavior; keep Mary/LAC/CLC docs tied to Layer 2.
- Define a retirement checklist for outdated prompt/gov specs so they stop applying to CLI sessions by default.
