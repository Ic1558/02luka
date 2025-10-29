# CLS Operations Runbook

This guide explains how Codex, CLS, and CLC collaborate using the repository-based workflow.

## Workflow overview
1. **Codex** creates a feature branch, implements changes, and opens a PR using `.github/PULL_REQUEST_TEMPLATE.md`.
2. **CI** executes `.github/workflows/cls-ci.yml` to lint scripts and perform the dry-run smoke test.
3. **CLS** reviews outputs, confirms governance alignment, and attaches dry-run logs.
4. **CLC** merges the PR and, if needed, deploys runtime copies via an approved work-order.

## Scripts
- `tools/bridge_cls_clc.zsh`: validates work-order metadata and prints dispatch instructions.
- `tools/check_cls_status.zsh`: smoke test used locally and in CI (`--dry-run` mode in CI).
- `tools/lib/cli_common.zsh`: shared helper library (`ts`, `die`, `sha256`, `require_cmd`).

## CI details
- Runs on `pull_request` touching CLS assets and on `push` to `main`.
- Installs `shellcheck`, `shfmt`, and `yamllint` using Homebrew (`macos-latest`).
- Executes `shellcheck` (warnings allowed initially), `zsh -n`, `yamllint`, and the dry-run smoke test.

## Dry-run expectations
- Include the log output from `tools/check_cls_status.zsh --dry-run` in the PR description.
- Ensure the WO template path resolves correctly and checksum is recorded in the log.

## Runtime deployment (optional)
- After merge, CLC may sync `tools/*.zsh` to `~/tools/` on runtime hosts.
- Deployment requires a separate work-order referencing the merged commit hash.

## Communication
- Link governance references (`docs/CLS/GOVERNANCE.md`, `02luka.md`) in both issues and PRs.
- Use the issue template `cls_task` when requesting Codex work to keep metadata consistent.
