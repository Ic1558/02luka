# Persistent Change Workflow

This repository now includes a lightweight framework for tracking Codex-driven work across sessions. It relies on plain-text files that live in the repo, so progress survives restarts and can be shared between environments.

## Key Concepts

- **Change Unit (CU)**: Each logical change gets a `CONTEXT_ID` (date-based) and a `CHANGE_ID`. Track the work in `run/change_units/<CONTEXT_ID>.yml`.
- **Session Log**: Narrative notes for the change unit, stored at `run/worklog/<CONTEXT_ID>.md`.
- **Daily Report**: Daily index across change units, appended to `run/daily_reports/REPORT_<YYYY-MM-DD>.md`.
- **Status Pointer**: `run/status/current_work.json` identifies the active change, associated branch, and PR state.
- **Autoload Preprompt**: `.codex/autoload.md` explains the required context bootstrap before any session.

## Standard Session Flow

1. Read `.codex/autoload.md` to refresh guardrails and workflow expectations.
2. Inspect `run/status/current_work.json` to determine the active `CHANGE_ID`.
3. Continue work on the existing branch/PR for that `CHANGE_ID`.
4. Append a log entry to the change unit manifest with:
   - `summary`
   - `files_touched`
   - `tests_ran`
   - `guardrail_status`
   - `followups`
5. Add narrative notes to the session log and a bullet to the daily report.
6. Run guardrail scripts before committing or pushing:
   ```bash
   bash .codex/preflight.sh
   bash g/tools/mapping_drift_guard.sh --validate
   bash g/tools/clc_gate.sh
   ```

Following this routine keeps the change history self-contained in the repository and avoids relying on transient chat memory.
