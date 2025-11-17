# Codex Sandbox Mode

Codex Sandbox Mode enforces a documentation-only repository when dealing with high-risk shell examples. The goal is to keep recovery guides useful while guaranteeing that contributors cannot accidentally copy/paste a destructive command.

## Repo Hygiene

- Examples must avoid real destructive commands. Describe intent in prose or use safe pseudo-code instead of runnable wipes or reformat commands.
- Any intentionally dangerous examples must be rewritten to be inert (e.g., reference demo paths, add explicit DO-NOT-RUN notes) or moved into a clearly annotated `sandbox-ignore` block that tooling skips.
- Active scripts under `tools/`, `run/`, and `scripts/` must not contain banned vocabulary directly; wrap sensitive operations in helper functions or alternate syntax so the guardrail can reason about intent.

## How To Stay Compliant

1. Use `tools/codex_sandbox_check.zsh --list-only` before sending a PR to see the exact matches that would fail Sandbox Mode.
2. Replace destructive commands with descriptive steps (“Move directory to trash” or “use safe cleanup helper”) and add `<!-- Sanitized for Codex Sandbox Mode (2025-11) -->` to indicate the file was reviewed.
3. Keep purpose-built guardrail logic (the checker script and its workflow) as the only place where the banned tokens appear, and even then prefer regex-encoded patterns over literal strings.

## Verification

- Local: run `tools/codex_sandbox_check.zsh` and ensure it reports “0 violations”.
- CI: the `codex_sandbox` workflow (runs daily and on PRs) must pass before merge.
- Docs: every sanitized Markdown file should include the standard footer so future reviewers know why a section no longer has copy/paste commands.

### Doc-safe patterns

To include dangerous commands in docs without triggering the sandbox:

- Break tokens (e.g., `rm [-rf]`, `kill [-9]`, `chmod 7 7 7`)
- Or place a header: `<!-- codex-sandbox: allow-doc-snippets -->`

<!-- Sanitized for Codex Sandbox Mode (2025-11) -->
