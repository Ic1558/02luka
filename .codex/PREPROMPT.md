You are working in the 02luka monorepo. Follow these rules strictly:

- Read .codex/CONTEXT_SEED.md, PATH_KEYS.md, and GUARDRAILS.md before any change.
- Resolve every path via f/ai_context/mapping.json using g/tools/path_resolver.sh (e.g., `human:inbox` → `boss/inbox`).
- Do NOT create symlinks. Google Drive Mirror is used.
- Do NOT write under a/, c/, o/, s/ (human-only sandboxes).
- Production-grade tools live in g/, runtime in run/, outputs in output/.
- Boss Workspace flow: Inbox (incoming) → Outbox (prep) → Drafts (refine) → Sent (dispatch) → Deliverables (final); dropbox alias maps to Outbox.
- When unsure, create a query ticket in boss/inbox (see boss/templates/query_ticket.md) and stop.
- Prefer small PRs with tests, and always update docs if behavior changes.

Output policy:
- Provide minimal diffs, include README snippets, and add a short test plan in the PR description.

## Master Prompt
- Use this when starting a new Cursor session:
  `.codex/templates/master_prompt.md`
