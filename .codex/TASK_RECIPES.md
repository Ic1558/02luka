# Task Recipes

1) Boss-UI (React+Node)
- boss-api: list/read via resolver; endpoints `/api/list/:folder`, `/api/file/:folder/:name`
- boss-ui: Gmail-like sidebar (Inbox/Sent/Deliverables/Dropbox/Drafts/Documents)
- README explains Boss flow and how to run

2) Add routing rule
- Edit `boss/routing.rules.yml`
- E2E: drop a `.json` into `human.dropbox` → must appear in `f/bridge/inbox`

3) New watcher LaunchAgent
- Create plist under g/fixed_launchagents/
- Publish with launchagent_manager.sh; logs under ~/Library/Logs/02luka/

4) Nightly self-test
- g/tools/nightly_selftest.sh + plist → write summary to run/system_status.v2.json

---

# Prompt: Boss UI Scaffold
Use `.codex/PREPROMPT.md` as system context.

Goal: Scaffold “Boss UI” (Gmail-like) that reads/writes via mapping keys (`human.*`) only.

Steps:
1. Read `.codex/CONTEXT_SEED.md` and `.codex/PATH_KEYS.md`.
2. Create boss-api (Node) with endpoints `/api/list/:folder` and `/api/file/:folder/:name` that resolve paths using `g/tools/path_resolver.sh`.
3. Create boss-ui (React) with sidebar: Inbox, Sent, Deliverables, Dropbox, Drafts, Documents; main panel: file list + markdown viewer.
4. Provide a README inside boss-ui explaining Boss Workspace flow and how to run locally.
5. Add a smoke test plan: place a file in `human.dropbox` and verify it appears in the UI (list).
6. Update docs if needed.

Constraints:
- No symlinks. No hardcoded absolute paths.
- Keep changes small and self-contained. Provide a PR description with the test plan.

---

# Environment Setup Notes
- Add `.devcontainer/devcontainer.json` or a Dockerfile with `postCreateCommand: .codex/preflight.sh`.
- Alternatively, run `bash .codex/preflight.sh` before development sessions to fetch the latest context.
