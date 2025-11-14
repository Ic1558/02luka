# Feature SPEC: Phase 5 - Governance & Reporting Layer

**Feature ID:** `phase5_governance_reporting`  
**Version:** 1.0.0  
**Date:** 2025-11-12  
**Status:** Ready for Implementation

---

## Objective

Add governance, self-auditing, and automated reporting layer on top of Phase 4, providing weekly system health summaries, metrics aggregation, automated alerts, and certificate validation.

---

## Problem Statement

Phase 4 provides real-time memory sync and daily digests, but lacks:
- Aggregated metrics over time (weekly/monthly trends)
- Governance reports combining all system health indicators
- Automated alerting when system health degrades
- Certificate validation to ensure deployments remain valid
- Self-auditing capabilities for system compliance

**Impact:**
- No visibility into system trends over time
- Manual health monitoring required
- No early warning for degradation
- Deployment certificates not validated
- No compliance auditing

---

## Solution Overview

Phase 5 adds:
1. **Metrics Collector:** Aggregate Redis events every 24h → monthly metrics
2. **Governance Report:** Weekly report combining metrics + health + digest
3. **Auto-Alert Hook:** Telegram alerts when health < 80% or digest missing
4. **Certificate Validation:** Validate deployment certificates are current
5. **Self-Auditing:** Automated compliance checks

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│ Phase 5: Governance & Reporting Layer                    │
├─────────────────────────────────────────────────────────┤
│                                                           │
│  ┌──────────────┐         ┌──────────────┐             │
│  │ Metrics      │ ──────→ │ Governance   │             │
│  │ Collector    │         │ Report       │             │
│  │ (24h)        │         │ (Weekly)     │             │
│  └──────┬───────┘         └──────┬───────┘             │
│         │                        │                      │
│         │                        ▼                      │
│         │              ┌──────────────┐                │
│         │              │ Auto-Alert   │                │
│         │              │ Hook         │                │
│         │              │ (Telegram)   │                │
│         │              └──────────────┘                │
│         │                                               │
│         ▼                                               │
│  ┌──────────────┐                                      │
│  │ Certificate  │                                      │
│  │ Validator     │                                      │
│  └──────────────┘                                      │
│                                                           │
└─────────────────────────────────────────────────────────┘
```

---

## Components

### 1. Metrics Collector (`tools/memory_metrics_collector.zsh`)

**Purpose:** Aggregate events from Redis every 24h into monthly metrics

**Sources:**
- Redis keys: `memory:agents:*`
- File: `shared_memory/context.json`
- Logs: `logs/memory_hub.out.log`
- Daily digests: `g/reports/memory_digest_*.md`

**Metrics Collected:**
- Agent activity counts (Mary tasks, R&D proposals)
- Health scores over time
- Redis connectivity uptime
- Pub/sub event counts
- Error rates
- Response times

**Output:**
- `g/reports/memory_metrics_YYYYMM.json` (monthly aggregation)
- `g/reports/memory_metrics_YYYYMM.md` (human-readable)

**Schedule:**
- LaunchAgent: `com.02luka.memory.metrics.collector` (daily at 23:55)

### 2. Governance Report Generator (`tools/governance_report_generator.zsh`)

**Purpose:** Generate weekly governance report combining all metrics

**Sources:**
- Monthly metrics: `g/reports/memory_metrics_*.json`
- Health checks: `tools/memory_hub_health.zsh` output
- Daily digests: `g/reports/memory_digest_*.md`
- Deployment certificates: `g/reports/DEPLOYMENT_CERTIFICATE_*.md`

**Report Sections:**
1. **Executive Summary**
   - Overall health score
   - Key metrics trends
   - Critical issues

2. **System Health**
   - Health check history
   - Component status
   - Uptime statistics

3. **Activity Metrics**
   - Mary task completion rate
   - R&D proposal processing rate
   - Agent coordination effectiveness

4. **Compliance**
   - Certificate validation status
   - Deployment history
   - Audit trail

5. **Recommendations**
   - Action items
   - Optimization opportunities
   - Risk mitigation

**Output:**
- `g/reports/system_governance_WEEKLY_YYYYMMDD.md`

**Schedule:**
- LaunchAgent: `com.02luka.governance.report.weekly` (Sunday 08:00)

### 3. Auto-Alert Hook (`tools/governance_alert_hook.zsh`)

**Purpose:** Send Telegram alerts when system health degrades

**Triggers:**
- Health score < 80%
- Daily digest missing for > 24 hours
- Redis connectivity lost for > 5 minutes
- Hub LaunchAgent not running
- Certificate validation failures

**Alert Format:**
```
[GOVERNANCE] Alert: <severity>
Component: <component>
Issue: <description>
Health Score: <score>%
Action: <recommended action>
```

**Configuration:**
- Uses `GPT_ALERTS_BOT_TOKEN` and `GPT_ALERTS_CHAT_ID`
- Deduplication: Same alert not sent twice within 1 hour
- Escalation: Critical alerts repeated every 4 hours

**Schedule:**
- LaunchAgent: `com.02luka.governance.alerts` (every 15 minutes)

### 4. Certificate Validator (`tools/certificate_validator.zsh`)

**Purpose:** Validate deployment certificates are current and valid

**Checks:**
- Certificate exists and is readable
- Certificate timestamp within last 30 days
- Certificate contains required sections
- Referenced components still exist
- Health checks from certificate still passing

**Output:**
- Validation report: `g/reports/certificate_validation_YYYYMMDD.json`
- Alert if validation fails

**Schedule:**
- LaunchAgent: `com.02luka.certificate.validator` (daily at 06:00)

### 5. Self-Auditing System (`tools/governance_self_audit.zsh`)

**Purpose:** Automated compliance and audit checks

**Audit Checks:**
- All Phase 4 components operational
- All LaunchAgents loaded
- All required scripts executable
- All required directories exist
- All required files accessible
- Redis connectivity maintained
- Health scores within acceptable range

**Output:**
- Audit report: `g/reports/governance_audit_YYYYMMDD.md`
- Compliance score (0-100)

**Schedule:**
- LaunchAgent: `com.02luka.governance.audit` (daily at 05:00)

---

## Data Flow

### Daily Metrics Collection
```
Redis events (24h)
    ↓
