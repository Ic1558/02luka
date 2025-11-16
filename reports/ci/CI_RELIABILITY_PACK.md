# CI Reliability Pack — Quiet by Default

**Goal:** Keep PRs green by default while still offering on-demand heavy smoke coverage when engineers explicitly request it.

## Summary of Changes
- Only the `validate` job is required; all other jobs (`ops-gate`, `rag-vector-selftest`, `ci-summary`) now run with `continue-on-error: true`, `timeout-minutes` guards, and `strategy.fail-fast: false`.
- Heavy jobs are gated behind an opt-in signal (`run-smoke` label, `[run-smoke]` in the PR title, or any push to `main`/`develop`).
- `validate` always prints the last 200 lines of `boss-api` logs when it fails so the root cause is obvious without spelunking artifacts.
- A dedicated `ci-summary` job (with `if: always()`) shows the end state of every job so maintainers can see optional failures without blocking merges.

## Why
- Reduce noisy red PRs during R&D bursts.
- Keep the single required check focused on fast, deterministic validation.
- Make failures actionable with inline logs rather than opaque artifacts.

## Job Classification
### Required
- **validate** – Phase 4/5/6 smoke tests (fast path, ~5–8 min). Must pass for merge.

### Optional (non-blocking)
- **ops-gate** – Phase 5/6/7 smoke tests (ops layer)
- **rag-vector-selftest** – Phase 15 RAG vector tests
- **ci-summary** – Aggregates the final status of all jobs

All optional jobs:
- Run with `continue-on-error: true`
- Use explicit `timeout-minutes` to avoid hangs
- Set `strategy: { fail-fast: false }` when matrixed
- Skip automatically on forked PRs

## Opt-in Label/Title Gating
Optional jobs only run when:
- PR has the `run-smoke` label, **or**
- PR title contains `[run-smoke]`, **or**
- Event is a push to `main`/`develop` (always run on protected branches)

Optional jobs are explicitly skipped when:
- PR title contains `[skip-smoke]`
- PR originates from a fork (`github.event.pull_request.head.repo.fork == true`)

### How to request heavy coverage
1. Add the `run-smoke` label to your PR, **or** include `[run-smoke]` in the title.
2. Re-run the workflow from the Actions tab if it already completed.

### Example PR titles
- `feat: new vector index [run-smoke]`
- `fix: hot path regression [skip-smoke]`

## Workflow Enhancements
- `tools/ci/validate.sh` respects `SKIP_BOSS_API=1` for local fast iterations.
- `scripts/smoke_with_server.sh` prints boss-api log tails whenever the job fails.
- `ci-summary` consolidates job outcomes so maintainers know which optional suites failed/skipped without digging through each job.

## Usage Guide
### For PR Authors
- **Normal PR:** Do nothing. Only `validate` runs and must pass.
- **Need heavy smoke:** Add the `run-smoke` label or `[run-smoke]` in the title.
- **Docs-only PR:** Add `[skip-smoke]` to the title if you want every optional job skipped even on pushes.

### For Maintainers
1. Label the PR with `run-smoke` to force heavy coverage.
2. Re-run the workflow if needed, then remove the label after verification.
3. Check the always-running `ci-summary` job for a consolidated report.

### Local Quickcheck
```bash
# Fast validation without boss-api start
SKIP_BOSS_API=1 bash tools/ci/validate.sh

# Full validation (default)
bash tools/ci/validate.sh

# CLS helper
./tools/dispatch_quick.zsh pr:quickcheck <PR#>
```

## Benefits
1. **Fewer Red PRs** – Only critical validation blocks merges.
2. **Faster Feedback** – Most PRs complete in ~5–8 minutes.
3. **On-Demand Testing** – Heavy suites available via `run-smoke` without touching workflow YAML.
4. **Fork Friendly** – External contributors avoid expensive jobs automatically.
5. **Better Debugging** – boss-api tails are surfaced automatically on failure.
6. **Deterministic** – Timeouts + fail-fast disabled matrices keep CI resilient.

## Troubleshooting
- **"Why is my PR green but some jobs show skipped?"** Optional suites skipped by default; add `run-smoke` to run them.
- **"Validate failed—where are the logs?"** Scroll to the end of the job; the script prints the boss-api tail automatically.
- **"I want zero smoke for docs-only"** Add `[skip-smoke]` to the PR title.
- **"Need local validation without the server"** Run `SKIP_BOSS_API=1 bash tools/ci/validate.sh`.

## Future Enhancements
- Path-based gating (skip tests when only `.md` changes).
- Scheduled nightly runs of optional suites.
- Multi-runtime matrices (Node/Python versions) for compatibility.
- Add SAST/dependency checks behind the same gating primitives.
