# Orchestrator Summary v2 — Feature (2025-11-16)

## Summary

Upgrade `claude_orchestrator_summary.json` to a stable **v2** JSON
schema so downstream dashboards and agents can rely on a consistent
structure.

The summary now includes:

- `version`: "v2"
- `run_id`: unique ID per orchestrator run
- `status`: "ok" | "partial" | "error"
- `generated_at`: ISO-8601 UTC timestamp
- `agent_count`: number of agents invoked
- `meta`: aggregate metrics (avg duration, etc.)
- `agents`: array of per-agent results

**No CI, security, or workflow changes.**  
This is a tooling-only update in `tools/claude_subagents/orchestrator.zsh`.

## Files

- `tools/claude_subagents/orchestrator.zsh`
  - Adds:

    - `ORCH_SUMMARY_DIR`, `ORCH_SUMMARY_PATH`
    - `orch_write_summary_json(run_id, status, agent_count, agents_json, meta_json)`
    - `orch_build_agents_json(...)` — formats per-agent results as a JSON array.
    - `orch_compute_overall_status(...)` — derives an overall status.
    - `orch_build_meta_json(...)` — builds a small meta object (avg duration, etc.).
    - Final call at the end of the main run that writes the summary JSON.

- `g/reports/system/orchestrator_summary_v2_feature_20251116.md`
  - This document.

## Behavior

- After each orchestrator run, a file is written:

  - Path (default):
    - `g/reports/system/claude_orchestrator_summary.json`
  - Example structure:

```json
{
  "version": "v2",
  "run_id": "orch-20251116T01:23:45Z",
  "status": "ok",
  "generated_at": "2025-11-16T01:23:45Z",
  "agent_count": 2,
  "meta": {
    "avg_agent_duration_ms": 1234,
    "agent_result_counts": {
      "ok": 0,
      "partial": 0,
      "error": 0
    }
  },
  "agents": [
    {
      "name": "mary",
      "status": "ok",
      "duration_ms": 900
    },
    {
      "name": "lisa",
      "status": "ok",
      "duration_ms": 1560
    }
  ]
}
```

  - Writes via *.tmp then mv for safer updates.
  - If agent arrays are empty, we still produce a valid JSON object with
    `agents: []`.

## Risk

- No changes to:
  - `apps/dashboard/*`
  - `server/security/*`
  - `apps/dashboard/wo_dashboard_server.js`
  - CI workflows, LaunchAgents, or scripts used by GitHub Actions.
  - Redis/WO state files.
- The file path (`claude_orchestrator_summary.json`) remains the same;
  only the JSON shape becomes richer and more consistent.

Risk level: Low.
