# Dashboard Services & MLS Panels

Date: 2025-11-15

## Overview
This update adds two operator-facing panels to the Work Orchestration dashboard so you can observe the runtime agents exposed by `/api/services` and `/api/mls` without leaving the browser. Both panels refresh every 30 seconds (alongside the manual Refresh button) so operators always see the latest health signals.

## Services Panel
- **Source:** `/api/services`
- **Summary metrics:** Cards call out total, running, stopped, and failed LaunchAgent services so regressions surface immediately.
- **Filters:**
  - Status: `running`, `stopped`, `failed`, plus an `all` view
  - Type: `bridge`, `worker`, `automation`, `monitoring`, `other`
- **Table view:** Real-time table showing `label`, `type`, `status`, `PID`, and `exit_code`, with inline empty/error states.
- **Accessibility:** Filter chips remain keyboard-focusable and inherit the dashboard’s focus styles.
- **Usage:** Quickly spot stuck or failing agents without cracking open logs.

## MLS Panel
- **Source:** `/api/mls`
- **Aggregated counters:** Totals across all lessons plus per-type counts (solutions, failures, patterns, improvements).
- **Filters:**
  - Type chips (`solution`, `failure`, `pattern`, `improvement`)
  - Checkbox: `Verified only`
- **Detail view:** Clicking a lesson row reveals context, related WO/session, score, tags, and verification state.
- **Auto-refresh:** Matches the dashboard cadence so new lessons show up without a reload.

## Navigation
A quick nav under the header links directly to `#services-panel` and `#mls-panel`, letting operators jump straight to the data they care about.

These additions are UI-only. The Node API server and security layers are unchanged, so risk stays low while observability improves.
