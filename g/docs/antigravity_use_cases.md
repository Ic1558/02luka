# Antigravity — Professional Use Cases & Capabilities (Practitioner Guide)

Antigravity (Gemini 3–powered, agent-first IDE) excels when you let agents run end-to-end flows while you review plans and artifacts. Use this guide as practitioner notes (not contract/SOT) for how to apply it in day-to-day work.

## Core Professional Use Cases
- **Greenfield feature builds:** Agents scaffold code, wire APIs, write tests, and validate in-browser.
- **Large refactors/upgrades:** Multi-file edits with plans, diffs, and incremental checks to keep risk low.
- **API/SDK integrations:** Generate clients, add env/config wiring, and run smoke tests.
- **Regression/QA runs:** Execute tests plus browser-driven flows to catch DOM/visual regressions.
- **Docs/enablement:** Generate or refresh README/HOWTOs alongside code changes for review.

## Capabilities Snapshot
- **Agent-first surfaces:** Editor + terminal + browser control in one loop (read/edit files, run commands, drive UI).
- **Planning and artifacts:** Agents propose plans, produce structured diffs/artifacts, and incorporate feedback mid-run.
- **Multi-model orchestration:** Gemini 3 default, with optional Claude/OSS via unified routing.
- **Run and verify:** Shell/test execution with captured stdout/stderr/exit codes; browser actions with screenshots/notes.
- **Learning reuse:** Successful snippets/flows can be logged for reuse across tasks.

## Opinionated Workflow Example (Next.js Feature)
1) **Frame the task:** In the Manager view, create a goal like “Add profile edit form with validation” and mark expected checks (unit + basic UI smoke).  
2) **Review the plan:** Let the agent propose a step list (scaffold component, add API route, tests, UI check). Edit/approve before execution.  
3) **Code + tests:** Agent edits files via the editor surface, runs `npm test`/`npm run lint` (or project defaults), and captures logs.  
4) **Browser validation:** Agent opens the app, navigates to the form, fills inputs, and records a screenshot/log noting success/fail.  
5) **Feedback loop:** Leave comments on diffs or screenshots; agent updates without restarting the run.  
6) **Review artifacts:** Inspect diffs/artifacts, verify tests, and only then accept/apply changes.  
7) **Document:** Have the agent update the feature README/CHANGELOG so the change is discoverable.

## Tips
- Prefer plans+deltas over ad-hoc prompts; insist on artifacts/diffs for every code change.
- Keep QA in the loop: run lint/tests and a minimal browser flow before accepting.
- Use model routing intentionally (e.g., Gemini for reasoning, OSS for cost-sensitive tasks) but keep the workflow consistent.
