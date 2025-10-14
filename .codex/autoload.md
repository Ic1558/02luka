# Auto-Preprompt Bootstrap

Always read this file before starting a session. It establishes the shared workflow for long-running changes.

1. Load the guardrails in `.codex/CONTEXT_SEED.md`, `.codex/GUARDRAILS.md`, and `.codex/PATH_KEYS.md`.
2. Determine the active change by inspecting `run/status/current_work.json`.
3. Append your progress to the appropriate log files before ending the session.
   - `run/change_units/<CONTEXT_ID>.yml`
   - `run/worklog/<CONTEXT_ID>.md`
   - `run/daily_reports/REPORT_<YYYY-MM-DD>.md`
4. Reuse the branch and PR associated with the active `CHANGE_ID`. Do not create duplicates.
5. Run the guardrail checks before pushing:
   ```bash
   bash .codex/preflight.sh
   bash g/tools/mapping_drift_guard.sh --validate
   bash g/tools/clc_gate.sh
   ```
