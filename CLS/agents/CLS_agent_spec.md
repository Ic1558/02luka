# CLS Agent Specification

The CLS automation pipeline is responsible for orchestrating work-orders (WOs) between Codex, CLS operators, and the CLC runtime team.
This document captures the non-sensitive rules that govern the automation components. Secrets or runtime tokens MUST NOT be committed to
the repository.

## Roles
- **Codex**: Designs and proposes changes through Git pull requests.
- **CLS**: Coordinates work-orders, reviews CI artifacts, and ensures compliance with governance.
- **CLC**: Acts as the sole system-of-truth (SOT) writer and deploys approved scripts to runtime hosts.

## Non-negotiable rules
1. Rule 91 – Only allow-listed scripts may be executed on runtime systems. Any new script must be reviewed and added to the allow-list
   before execution.
2. Rule 92 – CLS cannot directly modify runtime state; handoffs occur via CLC-reviewed work-orders.
3. Rule 93 – All actions must be traceable through Git history or recorded work-order artifacts.

## Deliverables for automation updates
- Workflows MUST run linting (`zsh -n`, `shellcheck`, `yamllint`) on relevant assets.
- Dry-run evidence from `tools/check_cls_status.zsh --dry-run` must accompany every PR touching CLS automation.
- Documentation updates belong under `docs/CLS/` so that operators can cross-reference governance quickly.

## Operational notes
- Runtime deployment is optional and performed by CLC after merge approval.
- Any additional helper scripts should reuse functions defined in `tools/lib/cli_common.zsh` for consistency.
- Avoid introducing dependencies that require network access during CI; everything should execute offline.
