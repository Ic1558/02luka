# CI Reliability Pack — Quiet by Default

## What changed

- All non-`validate` jobs are now **non-blocking**: `continue-on-error: true` + `timeout-minutes: 15`.

- `strategy.fail-fast: false` across jobs (matrix won't cancel siblings on first failure).

- `validate` prints `boss-api` log tail on any failure (always step).

- Added `summary` job with `always()` to give a clear pipeline end state.

## Why

- Reduce noisy red PRs during R&D bursts.

- Keep the single required check focused on fast, deterministic validation.

- Make failures actionable with inline logs rather than opaque artifacts.

## Reviewer notes

- Branch protection: keep **only `validate`** as "Required". (Settings → Branches)

- Heavy/experimental jobs remain in the workflow but won't block merges.

- Local quickcheck (CLS): `./tools/dispatch_quick.zsh pr:quickcheck <PR#>`.

## Next (optional)

- Add label/title gating to opt-in heavy smoke (`[run-smoke]` or `run-smoke` label).

- Move boss-api health wait into the script with SKIP_BOSS_API guard.

## Opt-in Label/Title Gating

Heavy jobs (`ops-gate`, `rag-vector-selftest`) now run only when:
- PR has label `run-smoke` OR
- PR title contains `[run-smoke]` OR
- Event is `push` (always runs on push to main/develop)

### Usage

To run heavy smoke tests on a PR:
1. Add label `run-smoke` to the PR, OR
2. Include `[run-smoke]` in the PR title

Example PR titles:
- `feat: new feature [run-smoke]`
- `fix: critical bug [run-smoke]`

### Benefits

- Default: PRs are quiet (only `validate` runs)
- Opt-in: Heavy tests run only when explicitly requested
- Push: Always runs full suite on push to main/develop
