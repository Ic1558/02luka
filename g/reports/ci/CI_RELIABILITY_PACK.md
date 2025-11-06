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
