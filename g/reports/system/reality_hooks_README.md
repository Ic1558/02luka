# Reality Hooks

Reality hooks are **lightweight real-world checks** that run on every important PR
to prove that key parts of the system still behave correctly, not just compile.

## What this does

The `tools/reality_hooks/pr_reality_check.zsh` script currently runs:

1. **Dashboard smoke**
   - Verifies that `apps/dashboard/wo_dashboard_server.js` parses with Node.
   - Best-effort only; marks `skipped` if the file is missing.

2. **Orchestrator summary**
   - Runs `tools/claude_subagents/orchestrator.zsh --summary`.
   - Checks that `g/reports/system/claude_orchestrator_summary.json` is created
     and contains valid JSON.

3. **Telemetry schema vs sample**
   - Loads `g/schemas/telemetry_v2.schema.json` and the first record from
     `g/telemetry_unified/unified.jsonl`.
   - Fails only if required keys from the schema are missing in the sample.

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

This can be consumed by scoring agents (e.g. pr_score) to set
reality_hooks > 0 for PRs that successfully run these checks.

## Running locally

From the repo root:

```
chmod +x tools/reality_hooks/pr_reality_check.zsh
tools/reality_hooks/pr_reality_check.zsh
```

If all hooks pass, the script exits 0 and writes a report.

If any hook fails, it exits non-zero and logs details to stdout.
