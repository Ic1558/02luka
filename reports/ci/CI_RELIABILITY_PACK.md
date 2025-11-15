# CI Reliability Pack — Quiet by Default

## Goal
Make CI quiet and reliable by default so only essential validation blocks merges while heavier suites stay available on demand.

## What Changed
- All non-`validate` jobs are **non-blocking**: `continue-on-error: true`, `timeout-minutes: 15`, and `strategy.fail-fast: false`.
- Added a dedicated `ci-summary` job (aka `summary`) that always runs so maintainers can see the pipeline end state even when optional jobs fail.
- `validate` prints the `boss-api` log tail on failure for faster triage.
- Heavy/experimental jobs (`ops-gate`, `rag-vector-selftest`) remain defined but no longer block merges by default.

## Gating Rules
Optional jobs run only when:
- The PR has the `run-smoke` label, **or**
- The PR title contains `[run-smoke]`, **or**
- The event is `push` to `main`/`develop` (always-on for branch protection).

Optional jobs are skipped when:
- PR title contains `[skip-smoke]`, **or**
- PR originates from a fork (`github.event.pull_request.head.repo.fork == true`).

## Branch Protection Guidance
Keep **only `validate`** marked as "Required" under Settings → Branches. Optional jobs will surface signal in `ci-summary` but not gate merges.

## Workflow Structure
```
┌─────────────────────────────────────────────────────┐
│ validate [REQUIRED]                                 │
│ - Phase 4/5/6 smoke tests (local, fast, ~5-8 min)   │
│ - Must pass for PR to be green                      │
│ - Timeout: 8 minutes                                │
├─────────────────────────────────────────────────────┤
│ ops-gate [OPTIONAL, gated]                          │
│ rag-vector-selftest [OPTIONAL, gated]               │
│ ci-summary [OPTIONAL, always runs]                  │
└─────────────────────────────────────────────────────┘
```

All jobs share:
- `timeout-minutes` to avoid hangs.
- `continue-on-error: true` for non-required jobs.
- `strategy: { fail-fast: false }` so matrix jobs finish even after a failure.

## Reviewer Notes
- Heavy jobs can be manually re-run by adding the `run-smoke` label, re-running the workflow, then removing the label.
- Local quickcheck (CLS): `./tools/dispatch_quick.zsh pr:quickcheck <PR#>`.
- To skip even optional jobs for docs-only changes, add `[skip-smoke]` to the PR title.
- `tools/ci/validate.sh` now honors `SKIP_BOSS_API=1` so validation can run without the server in constrained environments.

## Benefits
- Default experience: quiet PRs with fast feedback from `validate`.
- Opt-in controls let authors request heavier coverage explicitly.
- Pipeline logs include inline boss-api tails for actionable failures.
