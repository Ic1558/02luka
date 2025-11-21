# V4 Task Layer v02 - CLC Local Validation Plan

**Date**: 2025-11-22  
**Agent**: Liam (Antigravity)  
**Status**: EXECUTED

---

## Context

The V4 Task Layer aims to unify how tasks are orchestrated and executed across the system. `clc_local` is the designated local patch executor, designed to be model-agnostic and safe. This plan covers the validation and integration of `clc_local` into the V4 ecosystem.

## Scope

**Included:**
- Full validation of `clc_local` core modules.
- Execution of the full test suite (executor, policy, impact assessment).
- Lane registration in governance and Liam router.
- AI context mapping in `agent_capabilities.json`.
- Self-check and E2E demo verification.
- Documentation and Work Order specification.

**Excluded:**
- Changes to V4 core protocols (FDE, AP/IO) unless critical.
- Hard-coding of specific models (must remain agnostic).
- Production deployment (this is a validation phase).

## Risks & Constraints

1.  **Model Agnostic**: The system must not assume "Claude" or any specific model. Model selection is handled via configuration/environment.
2.  **Safety**: `clc_local` must adhere to strict policy checks (file access, dangerous operations).
3.  **Path Rules**: All paths must follow SOT conventions (`lib/path_config.zsh`, no `~`).

## Execution Strategy

1.  **Validation**: Verify imports and run `pytest` suite.
2.  **Integration**: Register lane in `mary_router.py` and `LANE_PROMPTS.md`.
3.  **Context**: Update `agent_capabilities.json`.
4.  **Verification**: Run `self_check.py` and `demo_e2e.py`.
5.  **Documentation**: Produce this plan and the accompanying spec.

---

## Outcome

All tasks in this plan have been executed successfully. `clc_local` is now a validated, integrated component of the V4 Task Layer.
