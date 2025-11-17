# CI Reliability Pack — Quiet by Default

**Goal:** Make CI calm, actionable, and reliable by default. Critical validation stays required, while heavier workflows become on-demand so most PRs stay green without losing observability.

## Summary of Changes
1. **Job classification**
   - `validate` remains the single required job (Phase 4/5/6 smoke). Runs on every PR.
   - `ops-gate`, `rag-vector-selftest`, and `ci-summary` are optional (`continue-on-error: true`, `timeout-minutes` caps, `strategy.fail-fast: false`).
2. **Gating**
   - Optional jobs run when the PR has the `run-smoke` label, the PR title contains `[run-smoke]`, or the workflow is triggered by `push` to protected branches.
   - Optional jobs are skipped when `[skip-smoke]` appears in the title or the PR originates from a fork.
3. **Reliability boosts**
   - All non-validate jobs use `continue-on-error: true`, `timeout-minutes` (15), and `strategy.fail-fast: false` so one failure doesn’t cancel the matrix.
   - `validate` prints the `boss-api` log tail on failure via an `always()` step.
   - Added a dedicated `summary` job (a.k.a. `ci-summary`) with `if: always()` to report the final state of every job, even when optional jobs fail.

## Why
- Reduce noisy red PRs during R&D bursts by keeping the only required check fast and deterministic.
- Keep heavy/experimental coverage available, but only when requested via labels/titles or on push events.
- Make failures actionable with inline logs instead of forcing artifact downloads.

## Reviewer Notes
- Branch protection: keep **only `validate`** marked as "Required".
- Optional jobs remain in the workflow so history/audits still show when they ran and how long they took.
- Local quickcheck (CLS): `./tools/dispatch_quick.zsh pr:quickcheck <PR#>`.

## Usage Guide
### Opting into heavy smoke
1. Add the `run-smoke` label to the PR, **or**
2. Include `[run-smoke]` in the PR title.

### Skipping optional jobs entirely
- Include `[skip-smoke]` in the PR title for docs-only or trivial changes.

### Push builds
- Full suite (validate + optional jobs) always runs on pushes to `main` / `develop` regardless of labels.

## Local Workflow Notes
- `tools/ci/validate.sh` honors `SKIP_BOSS_API=1` when you just need the client-side quick smoke.
- `scripts/smoke_with_server.sh` already prints the last 200 lines of `boss-api.out.log` when tests fail.

## Benefits
1. **Fewer red PRs** – Only the required job must pass.
2. **Faster feedback** – Most PRs finish in ~5–8 minutes.
3. **On-demand heavy coverage** – Explicit opt-in label/title keeps signal high.
4. **Fork friendly** – External contributors avoid expensive jobs automatically.
5. **Better debugging** – Auto log tails plus the `ci-summary` job keep context in the GitHub UI.
6. **Deterministic** – Timeouts prevent hangers and fail-fast disables cascading cancels.

## Next (optional)
- Add label/title gating for additional suites if new jobs appear.
- Move the boss-api health wait fully into the script with `SKIP_BOSS_API` guard to reduce redundant waits.
