# Governance v4.1 — Behavior Notes (Implementation View)

**Scope:** Behavior summary of the v4.1 enforcement code (router + AI Manager).  
**Purpose:** Quick reference for developers; not a governance spec update.

---

## Pattern Matching Order
- The router checks **locked patterns first**, then open patterns.
- If a path matches any locked pattern → `locked_zone`.
- If none match locked but some match open → `open_zone`.
- If a path matches **neither locked nor open**, it is treated as `locked_zone` (secure-by-default).

## Writer Normalization
- Mapping: `gg→GG`, `gc→GC`, `liam→LIAM`, `cls→CLS`, `codex→CODEX`, `gmx→GMX`, `clc→CLC`.
- Any writer outside this map → `UNKNOWN`.
- `UNKNOWN` writers are **denied** in all zones.
- `normalized_writer` is included in governance results for debugging/telemetry.

## UNKNOWN Writer Policy
- `UNKNOWN` → `writer_not_allowed`, regardless of zone.
- Zone resolution still runs (and may be locked if paths are unknown), but permission check blocks the request.

## Lane Policy (summary)
- `locked_zone`: dev lanes are blocked.
- `open_zone`: dev lanes allowed (`dev_oss`, `dev_gmxcli`, `dev_codex`).

## Telemetry Helper
- `to_telemetry_dict(result)` provides a ready-to-log dict:
  - `zone`, `allowed`, `writer`, `normalized_writer`, `lane`, `reason`, `details`

---

**Note:** This file documents observed behavior of the implementation and is not an amendment to AI/OP-001 or other governance specifications.
