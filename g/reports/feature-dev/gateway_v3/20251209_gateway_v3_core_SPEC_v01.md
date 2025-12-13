# Gateway v3 Core — SPEC (Phase 0)

**WO:** WO-20251206-GATEWAY-V3-CORE  
**Scope:** Phase 0 – MAIN inbox → Mary router → CLC only  
**Safety:** Sandbox-friendly; only touches `bridge/` inbox/error and `g/telemetry/`  

---

## Functional Requirements (P0)
1. **Input:** Work Orders (WO) in `bridge/inbox/MAIN/` as YAML/JSON files.
2. **Normalization:** Load, validate minimal schema (`wo_id`, `title` required; optional `strict_target`, `routing_hint`, etc.).
3. **Routing Rules:**
   - `strict_target` present → allow only `CLC`; otherwise, send to error.
   - Else `routing_hint` in {`dev_oss`, `dev_oss_lane`} → target `CLC`.
   - Else default target `CLC`.
4. **Forwarding:**
   - Add `_routed_by`, `_routed_ts` fields.
   - Write to `bridge/inbox/CLC/` with same basename (prefer JSON if needed).
   - On failure: move to `bridge/error/MAIN/` with reason.
5. **Telemetry:**
   - Append JSONL to `g/telemetry/gateway_v3_router.jsonl` with: `ts, wo_id, source=MAIN, decision, target, error, file`.
6. **Modes:**
   - Oneshot CLI; no watch/daemon in P0.
   - `--dry-run`: log actions, no file writes/moves.
   - `--verbose`: detailed logging.
7. **Schema/Config:**
   - Schema mirror at `g/gateway/v3/core/schema/wo_v3.json`.
   - Config at `g/gateway/v3/core/config.yaml` (allowed_targets=[CLC], routing_hints map to CLC, default CLC).

## Non-Functional Requirements
- Safety: Only read/write under `bridge/` and `g/telemetry/`; no network calls.
- Language: Python 3; YAML support optional (PyYAML).
- Tests: Unit tests for normalization and routing decisions.
- Idempotent: rerunning on same files should not break (but P0 assumes single pass; watch mode deferred).

## Components
- `router.py`: CLI; routing/telemetry/error handling.
- `inbox_normalizer.py`: Parse/validate WO; basic type checks.
- `schema/wo_v3.json`: Minimal schema.
- `config.yaml`: Routing map + metadata (`_routed_by`).
- `tests/`: `test_router.py` for normalize/routing.
- `README.md`: Usage, flags, safety notes.

## CLI Interface
```
python g/gateway/v3/core/router.py \
  --source bridge/inbox/MAIN \
  --dest-clc bridge/inbox/CLC \
  --error-dir bridge/error/MAIN \
  --config g/gateway/v3/core/config.yaml \
  [--telemetry g/telemetry/gateway_v3_router.jsonl] \
  [--dry-run] [--verbose]
```

## Routing Logic (detailed)
1. Normalize WO (JSON/YAML → dict); required fields present.
2. Decision:
   - if `strict_target`:
     - if not CLC → decision=error
     - else target=CLC
   - elif `routing_hint` in map → target=mapped (CLC)
   - else target=default (CLC)
3. On route success: write to dest inbox; include `_routed_by`, `_routed_ts`.
4. On error: move original to error inbox; record reason.
5. Telemetry always appended.

## Telemetry Record
```json
{
  "ts": "<ISO8601>",
  "wo_id": "<id>",
  "source": "MAIN",
  "decision": "route|error",
  "target": "CLC|null",
  "error": "<string|null>",
  "file": "<basename>"
}
```

## Tests (P0)
- Normalize valid WO.
- Normalize missing required → raises NormalizeError.
- Routing:
  - strict_target=CLC → routed.
  - strict_target=non-CLC → error.
  - routing_hint=dev_oss → CLC.
  - default → CLC.

## Out of Scope (P0)
- Watch/daemon/LaunchAgent.
- Targets beyond CLC.
- Advanced schema enforcement or migrations.
- Writing to 02luka.md or other docs.

## Safety & Paths
- All operations must stay under repo root.
- Only touch `bridge/inbox/MAIN`, `bridge/inbox/CLC`, `bridge/error/MAIN`, and `g/telemetry/`.
- `--dry-run` for safe inspection.

## Deliverables Verification (P0)
- Files exist: router.py, inbox_normalizer.py, schema, config, README.
- Telemetry path reachable.
- Unit tests passing.
- Oneshot run with sample WOs produces expected routing/error.
