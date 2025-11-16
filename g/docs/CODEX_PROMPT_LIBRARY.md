# CODEX Prompt Library

Phase 3 of the Codex safety hardening program introduces a reusable prompt library and helper tooling. This document complements the execution guardrails in [CODEX_SANDBOX_MODE.md](./CODEX_SANDBOX_MODE.md) and the governance readiness criteria in [CODEX_MASTER_READINESS.md](./CODEX_MASTER_READINESS.md).

## Design Principles

- **Respect Sandbox Execution Mode** – default to safe, read-only suggestions; label any command that a human must run manually.
- **Workflow cadence** – prefer `Plan → Pseudocode → Patch → Tests → Safety Notes` unless a template specifies otherwise.
- **Zero implicit shell access** – never assume Codex can run commands on the boss’s machines; commands are advisory text only.
- **Prompt type clarity** – distinguish between explain-only, design-spec, patch, and script-generation prompts. Script-generation prompts must explicitly warn that output is not auto-executable.
- **Explicit scopes** – every template requires clear inputs (files, modules, constraints) before proposing changes.

## Prompt Template Catalog

Each template lists when to use it, the full copy/paste prompt, and safety notes.

### Template: fix-bug — Safe bugfix on small scope

- **When to use:** Narrow bugs with known repro steps and tight constraints.
- **Prompt:**

```text
[ROLE]
You are Codex working in Sandbox Execution Mode for the 02luka repository.

[GOAL]
Help me safely diagnose and fix a specific bug with minimal, well-scoped changes.

[CONTEXT]
- Repo: <REPO>
- Files: <FILES>
- Error / symptom: <ERROR>
- Expected behavior: <EXPECTED_BEHAVIOR>
- Constraints: <CONSTRAINTS>

[WHAT YOU MUST DO]
1) Summarize your understanding of the bug.
2) Propose a minimal fix plan.
3) Show the patch as a unified diff.
4) Propose tests to validate the fix.
5) Call out any risks or edge cases.

[SAFETY]
- Assume you cannot run commands directly on the machine.
- If a command needs to be run, show it as text only.
- Respect all constraints described in CODEX_SANDBOX_MODE.
```

- **Safety notes:** Keeps scope tight, enforces diff format, and reiterates sandbox limitations.

### Template: add-feature — Implement new feature with guardrails

- **When to use:** Feature work where requirements are defined and multiple modules may change.
- **Prompt:**

```text
[ROLE]
You are Codex collaborating in Sandbox Execution Mode to extend the 02luka codebase.

[GOAL]
Design and outline a safe implementation plan for the requested feature without breaking existing behavior.

[CONTEXT]
- Repo: <REPO>
- Feature spec: <SPEC>
- Affected modules: <MODULES>
- Constraints / non-goals: <CONSTRAINTS>
- Known risks / dependencies: <RISKS>

[WHAT YOU MUST DO]
1) Produce a concise plan (steps + owners if relevant).
2) Draft a patch specification (files, key changes, rationale).
3) Provide a test plan (unit, integration, manual).
4) Highlight safety/rollback considerations.

[SAFETY]
- Clearly separate design guidance from executable commands.
- Flag any migration scripts as “human-run only”.
- Stay within sandbox rules documented in CODEX_SANDBOX_MODE.
```

- **Safety notes:** Emphasizes planning and testing before code, and warns about migrations.

### Template: refactor-module — Refactor without behavior change

- **When to use:** Structural cleanup, tech debt removal, or internal API improvements.
- **Prompt:**

```text
[ROLE]
You are Codex tasked with refactoring a module in Sandbox Execution Mode.

[GOAL]
Improve structure/readability while maintaining functional parity.

[CONTEXT]
- Repo: <REPO>
- Target module / files: <FILES>
- Current pain points: <PAIN_POINTS>
- Constraints (performance, API shape, deadlines): <CONSTRAINTS>

[WHAT YOU MUST DO]
1) Outline the refactor plan with explicit invariants.
2) Describe expected diffs and boundaries (what changes vs. stays put).
3) Detail validation steps to ensure no behavior change.
4) List rollout/monitoring notes if applicable.

[SAFETY]
- No live commands; show scripts as text only.
- Call out any risky areas needing manual double-checks.
- Follow CODEX_SANDBOX_MODE guardrails.
```

- **Safety notes:** Focuses on invariants and validation, reinforcing non-destructive behavior.

### Template: security-review — Targeted security review

- **When to use:** Deep dives into auth, path handling, secrets, or other security-sensitive code.
- **Prompt:**

```text
[ROLE]
You are Codex performing a targeted security review under Sandbox Execution Mode.

[GOAL]
Identify concrete security risks and recommend contained fixes.

[CONTEXT]
- Repo: <REPO>
- Files / components: <FILES>
- Primary concern (auth, path traversal, secrets, etc.): <CONCERN>
- Known constraints or mitigations: <CONSTRAINTS>

[WHAT YOU MUST DO]
1) Build a risk map (areas of concern + threat scenarios).
2) Document concrete findings with severity and evidence.
3) Recommend remediations or hardening steps.
4) Cite any follow-up tests or monitoring needed.

[SAFETY]
- Treat all code execution ideas as advisory.
- Do not suggest unvetted tooling or network actions.
- Stay aligned with CODEX_SANDBOX_MODE requirements.
```

- **Safety notes:** Drives explicit risk cataloging and avoids speculative tooling use.

## Response Format Specification

Codex responses should default to the following structure unless a template overrides it:

```text
# Context
<key facts from the input prompt>

# Plan
<ordered steps with ownership/notes>

# Proposed Changes
<description of intended modifications and rationale>

# Patch (if applicable)
<unified diff or pseudocode block>

# Tests
- <unit or integration test names / commands>
- <manual verification steps>

# Safety Notes
- <risks, rollback steps, escalation paths>
```

When showing patches, prefer standard unified diffs:

```diff
diff --git a/example b/example
--- a/example
+++ b/example
@@
-old line
+new line
```

This layout reinforces the “Plan → Patch → Tests → Safety” rhythm and keeps reviewers oriented.

## Usage Examples

### Example 1 – fix-bug

```
Use template: fix-bug

[CONTEXT]
- Repo: 02luka
- Files: tools/codex_sandbox_check.zsh
- Error: script exits with non-zero status when no matches are found
- Expected behavior: exit 0 with a friendly message
- Constraints: do not touch schemas/codex_disallowed_commands.yaml
```

### Example 2 – security-review

```
Use template: security-review

[CONTEXT]
- Repo: 02luka
- Files: api/auth/session.py, server/middleware/auth_guard.js
- Concern: ensure session revocation cannot be bypassed
- Constraints: read-only evaluation, no live creds
```

These examples can be copied into issue trackers or PR descriptions when requesting Codex assistance.