Metrics Collector
    ↓
Monthly metrics JSON/MD
    ↓
Governance Report (weekly)
```

### Alert Flow
```
Health Check / Certificate Validation / Audit
    ↓
Alert Hook
    ↓
Telegram Notification
    ↓
Deduplication Check
```

### Weekly Governance Report
```
Metrics (monthly) + Health (daily) + Digests (daily) + Certificates
    ↓
Governance Report Generator
    ↓
Weekly Report (Markdown)
    ↓
Archive + Alert if issues
```

---

## Configuration

### Environment Variables
- `GPT_ALERTS_BOT_TOKEN`: Telegram bot token
- `GPT_ALERTS_CHAT_ID`: Telegram chat ID
- `GOVERNANCE_HEALTH_THRESHOLD`: Default 80
- `GOVERNANCE_ALERT_DEDUP_HOURS`: Default 1
- `GOVERNANCE_CERT_VALID_DAYS`: Default 30

### File Locations
- Metrics: `g/reports/memory_metrics_YYYYMM.{json,md}`
- Governance Reports: `g/reports/system_governance_WEEKLY_YYYYMMDD.md`
- Audit Reports: `g/reports/governance_audit_YYYYMMDD.md`
- Certificate Validation: `g/reports/certificate_validation_YYYYMMDD.json`

---

## Success Criteria

✅ **Functional:**
- Metrics collector aggregates data daily
- Governance report generates weekly
- Auto-alert sends notifications
- Certificate validator checks certificates
- Self-audit runs daily

✅ **Operational:**
- All LaunchAgents loaded
- Reports generated on schedule
- Alerts working correctly
- Compliance score > 90%

✅ **Quality:**
- Reports clear and actionable
- Alerts timely and relevant
- Metrics accurate
- Validation comprehensive

---

## Safety & Guardrails

### Alert Deduplication
- Same alert not sent twice within 1 hour
- Critical alerts escalate every 4 hours
- Alert state stored in `logs/governance_alerts.state`

### Error Handling
- Metrics collection continues on partial failures
- Reports generated even with missing data
- Alerts sent even if some checks fail

### Data Retention
- Monthly metrics: Keep last 12 months
- Weekly reports: Keep last 52 weeks
- Audit reports: Keep last 90 days
- Certificate validation: Keep last 30 days

---

## Future Enhancements

1. **Advanced Analytics:**
   - Trend analysis
   - Predictive alerts
   - Anomaly detection

2. **Integration:**
   - Dashboard visualization
   - API endpoints
   - Webhook notifications

3. **Compliance:**
   - Regulatory reporting
   - Audit trail export
   - Compliance scoring

---

## References

- **Phase 4 SPEC:** `g/reports/feature_shared_memory_phase4_redis_hub_SPEC.md`
- **Phase 4 Operational Tools:** `g/reports/feature_phase4_operational_tools_SPEC.md`
- **Daily Digest:** `tools/memory_daily_digest.zsh`
- **Health Check:** `tools/memory_hub_health.zsh`
