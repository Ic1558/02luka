# Phase 19 — CI Hygiene & Health Snapshot

## What

- **.gitignore** updates: ignore logs/tmp/artifacts to keep the repo clean.

- **tools/ci/health_snapshot.sh**: quick CI overview for open PRs.

  - Requires `gh` CLI (local/dev convenience)

  - Writes reports to `g/reports/ci/health_*.md`

## Why

- Reduce accidental noisy commits (logs/tmp).

- One command to see PR + checks status (for triage).

## Usage

```bash
tools/ci/health_snapshot.sh           # default (20 PRs)
tools/ci/health_snapshot.sh 50        # increase limit
```
