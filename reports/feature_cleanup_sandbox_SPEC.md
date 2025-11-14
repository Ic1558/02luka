# Feature SPEC: Codex Sandbox Compliance — Phase 1 Sanitization

- **Date:** 2025-11-14  
- **Author:** Codex Ops  
- **Goal:** Remove every historical reference to high-risk shell commands so the Codex Sandbox Guardrail can run globally across the 02luka repo.

## Background

The new guardrail blocks any reference to the following destructive patterns:

- Recursive deletes and root-level wipes.
- Moving or rewriting root directories.
- Privileged shell invocations and force-kill signals.
- Fork bombs or other resource-exhaustion payloads.
- World-writable permission changes.
- Raw disk utilities, filesystem formatters, shutdown/reboot commands.
- Remote install pipelines such as "curl piped straight into sh", inline Python `os.remove`, or scripted multi-line deletion loops.

These strings still appear inside legacy docs, reports, and helper scripts. They must be neutralized before Sandbox Mode can be enforced in CI.

## Requirements

### Functional
1. Remove or neutralize dangerous vocabulary in docs (`docs/`, `reports/`, `manuals/`, `g/reports/`) plus archived examples.
2. Replace each command with a sandbox-safe equivalent: describe the action in prose, escape the snippet, or wrap it in a clearly annotated `sandbox-ignore` block.
3. Ensure no active scripts under `tools/`, `run/`, `scripts/`, or `launchd/` contain banned tokens (only the checker and its workflow may reference them).

### Non-Functional
1. No behavior change for production scripts—updates focus on presentation and guardrail UX.
2. Preserve documentation clarity while sanitizing the dangerous content.
3. The Codex Sandbox checker must pass locally and in CI.

## Scope

### Included
- Documentation cleanup (docs, manuals, reports).
- Example rewrites (old specs, postmortems, notebooks).
- Removing references inside historical logs, reports, and ops guides.
- Neutralizing risky command patterns that existing tools might surface.

### Excluded
- SOT files: `02luka.md`, `CLAUDE.md`, `AI:OP-001`.
- LaunchAgent definitions and other system-level plists.
- Runtime logic changes or new automation that performs destructive work.

## Success Criteria

- `tools/codex_sandbox_check.zsh` reports “0 violations”.
- CI `codex_sandbox` job passes on every PR.
- Repository contains no unescaped banned terms outside of the guardrail implementation.
- Documentation remains readable and actionable, with sanitized footers applied to the touched files.

<!-- Sanitized for Codex Sandbox Mode (2025-11) -->
