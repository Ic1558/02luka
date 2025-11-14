# Codex Master Readiness

This checklist captures the minimum signals required before promoting changes into Codex master or enabling a new automation phase.

## Required Signals

1. **Spec + Plan signed off** – feature docs stored under `g/reports/`.
2. **Guardrails green** – CI, LaunchAgent self-tests, and telemetry dashboards show no regressions.
3. **Documentation synced** – README family, playbooks, and WO templates updated in the same PR.
4. **Boss review logged** – decision recorded in `g/reports/code_review_*`.
5. **Codex sandbox** – repository is scrubbed of disallowed command strings and `tools/codex_sandbox_check.zsh` must be green before merge.

Keep the checklist in the PR description and attach evidence links so reviewers can re-run any step.

<!-- Sanitized for Codex Sandbox Mode (2025-11) -->
