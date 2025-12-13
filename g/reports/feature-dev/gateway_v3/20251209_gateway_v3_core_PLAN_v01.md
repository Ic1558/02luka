# Gateway v3 Core — PLAN (Phase 0)

**WO:** WO-20251206-GATEWAY-V3-CORE  
**Scope:** Phase 0 (MAIN inbox → Mary router → CLC only)  
**Goal:** Stand up a minimal, safe gateway core that normalizes WOs from `bridge/inbox/MAIN/` and routes to CLC (strict_target/routing_hint/default). No production touch outside `bridge/` paths.  

---

## Objectives
- Normalize and route Work Orders (WOs) from MAIN inbox to CLC based on v3 schema rules (strict_target, routing_hint, default).
- Provide clear telemetry and error handling; sandbox-safe with dry-run.
- Keep Phase 0 self-contained; no LaunchAgent/watch yet.

## Deliverables (Phase 0)
- `g/gateway/v3/core/router.py` (CLI for routing oneshot)
- `g/gateway/v3/core/inbox_normalizer.py` (WO load/validate)
- `g/gateway/v3/core/schema/wo_v3.json` (schema mirror of v3)
- `g/gateway/v3/core/config.yaml` (routing map: CLC only; hints → CLC)
- `g/gateway/v3/core/tests/` (unit tests for normalize + routing)
- `g/gateway/v3/core/README.md` (usage, flags, safety)
- Telemetry: `g/telemetry/gateway_v3_router.jsonl`
- Error handling: `bridge/error/MAIN/` sink; forwarded to `bridge/inbox/CLC/`

## Out of Scope (Phase 0)
- Watch/daemon/LaunchAgent
- Targets other than CLC
- Advanced fields beyond minimal schema enforcement
- Writes outside `bridge/` and `g/telemetry/`

## Approach
1) Schema & Config
   - Define v3 schema (`wo_v3.json`) requiring `wo_id`, `title`; allow optional fields.
   - Config: allowed_targets = [CLC]; routing_hints map dev_oss/dev_oss_lane → CLC; default CLC.
2) Normalization
   - Load YAML/JSON; ensure dict; required fields; basic type checks.
   - Return payload + meta (source_file); reject invalid → error inbox.
3) Routing Logic
   - strict_target: allow only CLC; else error.
   - routing_hint: map to CLC if known; else ignore.
   - default: CLC.
   - Add `_routed_by`, `_routed_ts`; write to dest inbox with original filename.
4) Telemetry & Errors
   - Append JSONL record: ts, wo_id, source=MAIN, decision, target, error, file.
   - On failure: move to `bridge/error/MAIN/` with reason.
5) Tests
   - Normalize happy/invalid.
   - Routing: strict_target=CLC passes; strict_target=other → error; routing_hint dev_oss → CLC; default → CLC.
6) Safety
   - Only operate under repo root; only touch bridge/ and g/telemetry/.
   - Dry-run: log actions, no writes/moves.

## Phases & Gates
- Gate 1 (PLAN → SPEC → REVIEW): This PLAN + SPEC + self-review.
- Gate 2 (DRYRUN → VERIFY): Local oneshot run with sample WOs; unit tests.
- Gate 3 (IMPLEMENT → TEST): Code already in place; ensure tests pass.
- Gate 4 (REPORT): Summarize and mark WO Phase 0 complete (sandbox).

## Timeline (P0)
- PLAN/SPEC/REVIEW: 0.5d
- DRYRUN/VERIFY: 0.5d
- IMPLEMENT/TEST: complete (existing code)
- REPORT: 0.1d

## Risks & Mitigations
- Misrouting: enforce strict_target allowlist.
- Schema drift: minimal schema; validate required fields.
- Path safety: constrain to bridge/ and telemetry paths; dry-run option.

## Status
- PLAN drafted (v01).
- Implementation largely present in `g/gateway/v3/core/` (from sandbox).
- Need SPEC/RFC check and DRYRUN/REPORT for WO tracking.
