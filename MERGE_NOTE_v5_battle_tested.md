# Merge Note: Governance v5 Battle-Tested Hardening + Gateway Single-Process Stability

## Title
Governance v5 Battle-Tested Hardening + Gateway Single-Process Stability

## What Changed

- **Gateway v3** now handles all v5 statuses correctly (COMPLETED / EXECUTING / REJECTED / FAILED) and logs `action=process_v5` consistently.
- **Removed the major instability source**: duplicate gateway processes (Mary-COO no longer spawns gateway).
- **SandboxGuard v5** hardened against path injection edge cases (null byte / newline / traversal variants) and rejects hostile/empty paths deterministically.
- **Router v5** hardened trigger resolution: invalid/unknown triggers are safely rejected into BLOCKED (no unsafe default).
- **Production monitor script** fixed: accurate v5 vs legacy detection + lane distribution from telemetry JSONL.

## Why

- Previously, REJECTED handling could trigger file-move race / exception → gateway fallback to legacy routing.
- Duplicate gateway processes caused inconsistent lane outcomes (PR-10 flapping STRICT vs FAST).
- Stress tests found real security gaps (null byte/newline/traversal variants) — now closed.

## Verification

- **Unit suite**: `pytest tests/v5_*` ✅ (0 failures; xfails expected)
- **Battle suite**: `pytest tests/v5_battle/` ✅ (security/stress/edge/chaos)
- **Runtime check**: telemetry shows `action=process_v5`, no `"action":"route"` fallback observed.
- **PR-10 verified**: CLS auto-approve routes to FAST lane consistently (local ops).

## Rollout / Ops

- Gateway LaunchAgent remains the only gateway runner.
- Mary-COO LaunchAgent runs only `agents/mary/mary.py`.

## Breaking / Operational Changes

**CRITICAL:** LaunchAgent configuration changes
- `com.02luka.mary-coo` MUST run `agents/mary/mary.py` ONLY (not gateway_v3_router.py)
- `com.02luka.mary-gateway-v3` is the ONLY gateway runner
- **DO NOT** let Mary-COO spawn gateway processes (causes routing conflicts)

**Router v5 changes:**
- CLS auto-approve now works for OPEN zone + whitelist paths (PR-10 intent)
- DANGER patterns fixed: removed non-functional patterns (^/$, rm -rf commands)
- Path traversal patterns added to DANGER zone detection

**Monitor script:**
- Fixed 24h window calculation (now filters by timestamp, not entire log)

## Commits

1. **Core Runtime**: `fix(v5): battle-tested hardening + gateway single-process stability + security validations`
2. **Battle-Test Suite**: `test(v5): battle-tested suite (security, stress, rollback, chaos)`
