# 02luka — Codex Master Readiness

**Goal:** When this file is detected, Codex must verify the dev session is sane and ready:
- Correct working dir: /workspaces/02luka-repo
- Node & Python available
- API (4000) & UI (5173) healthy
- Drive path usage avoided inside ProgramArguments (no "My Drive (1)")

## Checklist for this session
1) `pwd` must equal `/workspaces/02luka-repo`
2) `node -v` and `python3 -V` should respond
3) `curl -fsS http://127.0.0.1:4000/api/ping` returns JSON with `"status":"ok"` or fallback
4) UI reachable at `http://localhost:5173/luka.html`
5) If any check fails, propose the *exact* one-liner fix, then run it.

## What Codex should do next
- Load `.codex/PREPROMPT.md` and apply project style in `.codex/style_adaptations.yml`
- Prefer short absolute paths: `~/dev/02luka-repo` (host) or `/workspaces/02luka-repo` (container)
- Use scripts:
  - `.codex/preflight.sh`
  - `run/dev_up_simple.sh`
  - `run/smoke_api_ui.sh`
- If LaunchAgents context is needed, read `g/reports/AGENT_VALUE_AUDIT_*.json` and *do not* write into CloudStorage paths.

## Output contract
- Print a 3-line status summary:
  - API: OK/FAIL + tip
  - UI : OK/FAIL + tip
  - Tooling: node/python present
- Then wait for my next instruction.
