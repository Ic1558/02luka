# Dashboard Services & MLS Panels

Date: 2025-11-15

## Overview
This update adds two operator-facing panels to the Work Orchestration dashboard so you can observe the runtime agents exposed by `/api/services` and `/api/mls` without leaving the browser.

## Services Panel
- **Source** – `/api/services`.
- **Summary metrics** – Cards for total, running, stopped, and failed LaunchAgent services.
- **Filters** – Inline chips/selectors let you slice by status (`all`, `running`, `stopped`, `failed`) and type (`bridge`, `worker`, `monitoring`, `automation`, `other`).
- **Table view** – Real-time table showing `label`, `type`, `status`, `PID`, and `exit_code`. Empty/error states are handled inline.
- **Auto-refresh** – Refreshes every 30 seconds (plus a manual Refresh button) so the counts and rows stay aligned with the health pill.
- **Usage** – Quickly spot stuck or failing 02luka agents without SSHing into hosts.

## MLS Lessons Panel
- **Source** – `/api/mls`.
- **Aggregated counters** – Totals for all lessons plus per-type counts (solutions, failures, patterns, improvements) with optional "Verified only" view.
- **Type filters** – Pill controls filter the lesson list client-side while keeping access to the full summary.
- **Detail view** – Clicking a lesson row reveals context, related WO/session, score, tags, and verification state.
- **Auto-refresh** – Polls every 30 seconds so lessons stay current with the work-order stream.

## Navigation
A quick nav under the header links directly to the new sections (`#services-panel`, `#mls-panel`), making it easy for operators to jump to the data they care about.

Both panels are front-end only; the Node API server and security layers remain unchanged.
