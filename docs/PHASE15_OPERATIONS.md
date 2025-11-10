# Phase 15 Operations Guide

**Scope:** Autonomous Knowledge Router (AKR), Vector Search (FAISS/RAG), Health Monitoring, and Operational Gates.

## Quick Commands

### Health Checks
- **Daily health run**: Automatic at 08:15 ICT via `phase15-quick-health.yml`
- **Manual trigger**: `gh workflow run phase15-quick-health.yml`
- **Check MCP health**: View `hub/mcp_health.json`
- **Check agent heartbeat**: View `hub/agent_heartbeat.json`

### Rerun Workflows
- **GitHub UI**: Actions tab → Select workflow → "Re-run jobs"
- **CLI rerun**: `gh run rerun <run-id>`
- **Dispatch tool**: `./tools/dispatch_quick.zsh` (if available for Phase15)
- **Force retrigger**: Empty commit on branch
  ```bash
  git commit --allow-empty -m "chore(ci): retrigger Phase15" && git push
  ```

### Maintenance Mode
- **Enable maintenance**: Set `MAINTENANCE_MODE=1` in repository variables
- **Disable maintenance**: Set `MAINTENANCE_MODE=0`
- **Check status**: Workflows log "Maintenance mode enabled" and exit gracefully

## Maintenance Guard Policy

Phase15 uses a three-tier guard system:

### 1. MAINTENANCE_MODE (v2.0)
- **Type**: Binary flag (0 or 1)
- **Effect**: When `1`, all Phase15 workflows exit gracefully without running
- **Use case**: System-wide freeze for emergency maintenance or debugging
- **Checked by**: All operational workflows at startup

### 2. PHASE15_STRICT
- **Type**: Boolean control
- **Effect**: When enabled, health check failures cause workflow to fail (strict mode)
- **Default**: Soft failures (warnings only)
- **Use case**: Enforce SLO compliance during critical periods

### 3. CI_STRICT (Soft-Green Gate)
- **Type**: Binary flag (0 or 1)
- **Effect**: When `0`, expensive/optional jobs are skipped
- **Purpose**: Prevent resource exhaustion, enable "green by default" CI
- **Pattern**: Optional jobs check `if: vars.CI_STRICT == '1'`

## Strict Gating Mechanisms

### Soft-Green Gate
- **Trigger**: `CI_STRICT != 1`
- **Behavior**: Heavy jobs (expensive tests, long-running checks) are skipped
- **Benefit**: Fast feedback loop; opt-in for comprehensive validation

### Confidence Threshold Gating
- **Threshold**: Router requires ≥0.75 confidence for autonomous routing
- **Below threshold**: Query delegated to Kim (fallback agent)
- **Purpose**: Prevent low-confidence misrouting

### Delegation Hop Limits
- **Max hops**: 3
- **Purpose**: Prevent circular delegation loops between agents
- **Enforcement**: `delegation-watchdog.yml` monitors and alerts

### Branch Protection Validation
- **Enforcer**: `protection-enforcer.yml`
- **Validates**: Required checks are configured on protected branches
- **Runs**: On push to main/master and on schedule

## Rerun Mechanisms

### Manual Triggers
1. **GitHub UI**: Actions → Workflow → "Re-run all jobs" or "Re-run failed jobs"
2. **GitHub CLI**: `gh run rerun <run-id>` or `gh run rerun <run-id> --failed`
3. **Dispatch script**: `./tools/dispatch_quick.zsh ci:rerun <PR#>` (if extended to Phase15)

### Automatic Retries
- **auto-index.yml**: 3-attempt push retry with `git pull --rebase` between attempts
- **Pattern**: Exponential backoff for network operations (2s, 4s, 8s, 16s)

### Scheduled Reruns
- **phase15-quick-health**: Daily at 08:15 ICT
- **mcp-health**: Every 10 minutes
- **agent-heartbeat**: Every 5 minutes
- **system-telemetry-v2**: Every 5 minutes (aggregates health snapshots)

### Dispatch Triggers with Parameters
Workflows supporting `workflow_dispatch`:
- `ops-status.yml`
- `ops-mirror.yml`
- `agent-heartbeat.yml`

Use `gh workflow run <workflow>.yml` with optional inputs.

## Artifact Locations

### Phase15 Reports
- **Path**: `g/reports/phase15/`
- **Contents**:
  - FAISS/RAG test reports
  - Router test results
  - `PHASE_15_RAG_FAISS_PROD.md` (vector search spec)
  - `PHASE_15_ROUTER_CORE.md` (router implementation summary)

### Health Snapshots
- **Path**: `hub/`
- **Files**:
  - `mcp_health.json` (MCP server status)
  - `agent_heartbeat.json` (agent availability)
  - `delegation_watchdog.json` (delegation metrics)

