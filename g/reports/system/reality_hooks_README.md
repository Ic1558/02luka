# Reality Hooks

Reality hooks are **lightweight real-world checks** that run on every important PR to prove that key parts of the system still behave correctly, not just compile.

## What this does

The `tools/reality_hooks/pr_reality_check.zsh` script currently runs:

1. **Dashboard smoke**
   - Verifies that `g/apps/dashboard/dashboard_data.json` exists and has sane roadmap + service data.
   - Ensures `roadmap.overall_progress_pct` and `services.total` are valid numbers.

2. **Orchestrator summary**
   - Runs `tools/subagents/orchestrator.zsh compete "echo reality_hook_success" 1` with `LUKA_SOT` pointed at the repo.
   - Checks that `g/reports/system/subagent_orchestrator_summary.json` or `claude_orchestrator_summary.json` is created and contains valid JSON with `agents` array and `winner` field.

3. **Telemetry schema vs sample**
   - Loads `schemas/telemetry_v2.schema.json` and validates `telemetry/sample_telemetry_v2.json` against it using `ajv`.
   - Supports both JSON and JSONL formats.

Each run writes a Markdown report under:

- `g/reports/system/reality_hooks_pr_<sha>.md`

and prints a machine-readable summary:

```text
REALITY_HOOKS_SUMMARY_START
dashboard_smoke=ok|failed|skipped
orchestrator_smoke=ok|failed|skipped
telemetry_schema=ok|failed|skipped
REALITY_HOOKS_SUMMARY_END
```

This can be consumed by scoring agents (e.g. pr_score) to set `reality_hooks > 0` for PRs that successfully run these checks.

## Running locally

From the repo root:

```bash
npm install   # only required once for Ajv
chmod +x tools/reality_hooks/pr_reality_check.zsh
tools/reality_hooks/pr_reality_check.zsh
```

If all hooks pass, the script exits 0 and writes a report.

If any hook fails, it exits non-zero and logs details to stdout.

## CI integration

`.github/workflows/reality_hooks.yml` runs the script on every pull request targeting `main` or `release/*`. The workflow uploads the generated Markdown report as an artifact so governance tooling (e.g., PR scoring agents) can detect that `reality_hooks > 0` for the PR.
