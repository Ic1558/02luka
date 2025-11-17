# Feature: WO Timeline MLS Overlay

**Date:** 2025-11-15  
**Scope:** Dashboard-only, read-only

## Goals

- Attach **MLS learning signals** directly onto the WO Timeline / History view.
- Allow quick answers to:
  - “WO นี้เคย fail กี่ครั้ง?”
  - “solution/pattern ถูกบันทึกหรือยัง?”
- Keep changes additive and low risk.

## API Extensions

### 1. `/api/mls`

New query parameter:

- `wo_id` (optional) — filter entries with `related_wo == wo_id`.

### 2. `/api/wos/history`

New query parameter:

- `include_mls=1` — when set, the response items include:

```jsonc
"mls_summary": {
  "total": 3,
  "solutions": 1,
  "failures": 1,
  "patterns": 1,
  "improvements": 0
}
```

This data is built from g/knowledge/mls_lessons.jsonl at request time.

## UI Behaviour
- WO Timeline view adds:
  - Checkbox: “Include MLS overlay”
  - When enabled each card shows a compact “MLS” line with counts per type.
- If the MLS file is missing or malformed the timeline still works (MLS overlay silently disabled, warning logged).

## Non-Goals
- No write operations are introduced.
- No change to signature verification or orchestration.
- No MLS editing via dashboard in this PR.

## Future Work
- Click-through from WO card → filtered MLS view for that WO.
- Correlate MLS patterns with CI runs and telemetry.
