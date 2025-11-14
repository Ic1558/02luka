# Feature SPEC: Claude Code Best Practices - Governance Integration

**Feature ID:** `claude_code_governance_integration`  
**Version:** 1.0.0  
**Date:** 2025-11-12  
**Status:** Ready for Implementation

---

## Objective

Integrate Claude Code Best Practices system with Phase 5 Governance & Reporting, ensuring unified metrics collection, health monitoring, alerting, and compliance reporting across all 02LUKA agents including Claude Code workflows.

---

## Problem Statement

Claude Code Best Practices system exists but is not integrated with:
- Phase 5 Governance metrics collection
- Redis hub for real-time state visibility
- Unified health monitoring
- Automated alerting system
- Governance reporting

**Impact:**
- Claude Code metrics isolated from system-wide reporting
- No unified health score including Claude Code
- Missing alerts for Claude Code hook failures
- Governance reports don't include Claude Code compliance
- No certificate validation for Claude Code components

---

## Solution Overview

Integrate Claude Code into Phase 5 Governance by:
1. **Redis Integration:** Push Claude Code metrics to `memory:agents:claude`
2. **Metrics Collector:** Include Claude Code metrics in monthly aggregation
3. **Health Check:** Merge Claude Code health into unified system score
4. **Alert Integration:** Send alerts when Claude Code health degrades
5. **Governance Report:** Add Claude Code compliance section
6. **Certificate Validation:** Include Claude Code components in validation

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│ Claude Code → Phase 5 Governance Integration            │
├─────────────────────────────────────────────────────────┤
│                                                           │
│  ┌──────────────┐         ┌──────────────┐             │
│  │ Claude Code  │ ──────→ │ Redis Hub    │             │
│  │ Metrics      │         │ (memory:     │             │
│  │ Collector    │         │  agents:     │             │
│  └──────┬───────┘         │  claude)     │             │
│         │                 └──────┬───────┘             │
│         │                        │                      │
│         │                        ▼                      │
│         │              ┌──────────────┐                │
│         │              │ Phase 5       │                │
│         │              │ Metrics       │                │
│         │              │ Collector     │                │
│         │              └──────┬───────┘                │
│         │                     │                         │
│         ▼                     ▼                         │
│  ┌──────────────┐    ┌──────────────┐                  │
│  │ Health Check │    │ Governance   │                  │
│  │ (Unified)    │    │ Report       │                  │
│  └──────────────┘    └──────────────┘                  │
│                                                           │
└─────────────────────────────────────────────────────────┘
```

---

## Components

### 1. Claude Code Metrics → Redis Integration

**Purpose:** Push Claude Code metrics to Redis hub for real-time visibility

**Source:** `tools/claude_tools/metrics_collector.zsh`

**Integration Points:**
- Hook success/failure counts
- Subagent conflict rates
- Code review metrics
- Deployment success rates
- Quality gate pass rates

**Redis Structure:**
```
HSET memory:agents:claude status active
HSET memory:agents:claude hook_success_rate 95.5
HSET memory:agents:claude subagent_conflicts 2
HSET memory:agents:claude last_update "2025-11-12T08:00:00Z"
```

**Implementation:**
- Modify `tools/claude_tools/metrics_collector.zsh` to write to Redis
- Publish updates to `memory:updates` channel
- Update `shared_memory/context.json`

### 2. Metrics Collector Integration

**Purpose:** Include Claude Code metrics in Phase 5 monthly aggregation

**Source:** `tools/memory_metrics_collector.zsh`

**Claude Code Metrics:**
- Hook execution counts (success/failure)
- Subagent conflict rate
- Code review completion rate
- Deployment success rate
- Quality gate pass rate
- Average review time
- Average deployment time

**Output:**
- Added to `g/reports/memory_metrics_YYYYMM.json` under `agents.claude`
- Included in monthly metrics Markdown report

### 3. Unified Health Check Integration

**Purpose:** Merge Claude Code health into system-wide health score

**Source:** `tools/memory_hub_health.zsh`

**Claude Code Health Checks:**
- All hooks executable
- Metrics collector running
- Subagent conflicts < 10%
- Hook failure rate < 20%
- Dependencies installed (shellcheck, pylint, jq)

**Health Score Calculation:**
```
System Health = (Hub Health + Redis Health + Claude Health + ...) / Total Components
```

**Implementation:**
- Add Claude Code section to `memory_hub_health.zsh`
- Calculate Claude Code health score (0-100)
- Include in overall system health

### 4. Alert Integration

**Purpose:** Send alerts when Claude Code health degrades

**Source:** `tools/governance_alert_hook.zsh`

**Alert Triggers:**
- Hook failure rate > 20%
- Subagent conflict rate > 10%
- Metrics collector not running > 1 hour
- Dependencies missing
- Health score < 80%

**Alert Format:**
```
[GOVERNANCE] Alert: Claude Code Health Degraded
Component: claude_code
Issue: Hook failure rate 25% (threshold: 20%)
Health Score: 75%
Action: Review hook logs, check dependencies
```

**Implementation:**
- Add Claude Code checks to `governance_alert_hook.zsh`
- Use same Telegram integration
- Deduplication logic

### 5. Governance Report Integration

**Purpose:** Include Claude Code compliance in weekly governance report

**Source:** `tools/governance_report_generator.zsh`

**Claude Code Section:**
- Hook execution statistics
- Code review metrics
- Deployment success rates
- Quality gate compliance
- Subagent coordination effectiveness
- Compliance score

**Report Structure:**
```markdown
## Claude Code Compliance

