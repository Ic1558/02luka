# Dashboard Services & MLS Panels

**Date:** 2025-11-15

This update adds two operator-facing panels to the Work Orchestration dashboard so you can observe the runtime agents exposed by `/api/services` and `/api/mls` without leaving the browser.

## Services Panel
- **Summary metrics** – Cards for total, running, stopped and failed LaunchAgent services.
- **Filters** – Inline chips let you slice by status (`all`, `running`, `stopped`, `failed`) or type (`bridge`, `worker`, `monitoring`, `automation`, `other`).
- **Table view** – Real-time table driven by `/api/services` showing `label`, `type`, `status`, `PID`, and `exit_code`. Empty/error states are handled inline.
- **Auto-refresh** – Tied into the existing 30s dashboard refresh cadence so the counts and table stay current alongside the health pill.
- **Source:** `http://127.0.0.1:8767/api/services` (Python API server)
- **Use case:** Quickly spot stuck or failing 02luka agents.

## MLS Lessons Panel
- **Aggregated counters** – Totals for all lessons plus per-type counts (solutions, failures, patterns, improvements) sourced from `/api/mls`.
- **Type filter** – Pill controls filter the lesson list client-side while keeping access to the full summary.
- **Rich detail view** – Clicking a lesson row opens contextual metadata (title, timestamp, score, context, tags, related WO/session) without leaving the panel.
- **Keyboard-friendly** – All filter chips are focusable buttons and the list rows advertise active selection, matching the dashboard's existing accessibility conventions.
- **Source:** `http://127.0.0.1:8767/api/mls` (Python API server)
- **Auto-refresh:** Every 30 seconds to keep lessons up to date.

## Navigation
A quick nav under the header links to the new sections (`#services-panel`, `#mls-panel`) so operators can jump straight to the data they care about.

## Technical Notes
- These panels only touch the front-end: the Node API server and security layers remain unchanged.
- API endpoints are wired to the Python API server at `http://127.0.0.1:8767` (not the Node.js dashboard server).
- The dashboard server (`wo_dashboard_server.js`) only exposes `/api/wos`, `/api/wo/:id`, and `/api/followup`; it does not implement `/api/services` or `/api/mls`.
