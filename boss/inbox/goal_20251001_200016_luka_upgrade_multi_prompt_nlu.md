# GOAL: Luka Web App Upgrade — Multi-Optimize Prompt + NLU Chatbot + Rename index → luka.html

## Why
- Current HTML lacks a **Prompt Composer** with optimization strategies → outputs vary and are hard to reproduce.
- Need natural-language control (NLU) on backend to trigger actions (“สร้าง goal ใหม่”, “เปิด inbox”, “link ไป Cursor”).
- Unify entrypoint by renaming **index.html → luka.html** and adopting a Linear-like layout.

## What (Deliverables)
1) **UI (boss-ui/luka.html)**  
   - Replace/rename `index.html` → `luka.html` (keep simple static build).
   - Top bar: New Goal, Search, Engine selector (Local / Anthropic / OpenAI via server proxy), “Link to Cursor”.
   - Sidebar: Inbox, Sent, Deliverables, Anthropic, Settings.
   - Main (2-pane): list (mailbox) + detail viewer (markdown/preview).
   - **Prompt Composer** (bottom drawer):
     - Inputs: “System”, “User Prompt”, “Context toggles” (include PREPROMPT, PATH_KEYS, selected files).
     - **Strategy chips** (multi-select): `Clarify`, `Decompose`, `Constrain`, `Critique`, `Testcases`, `Security`, `Refactor`, `Docstring`.
     - Button: **Optimize** → calls `/api/optimize_prompt` → returns N variants ranked.
     - Button: **Run** → calls `/api/chat` with chosen variant; show response in detail pane (stream later).
     - Button: **Save as Goal** → writes `boss/inbox/goal_*.md`.

2) **Backend (boss-api/server.cjs)**  
   - Keep `POST /api/goal` (done).
   - Add `POST /api/optimize_prompt` → returns `{ variants: [ {id, score, title, prompt, rationale} ] }`
     - Phase-1 heuristic (no external key required): rule-based rewrites using known patterns.
     - Phase-2 (optional): if `ANTHROPIC_API_KEY` or `OPENAI_API_KEY` present → improve variants via provider, server-side only.
   - Add `POST /api/chat` (NLU aware):
     - Body: `{ input, system?, model?, context?, engine? }`
     - If `input` matches **NLU intents** → route to action (see below). Else → LLM chat via provider.
   - **NLU intents** (first cut, rule+regex; upgradeable to classifier):
     - `create_goal(title?, body?)` → write file via resolver to `human:inbox`.
     - `open(mailbox)` → return `/api/list/:mailbox`.
     - `link_to_cursor(goal_file)` → return prebuilt Codex command string.
     - `search(query)` → grep within `boss/` & `run/`.
   - CORS: allow `GET, POST, OPTIONS`. JSON limits & sanitization.

3) **Cursor Link (UI)**  
   - In detail pane of a goal → show **“Copy Codex Command”** that embeds the 02luka guardrails (master prompt reference, resolver-only wording).

4) **Renames & wiring**
   - `boss-ui/index.html` → **`boss-ui/luka.html`**
   - Update any scripts or docs referencing `index.html`.

5) **Tests / Smoke**
   - Extend `run/smoke_api_ui.sh`:
     - Check `GET /api/list/inbox` → 200.
     - POST `/api/optimize_prompt` with a small prompt → 200 and ≥1 variant.
     - POST `/api/chat` with “open inbox” → returns intent result (not LLM call).
     - If API keys exist → minimal live call returns 200; else 400/401 accepted.

## Guardrails
- All file paths via `g/tools/path_resolver.sh` (no absolute/symlinks).
- No client-side keys; providers via server only.
- Minimal diffs, update manifest & daily report, Conventional commit w/ CHANGE_ID + tags.

## Manifests
- Append `run/change_units/CU-2025-10-02.yml`
- Append `run/daily_reports/REPORT_2025-10-02.md`

## Commit (example)
feat(ui,api): add Luka Prompt Composer (multi-opt) + NLU router; rename index→luka (CHANGE_ID: CU-2025-10-02-luka-upgrade) #boss-ui #boss-api #resolver #preflight
