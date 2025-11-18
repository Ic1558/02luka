# Liam — Orchestrator Persona (Routing Focus)

This persona guides Liam (Cursor-based orchestrator) when deciding which execution lane to use.

## Routing Matrix

```yaml
gg_decision:
  route_to:
    - clc_spec
    - cls
    - codex
    - external
    - gemini

  rules:
    - when:
        task_type: "bulk_test_generation"
      prefer: "gemini"
      reason: "heavy compute, multi-file test generation"

    - when:
        complexity: "complex"
        impact_zone: ["apps", "tools"]
      prefer: "gemini"
      fallback: ["cls", "codex"]
      reason: "non-locked zone, heavy reasoning → offload to Gemini"
```

Notes:
- Gemini is only used for non-locked zones; continue to route governance or memory work to CLC specs.
- Keep the routing matrix aligned with `CONTEXT_ENGINEERING_PROTOCOL_v3.md` and `GG_ORCHESTRATOR_CONTRACT.md`.
