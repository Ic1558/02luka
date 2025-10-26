# CI Trigger Automation Flow

This document summarizes how the `ci_trigger.sh` helper coordinates a safe
no-op commit to kick GitHub Actions when a `*-CI-TRIGGER*.md` work order is
processed.

## Overview
1. The script lives at `tools/ci_trigger.sh` and is invoked by CLC when a
   trigger work order arrives.
2. The helper requires the presence of `g/governance/ci_trigger.ok`. This flag
   file gates the workflow to prevent accidental pushes in repositories where
   the trigger is not enabled.
3. When enabled, the script rate limits CI pokes using
   `g/governance/.ci_trigger.lock` so that multiple triggers within
   `RATE_SECONDS` (default 120 seconds) are ignored.
4. A touch is performed on `tools/test_browseros_phase77.sh` to ensure the
   subsequent commit is always a no-op for application logic.
5. The commit is authored as `ci-trigger <ci@02luka.local>` and pushed to the
   configured branch (default `main`).

## Safety Guards
- The repository owner is validated to be `Ic1558` before any push occurs.
- The script fetches and checks out the target branch to stay in sync with
  remote history before pushing.
- Rate limiting protects against runaway triggering loops.

## Configuration
- Override the target repository path via the `REPO` environment variable.
- Use the `BRANCH` variable to specify a non-default branch.
- Adjust `RATE_SECONDS` to change the minimum interval between pushes.
- Update the watched file path by setting `WATCH_FILE` if another sentinel file
  becomes preferable in future phases.

## Expected Result
Once all checks pass, the script commits a timestamped comment line to the
watched file and pushes the change, causing GitHub Actions to execute. The
script logs its progress to standard output for troubleshooting.
