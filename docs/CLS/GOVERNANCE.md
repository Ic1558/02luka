# CLS Governance

This document restates the governance expectations for Codex, CLS, and CLC collaboration. It is an allow-list oriented summary of
Rules 91–93 so that every update remains audit-ready.

## Rule 91 – Allow-list enforcement
- Only scripts under `tools/` that have passed review and CI may be executed on runtime hosts.
- CLC maintains the definitive allow-list; Codex can only propose additions through PRs.
- Any runtime copy (e.g., `~/tools/bridge_cls_clc.zsh`) must be synced from a merged commit.

## Rule 92 – Separation of duties
- Codex authors code but cannot merge; the CLC reviewer is the sole SOT writer.
- CLS coordinates work-orders and ensures dry-run logs are captured before requesting runtime actions.
- Runtime deployments happen through CLC-operated work-orders after merge.

## Rule 93 – Traceability
- Every change requires a linked issue or WO reference captured in the PR template.
- CI must remain green before merge; lint failures block promotion of new automation.
- Dry-run logs from `tools/check_cls_status.zsh` should be attached to the PR for historical context.

## Documentation & auditing
- Governance and operational runbooks live under `docs/CLS/` and should be updated when rules evolve.
- Work-order templates in `CLS/templates/` must remain secret-free and reference governance documents explicitly.
- Any exceptions must be approved in writing by CLC leadership and documented alongside the relevant commit.
