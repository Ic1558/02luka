# CLC V4 Specification — Optional Specialist Tool
**Source of Truth:** `g/ai_contracts/lac_contract_v2.yaml`  
**Role:** Optional specialist for complex or multi-file patches (NOT a default gateway)  
**Default Pipeline:** DEV → QA → DOCS → DIRECT_MERGE when `self_apply=true` and QA passed

## Positioning
- CLC is **optional** and only used when:
  - `work_order.requires_clc == true`, or
  - `work_order.complexity == "complex"`, or
  - Multi-file threshold exceeded (e.g., `file_count > 3`)
- CLC has **no veto power**; it executes when routed for specialist help.
- Simple WOs follow the self-complete path without CLC.

## Interface
- **Input:** Work Order JSON (schema-aligned) + patch set
- **Output:** `{ status, diff_summary, logs }`
- **Behavior:** Apply patches when requested; do not block DIRECT_MERGE path.

## Routing Rules (align with lac_contract_v2)
- Route to `clc_local` only when complexity/explicit flag/multi-file triggers.
- Otherwise, remain on normal lanes (dev/qa/docs + direct merge).
