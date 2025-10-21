# Assistant Roles & Autonomy Levels

## Core Roles

### Workflow Automation Specialist
- **Scope**: Executes repeatable workflows (report generation, data sync, approvals).
- **Capabilities**:
  - Trigger and monitor connectors (Drive, Slack, CRM, Email) with pre-approved playbooks.
  - Generate summaries of operational metrics and incident timelines.
  - Surface blockers and request human input when ambiguity exceeds confidence threshold.
- **Autonomy Level**: *Guarded* — may run pre-approved automations independently; escalates exceptions.
- **Escalation Rules**:
  - Request human review before modifying data sources classified as `restricted`.
  - Pause workflows when tool responses include `uncertain` or `ambiguous` markers.

### Knowledge Navigator
- **Scope**: Provides retrieval-augmented answers using business knowledge bases.
- **Capabilities**:
  - Perform context assembly via `packages/context` with importance/recency scoring.
  - Annotate responses with source citations and highlight missing data.
  - Maintain short-term conversation state for follow-up questions.
- **Autonomy Level**: *Assistive* — responds directly to informational requests but cannot trigger automations.
- **Escalation Rules**:
  - Escalate when the retrieved confidence score < 0.35 or when sensitive data categories (PII, financial) appear.
  - Route compliance-sensitive queries to designated human reviewers.

### Operations Orchestrator
- **Scope**: Coordinates cross-team workflows, tracks KPIs, and manages human/AI hand-offs.
- **Capabilities**:
  - Monitor latency, accuracy, cost per task, and task completion rate (TCR).
  - Suggest process improvements and create follow-up tickets in backlog systems (stubbed connectors).
  - Execute adaptive routing between automations and human operators.
- **Autonomy Level**: *Supervised* — requires human approval for actions affecting production systems.
- **Escalation Rules**:
  - Mandatory approval for deploy, rollback, or incident response actions.
  - Notify operations channel when SLA thresholds are breached.

## Collaboration & Handoff Model
1. **Discovery**: Knowledge Navigator collects requirements and context.
2. **Planning**: Operations Orchestrator drafts workflow plan and requests approvals via RBAC.
3. **Execution**: Workflow Automation Specialist runs approved steps with real-time logging.
4. **Review**: Human operator reviews audit log, provides feedback, and updates ticket status.
5. **Learning Loop**: Feedback stored through `/memory/remember` and curated in improvement backlog.

## Autonomy Controls
- **Confidence Thresholds**: Each role enforces minimum confidence for unattended execution.
- **Human-in-the-Loop Hooks**: UI feedback buttons capture `approve`, `reject`, `needs changes` events tied to session IDs.
- **Audit Trail**: All role actions logged with `actor`, `role`, `timestamp`, and `reason` metadata.
- **RBAC Alignment**: Roles map to RBAC scopes (`context:read`, `memory:write`, `automation:execute`, `ops:approve`).

## Escalation Paths
- **Primary**: Route to human owner via Slack connector (stub: logs to console until secrets configured).
- **Secondary**: Create ticket in operations backlog (stub: writes to `g/reports/assistance_todo.json`).
- **Emergency**: Trigger Ops Atomic gate to block further automations when risk severity >= `high`.
