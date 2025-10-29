# CLS Governance Workflow Manual

## Purpose
The CLS governance workflow keeps the local automation stack safe, observable, and aligned with human oversight. It formalizes how the CLS agent, supporting launch agents, and human reviewers coordinate so that high-risk automations require approval while routine maintenance continues autonomously.

## Scope
- **Environment**: macOS host with CLS LaunchAgents, Docker Compose services, and `CLS_FS_ALLOW` providing access to `~/02luka`, `/Volumes/lukadata`, and `/Volumes/hd2`.
- **Automation Surfaces**: CLS task queue (`queue/inbox/*.json`), maintenance services in `g/tools/services/`, and scheduled LaunchAgents under `Library/LaunchAgents/`.
- **Reporting**: Operational artifacts live in `g/reports/` with telemetry in `g/logs/` and `g/telemetry/`.

## Governance Roles
| Role | Primary Responsibilities | Escalation Targets |
|------|--------------------------|--------------------|
| **CLS Agent** | Execute queued workflows, produce daily reports, and honor guardrails defined in `docs/SECURITY_GOVERNANCE.md`. | Escalates to GG (Guardian) when policy checks fail or unknown scopes detected. |
| **Guardian (GG)** | Reviews high-risk intents surfaced through CLS, validates automation plans, and approves `requiresApproval` events. | Escalates to Operations Orchestrator for production-impacting changes. |
| **Operations Orchestrator** | Maintains LaunchAgents, secrets, and Ops Atomic gating; ensures incident hand-off and audits `g/reports/` outputs. | Escalates to incident commander / human on-call. |
| **Workflow Automation Specialist** | Authors and validates CLS-compatible scripts, keeps queue definitions updated, and verifies telemetry. | Escalates to Guardian when automation drifts from policy. |

## Core Automation Components
| Component | Location | Purpose |
|-----------|----------|---------|
| `g/tools/services/autoheal_daemon.cjs` | Node service invoked by CLS to restart failing processes and write to `g/telemetry/autoheal.log`. |
| `scripts/cls_daily_monitoring.sh` | Shell runbook that generates `g/reports/CLS_DAILY_MONITORING_*.md` and tails recent logs for review. |
| `scripts/cls_dev_bootcheck.sh` | Startup diagnostic confirming `CLS_SHELL`, `CLS_FS_ALLOW`, executable paths, and queue connectivity. |
| `scripts/cls_final_cutover.sh` | Full production takeover sequence that publishes `g/reports/CLS_CUTOVER_REPORT_*.md`. |
| `Library/LaunchAgents/com.02luka.cls.workflow.plist` | Schedules the CLS workflow scan with environment variables and log paths for audit. |
| `Library/LaunchAgents/com.02luka.cls.verification.plist` | Verification LaunchAgent ensuring CLS validation jobs remain healthy. |
| `g/tools/services/ops_digest.cjs` | Aggregates alerts, auto-heal, and maintenance activity for governance dashboards. |

## Daily Governance Cycle
1. **07:45 ICT – Pre-flight**
   - `scripts/cls_dev_bootcheck.sh` confirms environment health.
   - Guardian reviews overnight alerts in `g/logs/ops_alerts.log`.
2. **09:00 ICT – Scheduled Run**
   - `Library/LaunchAgents/com.02luka.cls.workflow.plist` invokes the workflow scan (`scripts/codex_workflow_assistant.sh --scan`).
   - Any tasks dropped in `queue/inbox/` are validated against `CLS_FS_ALLOW` and executed.
3. **09:15 ICT – Report Publishing**
   - `scripts/cls_daily_monitoring.sh` consolidates telemetry and writes `g/reports/CLS_DAILY_MONITORING_<date>.md`.
   - Summary metrics appended to `g/telemetry/rollup_daily.ndjson`.
4. **15:00 ICT – Midday Audit (optional)**
   - Guardian runs `scripts/cls_quick_test.sh` to spot-check memory access and automation responses.
5. **21:00 ICT – Evening Run**
   - LaunchAgent triggers again for end-of-day queue flush; alerts forwarded through `g/tools/services/ops_autoheal.cjs`.
6. **21:30 ICT – Handoff**
   - CLS posts digest via `g/tools/services/daily_digest.cjs`; Guardian verifies digest references valid artifacts in `g/reports/`.

## Change Control
- **Queue Updates**: New automation intents land in `queue/inbox/*.json`. Every file must specify `paths` constrained to directories allowed by `CLS_FS_ALLOW`.
- **Script Promotion**: Draft scripts live under `g/tools/services/` or `agents/local/`. Promotion to production requires Guardian approval plus a record in `g/reports/` noting change context.
- **LaunchAgent Adjustments**: Modifying `Library/LaunchAgents/*.plist` requires running `launchctl unload/load` and documenting the change in `g/reports/CLS_GOVERNANCE_MANUAL.md` changelog (see below).

## Monitoring & Alerts
- **Auto-Heal Events**: `g/logs/ops_autoheal.log` and telemetry metric `autoheal_events` track restarts. Trigger manual review after >3 restarts/hour.
- **Alerts Pipeline**: `g/logs/ops_alerts.log` plus JSON alerts in `g/state/alerts/` integrate with Ops Atomic for paging.
- **Verification**: `scripts/cls_quick_test.sh` and `g/tools/services/ops_audit_viewer.cjs` validate policy coverage and audit trails.
- **CI Enforcement**: `cls_dev_bootcheck.sh` is invoked in CI smoke passes to ensure governance configuration remains intact.

## Incident Response
1. **Detect**: Auto-heal failure or unauthorized path access triggers `requiresApproval` responses logged in `g/reports/` and surfaced to Guardian.
2. **Triage**: Guardian inspects latest `CLS_DAILY_MONITORING` report and relevant logs. For filesystem breaches, inspect `CLS_FS_ALLOW` history in `cls_dev_bootcheck.sh` output.
3. **Mitigate**: Immediately unload the CLS LaunchAgent to halt queued automations:
   - `launchctl bootout "gui/$UID" ~/Library/LaunchAgents/com.02luka.cls.workflow.plist`
   - If already running, stop any active workflow shell by sending `CTRL+C` or `pkill -f codex_workflow_assistant.sh`.
   - Document any manual overrides taken (e.g., disabling queue files in `queue/inbox/`).
4. **Document**: Record outcome in a new `g/reports/CLS_INCIDENT_<timestamp>.md`, referencing impacted queue files and mitigations.
5. **Review**: Operations Orchestrator updates this manual and `docs/SECURITY_GOVERNANCE.md` if new controls are required.

## Reporting Artifacts
| Artifact | Description | Frequency |
|----------|-------------|-----------|
| `g/reports/CLS_DAILY_MONITORING_<date>.md` | Daily run summary, queue status, auto-heal counts. | Twice daily (09:15 / 21:30 ICT). |
| `g/reports/CLS_CUTOVER_REPORT_<timestamp>.md` | Production readiness review after major changes. | As needed. |
| `g/reports/CLS_GOVERNANCE_MANUAL.md` | Living governance manual (this file). | Update on every control change. |
| `g/telemetry/rollup_daily.ndjson` | Metric rollups for dashboards. | Every digest run. |

## Changelog
- **2025-10-29** – Manual bootstrap: documented governance roles, daily schedule, monitoring, and incident response flow.
