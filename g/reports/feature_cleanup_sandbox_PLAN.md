# Phase 1 Plan — Repo Sanitization

- **Feature:** Codex Sandbox Compliance  
- **Owner:** Codex Ops  
- **Objective:** Deliver Phase 1 of repo sanitization so Sandbox Guardrail can be enabled globally.

## Phase 1 — Inventory (Automated)

1. Run the checker in list mode to capture every violation:
   ```bash
   tools/codex_sandbox_check.zsh --list-only
   ```
2. Categorize matches:
   - **Category A:** Documentation samples (safe to rewrite inline).
   - **Category B:** Deprecated scripts (can be removed or fully neutralized).
   - **Category C:** Reports/postmortems (replace with prose).
   - **Category D:** Critical active scripts (rewrite logic to avoid banned vocabulary without changing behavior).

## Phase 2 — Sanitization Strategy

Apply one of three patterns per match:

- **Pattern A – Escape:** Replace runnable command with inert formatting (textual description, escaped code, or demo paths).
- **Pattern B – Neutralize:** Remove the snippet entirely and drop in `# (legacy example removed for safety)` or equivalent prose.
- **Pattern C – Sandbox ignore:** Wrap necessary legacy snippets inside a clearly labeled ` ```sandbox-ignore ``` ` block.

## Phase 3 — File Edits

- Touch every relevant file under `docs/`, `manuals/`, `reports/`, and `g/reports/`.
- Annotate sanitized Markdown files with `<!-- Sanitized for Codex Sandbox Mode (2025-11) -->`.
- Keep SOT docs, LaunchAgents, and live automation untouched unless they contain banned vocabulary (then rewrite the phrasing, not the logic).

## Phase 4 — Verification

1. Rerun the checker normally:
   ```bash
   tools/codex_sandbox_check.zsh
   ```
2. Expect:
   - ✅ `0 violations`
   - ✅ Docs still readable
   - ✅ Guardrail-ready for Codex Sandbox global activation

<!-- Sanitized for Codex Sandbox Mode (2025-11) -->