### Unified Telemetry
- **Path**: `g/telemetry_unified/unified.jsonl`
- **Schema**: Phase 14.2 unified telemetry format
- **Aggregator**: `system-telemetry-v2.yml`

### Workflow Artifacts
- **Retention**: 7 days (default)
- **Upload**: `actions/upload-artifact@v4`
- **Policy**: `if-no-files-found: warn`
- **Guarantee**: Phase15 workflows produce artifacts even on error

## Phase15 Quick-Health SLO

### Primary Metrics

| Metric | Target | Measured By |
|--------|--------|-------------|
| **Routing Accuracy** | ≥95% | `rag-vector-selftest.yml`, `router-selftest.yml` |
| **Routing Latency** | <100ms | Router query execution time |
| **Vector Search Latency** | <500ms (uncached), <20ms (cached) | FAISS query benchmarks |
| **Delegation Success** | ≥90% | `delegation-watchdog.yml` |
| **Telemetry Coverage** | 100% | All workflows emit telemetry |

### Health Check Frequency

| Check | Frequency | Workflow | Alert Channel |
|-------|-----------|----------|---------------|
| **Phase15 Quick Health** | Daily 08:15 ICT | `phase15-quick-health.yml` | GitHub Actions |
| **MCP Health** | Every 10 min | `mcp-health.yml` | `hub/mcp_health.json` |
| **Agent Heartbeat** | Every 5 min | `agent-heartbeat.yml` | Telegram (on failure) |
| **System Telemetry** | Every 5 min | `system-telemetry-v2.yml` | Aggregated health snapshot |

### SLO Validation
- **Router self-test**: Validates confidence thresholds, delegation logic, vector search integration
- **RAG/FAISS self-test**: Benchmarks query latency, cache hit rate, index freshness
- **Pattern**: Both tests run as part of `phase15-quick-health.yml`

### Failure Response
1. **Soft failure** (default): Log warning, continue workflow, upload diagnostic artifacts
2. **Strict failure** (`PHASE15_STRICT=1`): Fail workflow, block PR merge, require manual investigation

## Integration Points

### Configuration Files
- **Router**: `config/router_akr.yaml` (thresholds, delegation rules, max_hops)
- **Agents**: `config/agents/{andy,kim}.yaml` (capabilities, permissions, telemetry)
- **Telemetry**: `config/telemetry_unified.yaml` (Phase 14.2 schema)
- **System Telemetry**: `config/telemetry_v2.yaml` (aggregation config)

### Reusable Workflows
- **RAG/Vector Self-Test**: `.github/workflows/_reusable/rag-vector-selftest.yml`
- **Router Self-Test**: `.github/workflows/_reusable/router-selftest.yml`
- **Pattern**: Reusable workflows are versioned (e.g., `@main`, `@v2`)

### Documentation
- **AKR Design**: `docs/phase15_AKR_plan.md` (997 lines, comprehensive design)
- **FAISS Integration**: `docs/phase15_faiss_kim_integration.md`
- **Vector Search Spec**: `g/reports/phase15/PHASE_15_RAG_FAISS_PROD.md`
- **Router Implementation**: `g/reports/phase15/PHASE_15_ROUTER_CORE.md`

## Troubleshooting

### Health Check Failures
1. **Check maintenance mode**: `echo $MAINTENANCE_MODE` (should be `0`)
2. **Review logs**: Actions tab → workflow run → expand failed step
3. **Check artifacts**: Download workflow artifacts for diagnostic reports
4. **Validate config**: Ensure `config/router_akr.yaml` and agent configs are valid YAML

### Router Confidence Issues
- **Low confidence (<0.75)**: Review query phrasing, check vector index freshness
- **Fallback to Kim**: Expected behavior; Kim handles ambiguous queries
- **Zero results**: Check FAISS index integrity, verify `g/knowledge/` data

### Delegation Loops
- **Symptom**: `delegation-watchdog.yml` reports hop count ≥3
- **Root cause**: Circular agent capabilities or query ambiguity
- **Fix**: Review `config/agents/*.yaml` delegation rules, adjust router thresholds

### Artifact Missing
- **Check retention**: Artifacts expire after 7 days
- **Verify upload**: Workflow logs should show "Uploading artifacts..."
- **Policy**: Phase15 guarantees artifact upload even on workflow failure

### Telemetry Gaps
- **Check aggregator**: `system-telemetry-v2.yml` should run every 5 min
- **Validate schema**: `config/telemetry_unified.yaml` defines required fields
- **Manual check**: `cat g/telemetry_unified/unified.jsonl | jq .`

---

**Last Updated**: 2025-11-10
**Owner**: Phase15 AKR Team
**Related Docs**: `docs/phase15_AKR_plan.md`, `g/reports/ci/CI_AUTOMATION_RUNBOOK.md`
