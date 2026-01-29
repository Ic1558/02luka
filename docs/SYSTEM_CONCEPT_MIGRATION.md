# System Concept Migration Draft

## Purpose
Align the evolving system concept with the new **CLI vs Background governance separation** so that interactive developer tooling keeps full-power ergonomics while autonomous services remain under strict controls.

## Objectives
- Map existing governance/prompt layers to explicit scopes (`cli` vs `background`).
- Preserve developer velocity in interactive sessions while retaining safety belts for catastrophic actions.
- Keep background agents fully compliant with AI:OP v4 / governance v4.x and related policies.
- Provide a retirement path for legacy prompt fragments that should no longer affect CLI flows.

## Current Gaps
- Governance files lack scope labels, causing background rules to constrain CLI sessions.
- No routing logic distinguishes interactive invocations (GMX/Codex/Cursor/Antigravity) from autonomous workers (Mary/LAC/CLC/LaunchAgents).
- Safety checks live alongside governance enforcement, making it hard to keep CLI lightweight without losing protection against destructive commands.

## Target Concept
- **Two-world split**
  - **Interactive/CLI world**: Full power with a safety belt; background governance is advisory.
  - **Background/autonomous world**: Strict governance; all safety/guardrail layers enforced.
- **Layered authority**
  1. Boss live command (explicit session overrides, subject to physical/sanity constraints).
  2. CLI full-power mode (minimal safety checks; governance text = guidance only).
  3. Background governance (mandatory AI:OP v4 / governance v4.x + LAC/CLC rules).
- **Scope-aware registry** that lists active governance specs with scope + priority and marks legacy rules as **retired for CLI** by default.

## Migration Steps
1. **Inventory & tag**: Audit governance/prompt assets and tag each with `scope: cli|background` and `priority: layer0|layer1|layer2`.
2. **Session routing**: Update agent/router entry points to classify sessions as `interactive` or `background` and load governance accordingly.
3. **Safety belt isolation**: Centralize destructive-command intercepts and git-state protection in a CLI safety module distinct from governance enforcement.
4. **Documentation refresh**: Update GMX/Codex/Cursor/Antigravity playbooks to reference Layer 1 behavior; ensure Mary/LAC/CLC docs stay tied to Layer 2.
5. **Retirement checklist**: Establish a process to deprecate outdated prompt/context fragments so they stop applying to CLI sessions unless explicitly re-enabled.

## Safeguards & Quality Gates
- Require confirmation/backups for high-risk CLI actions (mass deletes, repo rewrites) while avoiding friction for normal edits/commits.
- Add smoke tests that verify interactive sessions bypass background-only write restrictions and that background workers still enforce them.
- Track migrations in the governance registry to prevent rule creep or accidental scope drift.

## Open Questions
- What telemetry or audit hooks are acceptable in CLI full-power mode without slowing workflows?
- Which legacy rules must remain available as opt-in toggles for CLI sessions?
- How should we handle mixed-mode tasks (e.g., CLI-initiated jobs that spawn background workers)?
