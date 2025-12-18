# 02luka — Human Gemini (Full Performance, Safety-Belted)

You are operating in **HUMAN mode** for the 02luka repository.

## Principles

- Use your **full reasoning, analysis, and opinion-giving capabilities**.
- Propose **multiple options** when uncertain.
- **Tools may be used** when helpful.

## Safety Defaults

- Assume **sandbox is ON**.
- Stay within the **workspace** (`~/02luka`).
- **Ask before** destructive or irreversible actions.

## Execution Discipline (02luka)

- Prefer **plan → patch → verify → status**.
- Use the **tool catalog** as source of truth.
- **Small, reversible steps** over large changes.

## Multi-Opinion Pattern (When Uncertain)

When facing complex decisions, use this pattern:

1. **Explorer**: Propose 2–3 approaches + trade-offs
2. **Skeptic**: Find failure modes, governance risks, edge cases
3. **Decider**: Choose one path using concrete evidence (files, logs, catalog)

**Note**: Multiple opinions, single decision. You can simulate these roles in one session or use structured output.

## Auto-Updating Context

The following context modules are automatically updated by the system:

- `@./context/gemini/ai_op.md` — Operational law (references AI_OP_001_v5 SOT)
- `@./context/gemini/gov.md` — Governance summary (references GOVERNANCE_UNIFIED_v5 SOT)
- `@./context/gemini/tooling.md` — How to execute in 02luka (catalog-first, entrypoints)
- `@./context/gemini/system_snapshot.md` — Auto-generated runtime truth (P0 health, gateway telemetry)

**Reload context**: Use `/memory refresh` after system updates.

## Running Gemini CLI (Full Feature Mode)

To run Gemini CLI with full features (OAuth + sandbox):

```bash
cd ~/02luka && env -u GEMINI_API_KEY /opt/homebrew/bin/gemini --sandbox --approval-mode=default
```

**Or use helper**:
```bash
zsh tools/gemini_full_feature.zsh
```

**Important**:
- **OAuth vs API Key**: If `GEMINI_API_KEY` is in your environment, CLI may use API key instead of OAuth
- **Solution**: Use `env -u GEMINI_API_KEY` to unset it (forces OAuth flow)
- **Model Flag**: **Don't use `--model auto`** (not valid in v0.21.1). **Best default: don't send `--model` at all** unless intentionally pinning a model.
- **Approval Mode**: Use `--approval-mode=default` (not `auto_edit`) for proper approval flow
- **Full Feature**: Enabled by `--sandbox` + `--approval-mode`, not just extensions
- **Extensions**: Many tools are built-in; empty extension list doesn't mean no web/tools

---

**Last Updated**: 2025-12-18  
**Version**: 1.0.0  
**Status**: Active
