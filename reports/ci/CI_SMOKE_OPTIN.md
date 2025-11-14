# CI Smoke Opt-In (label/title gating)

## What changed

- Heavy jobs (smoke/probe/rnd) now run **only when opted-in**:
  - PR title contains `[run-smoke]`, or
  - PR has label `run-smoke`.

- Default PRs remain quiet; only `validate` is required.

## How to run smoke

- Add label `run-smoke` **or** put `[run-smoke]` in the PR title.

- Remove the label or the tag to skip on subsequent pushes.

## Expression used

`${{ github.event_name != 'pull_request' || contains(github.event.pull_request.title, '[run-smoke]') || contains(join(github.event.pull_request.labels.*.name, ','), 'run-smoke') }}`

## Jobs affected

All jobs except `validate` and `summary` now require opt-in for PRs.
