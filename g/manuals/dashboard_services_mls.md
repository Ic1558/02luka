# Dashboard Services & MLS Panels

Date: 2025-11-15

## Services Panel

- Source: `/api/services`
- Shows LaunchAgent services with label, type, status, PID, and exit code.
- Filters:
  - Status: running / stopped / failed
  - Type: bridge / worker / automation / monitoring / other
- Auto-refreshes every 30 seconds (plus manual Refresh button).
- Use it to quickly spot stuck or failing 02luka agents.

## MLS Panel

- Source: `/api/mls`
- Lists multi-loop-learning lessons (MLS) with time, type, title, score, tags, and verification state.
- Row click reveals details (context, related WO, related session).
- Filters:
  - Type: solution / failure / pattern / improvement
  - Checkbox: Verified only
- Auto-refreshes every 30 seconds to keep lessons up to date.