### Hook Execution
- Success Rate: 95.5%
- Total Executions: 1,234
- Failures: 56

### Code Review
- Reviews Completed: 89
- Average Review Time: 12.3 minutes
- Subagent Conflicts: 2 (2.2%)

### Deployment
- Success Rate: 98.1%
- Average Deployment Time: 5.2 minutes

### Compliance Score: 94/100
```

### 6. Certificate Validation Integration

**Purpose:** Validate Claude Code components in certificate validation

**Source:** `tools/certificate_validator.zsh`

**Claude Code Components to Validate:**
- `.claude/settings.json` exists
- All hooks executable (`pre_commit.zsh`, `quality_gate.zsh`, `verify_deployment.zsh`)
- Metrics collector script exists
- Dashboard accessible
- Dependencies installed

**Validation Rules:**
- All required files exist
- All scripts executable
- Dependencies available
- Health checks passing

### 7. Dependency Management

**Purpose:** Verify and install Claude Code dependencies

**Source:** `tools/claude_hooks/setup_dependencies.zsh`

**Dependencies:**
- `shellcheck` (shell script linting)
- `pylint` (Python linting)
- `jq` (JSON processing)
- `gh` (GitHub CLI)
- `git` (version control)

**Implementation:**
- Check for each dependency
- Install if missing (via Homebrew or pip)
- Verify installation
- Report status

---

## Data Flow

### Daily Metrics Collection
```
Claude Code Metrics Collector
    ↓
Redis (memory:agents:claude)
    ↓
Phase 5 Metrics Collector (daily)
    ↓
Monthly Metrics JSON/MD
    ↓
Governance Report (weekly)
```

### Health Check Flow
```
Claude Code Health Checks
    ↓
Unified Health Check
    ↓
System Health Score
    ↓
Alert if < 80%
```

### Alert Flow
```
Claude Code Health Degradation
    ↓
Governance Alert Hook
    ↓
Telegram Notification
    ↓
Deduplication
```

---

## Configuration

### Environment Variables
- `CLAUDE_CODE_HEALTH_THRESHOLD`: Default 80
- `CLAUDE_CODE_HOOK_FAILURE_THRESHOLD`: Default 20%
- `CLAUDE_CODE_SUBAGENT_CONFLICT_THRESHOLD`: Default 10%
- `CLAUDE_CODE_METRICS_RETENTION_DAYS`: Default 365

### File Locations
- Metrics: `g/reports/memory_metrics_YYYYMM.json` (includes `agents.claude`)
- Health Check: `tools/memory_hub_health.zsh` (includes Claude Code section)
- Dependencies: `tools/claude_hooks/setup_dependencies.zsh`
- Certificate Validation: Includes Claude Code components

---

## Success Criteria

✅ **Functional:**
- Claude Code metrics pushed to Redis daily
- Metrics included in monthly aggregation
- Health check includes Claude Code
- Alerts sent when health degrades
- Governance report includes Claude Code section
- Certificate validation includes Claude Code

✅ **Operational:**
- All integrations working
- Metrics accurate
- Alerts timely
- Reports complete

✅ **Quality:**
- Unified health score accurate
- Compliance reporting clear
- Dependencies managed
- Security checks comprehensive

---

## Safety & Guardrails

### Metrics Retention
- Keep 12 months of Claude Code metrics
- Align with Phase 5 retention policy
- Automatic cleanup of old data

### Alert Deduplication
- Same alert not sent twice within 1 hour
- Critical alerts escalate every 4 hours
- Alert state stored in `logs/governance_alerts.state`

### Dependency Management
- Verify dependencies before hooks run
- Install missing dependencies automatically
- Report dependency status in health check

### Security
- Pattern scanning for credentials (regex)
- SSH key detection
- Token pattern matching
- Link with Phase 5 certificate validation

---

## Future Enhancements

1. **Advanced Analytics:**
   - Trend analysis for Claude Code metrics
   - Predictive alerts
   - Anomaly detection

2. **Dashboard Integration:**
   - Real-time Claude Code metrics in dashboard
   - Pull from Redis for live updates

3. **Compliance:**
   - Regulatory reporting
   - Audit trail export
   - Compliance scoring

---

## References

- **Phase 5 SPEC:** `g/reports/feature_phase5_governance_reporting_SPEC.md`
- **Claude Code Best Practices:** Previous implementation plan
- **Phase 4 SPEC:** `g/reports/feature_shared_memory_phase4_redis_hub_SPEC.md`
- **Health Check:** `tools/memory_hub_health.zsh`
