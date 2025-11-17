# CI Reliability Pack

**Goal:** Make CI quiet and reliable by default, reducing red PRs and only requiring critical checks to pass.

## Summary of Changes

This CI reliability pack implements a "quiet by default" strategy where only essential validation runs on every PR, while heavier/optional tests can be triggered on-demand.

### 1. Job Classification

#### REQUIRED (must pass for PR merge):
- **validate** - Phase 4/5/6 smoke tests (local, fast, ~5-8 min)

#### OPTIONAL (continue-on-error, won't block merge):
- **ops-gate** - Phase 5/6/7 smoke tests (ops layer)
- **rag-vector-selftest** - Phase 15 RAG vector search tests
- **ci-summary** - Always-running summary job showing status of all jobs

### 2. Gating Mechanisms

Optional jobs are automatically skipped unless:
- PR has the `run-smoke` label, OR
- Running on push to main/develop branches

Optional jobs are also skipped when:
- PR title contains `[skip-smoke]`
- PR is from a forked repository (`github.event.pull_request.head.repo.fork == false`)

### 3. Reliability Features

All jobs include:
- **timeout-minutes** - Prevents jobs from hanging indefinitely
- **continue-on-error: true** - Optional jobs won't fail the PR
- **strategy: { fail-fast: false }** - Matrix jobs continue even if one fails
- **Fork protection** - Heavy jobs don't run on external forks

### 4. Script Enhancements

**tools/ci/validate.sh** now supports:
- `SKIP_BOSS_API=1` - Skip server start for faster validation in environments where the server is unavailable or unnecessary

**scripts/smoke_with_server.sh** already includes:
- Automatic printing of last 200 lines of `boss-api.out.log` on test failure for easier debugging

## Usage Guide

### For PR Authors

#### Normal PR (fast, quiet mode):
```bash
# Just open your PR - only 'validate' job runs (fast)
gh pr create --title "feat: add new feature"
```

#### Run full smoke tests on-demand:
```bash
# Add the 'run-smoke' label to trigger optional jobs
gh pr edit <PR-NUMBER> --add-label "run-smoke"
```

#### Skip even optional jobs (docs-only changes):
```bash
# Add [skip-smoke] to your PR title
gh pr create --title "docs: update README [skip-smoke]"
```

### For Maintainers

#### Re-run heavy tests manually:
1. Add the `run-smoke` label to the PR
2. Re-run the workflow from the Actions tab
3. Remove the label after verification

#### Check detailed job status:
The `ci-summary` job always runs and shows:
- Status of required job (validate)
- Status of optional jobs (ops-gate, rag-vector-selftest)
- Clear indication of which jobs can fail without blocking

### For Local Development

#### Skip server start in validation:
```bash
# Useful when boss-api is unavailable or for faster iteration
SKIP_BOSS_API=1 bash tools/ci/validate.sh
```

#### Run full validation with server:
```bash
# Default behavior - starts server and runs tests
bash tools/ci/validate.sh
```

## CI Workflow Structure

```
┌─────────────────────────────────────────────────────┐
│ validate [REQUIRED]                                  │
│ - Phase 4/5/6 smoke tests                           │
│ - Must pass for PR to be green                     │
│ - Runs on all PRs                                   │
│ - Timeout: 8 minutes                                │
└─────────────────────────────────────────────────────┘
                     │
                     ├─────────────────────────────────┐
                     ▼                                 ▼
┌─────────────────────────────────┐  ┌──────────────────────────────────┐
│ ops-gate [OPTIONAL]              │  │ rag-vector-selftest [OPTIONAL]   │
│ - Phase 5/6/7 smoke tests       │  │ - Phase 15 RAG vector tests      │
│ - continue-on-error: true       │  │ - continue-on-error: true        │
│ - Skipped on forks              │  │ - Skipped on forks               │
│ - Skipped unless 'run-smoke'    │  │ - Skipped unless 'run-smoke'     │
│ - Skipped if [skip-smoke]       │  │ - Skipped if [skip-smoke]        │
│ - Timeout: 8 minutes            │  │ - Timeout: 15 minutes            │
└─────────────────────────────────┘  └──────────────────────────────────┘
                     │                                 │
                     └─────────────┬───────────────────┘
                                   ▼
                  ┌────────────────────────────────────┐
                  │ ci-summary                          │
                  │ - if: always()                      │
                  │ - Shows status of all jobs         │
                  │ - Fails only if validate failed    │
                  │ - Timeout: 2 minutes               │
                  └────────────────────────────────────┘
```

## Benefits

1. **Fewer Red PRs** - Only critical validation must pass
2. **Faster Feedback** - Most PRs run only 1 fast job (~5-8 min)
3. **On-Demand Testing** - Heavy tests available via `run-smoke` label
4. **Fork Friendly** - External contributors don't trigger expensive jobs
5. **Better Debugging** - Auto-print logs on failure, summary job shows all statuses
6. **Reliable** - Timeouts prevent hanging, continue-on-error prevents flaky test blocking

## Migration Notes

### Before (all jobs required):
- All 3 jobs must pass for PR to be green
- Any flaky job blocks the PR
- Forks run expensive tests unnecessarily
- PRs often show as red even when core validation passes

### After (quiet by default):
- Only 'validate' must pass for PR to be green
- Optional jobs can fail without blocking
- Forks skip expensive tests
- PRs are green as long as core validation passes
- Heavy tests run on-demand via 'run-smoke' label

## Troubleshooting

### "Why is my PR green but some jobs show as skipped?"
Optional jobs are skipped by default. Add the `run-smoke` label if you need them to run.

### "I want to run all tests on my PR"
Add the `run-smoke` label to your PR using:
```bash
gh pr edit <PR-NUMBER> --add-label "run-smoke"
```

### "The validate job failed but I need more debugging info"
Check the job logs - `smoke_with_server.sh` automatically prints the last 200 lines of boss-api logs on failure.

### "I don't want any smoke tests on my docs-only PR"
Add `[skip-smoke]` to your PR title:
```bash
gh pr edit <PR-NUMBER> --title "docs: update README [skip-smoke]"
```

### "How do I test locally without starting the server?"
Use the `SKIP_BOSS_API` environment variable:
```bash
SKIP_BOSS_API=1 bash tools/ci/validate.sh
```

## Future Enhancements

Potential improvements for future iterations:
- Path-based gating (e.g., skip all tests if only `.md` files changed)
- Scheduled nightly runs of all optional jobs
- Matrix testing for multiple Node/Python versions
- Performance benchmarking jobs
- Security scanning jobs (SAST, dependency checks)
