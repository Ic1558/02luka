# Feature: Kim / Telegram WO Reality Command

**Date:** 2025-11-15  
**Scope:** Kim Agent only, read-only

## Goal

Allow Boss to ask Kim for a **reality snapshot** of a specific WO, combining:

- WO state (status, duration, agent)
- MLS summary (solutions/failures/patterns/improvements)
- Rule-based recommendation

via a simple Telegram command.

## Command

- `/wo <WO-ID>`

Examples:

- `/wo WO-20251115-001`

## Behaviour

For a valid WO:

- Replies with:
  - ID, status, agent, duration
  - Summary, PR, tags
  - MLS stats
  - Recommendation (level/code/title/details)
  - Dashboard deeplink

For invalid WO:

- `❗ ไม่พบ WO: <id>`

For network / JSON errors:

- Short Thai message explaining the error.

## Implementation

- Uses `GET ${DASHBOARD_BASE_URL}/api/wos/:id/insights`
- No write operations, no CI / orchestrator changes.

## Future Work

- Aggregate command:
  - `/wo_today` → list of failed WOs without solutions.
- Hook Mary / CLC to auto-check for high-risk WOs.
