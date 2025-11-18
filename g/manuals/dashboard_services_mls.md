# Dashboard Services & MLS Panels

Date: 2025-11-15

This update introduces two operator-focused panels to the Work Orchestration dashboard so you can observe runtime agents and learning signals without leaving the browser.

## Services Panel
- **Source:** `/api/services`
- **Summary metrics:** Cards display total, running, stopped, and failed LaunchAgent services.
- **Filters:**
  - Status chips: `all`, `running`, `stopped`, `failed`
  - Type chips: `bridge`, `worker`, `automation`, `monitoring`, `other`
- **Table view:** Real-time table with `label`, `type`, `status`, `PID`, and `exit_code`. Empty/error states are handled inline, and the section auto-refreshes every 30 seconds (plus manual refresh button).
- **Use cases:** Quickly spot stuck or failing agents, confirm PID/exit codes, and verify LaunchAgent coverage per service type.

## MLS Lessons Panel
- **Source:** `/api/mls`
- **Aggregated counters:** Totals for all lessons plus per-type counts (solutions, failures, patterns, improvements) sourced from the API payload.
- **Filters:** Type pills let you slice client-side; a "Verified only" checkbox keeps focus on trusted learnings.
- **Detail view:** Clicking a lesson row reveals time, title, score, tags, verification state, related work order, and related session context.
- **Auto-refresh:** Polls every 30 seconds so new lessons appear alongside the latest services data.
- **Accessibility:** Filter chips are focusable buttons and list rows advertise active selection to match the dashboard’s existing interaction patterns.

## Navigation
A quick nav under the dashboard header links directly to `#services-panel` and `#mls-panel`, making it easy for operators to jump to the data they care about. These enhancements are front-end only—the API server and security layers remain unchanged.
