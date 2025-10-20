# Security & Governance Framework

## Role-Based Access Control (RBAC)
| Scope | Description | Default Assignees |
|-------|-------------|-------------------|
| `context:read` | Access to context loaders, RAG sources, and search indices. | Knowledge Navigator, Workflow Automation Specialist |
| `memory:write` | Persist new memories, modify importance scores, run cleanup jobs. | Workflow Automation Specialist, Operations Orchestrator |
| `automation:execute` | Execute connectors (Drive/Slack/CRM/Email) and automation runbooks. | Workflow Automation Specialist (approved playbooks only) |
| `ops:approve` | Approve or reject high-risk operations, deployments, and rollbacks. | Human operators, Ops Atomic reviewers |

RBAC enforcement lives in the API auth middleware. Requests without matching scopes return `403` and log audit entries.

## Secrets Handling
- Secrets stored in environment variables or secret managers; never committed to git.
- `.env.example` left untouched to avoid leaking; use `direnv` or `doppler` locally.
- Ops Atomic credentials (`OPS_ATOMIC_URL`, `OPS_ATOMIC_TOKEN`) required for production CI gate.
- Connector tokens (Slack, Drive, CRM, Email) loaded from process environment and validated at startup.
- Secrets rotated quarterly or upon incident.

## Audit Trail
- Structured logs output JSON with `timestamp`, `requestId`, `actor`, `role`, `route`, `decision`.
- Memory operations append to `g/reports/memory_audit.log` for offline review.
- Feedback submissions recorded in `sessionStorage` and optionally synced to `g/reports/feedback_queue.json` (stub until sync service implemented).
- Ops Atomic gate logs stored alongside CI artifacts.

## Data Residency & Retention
- Default storage location: repository workspace (treated as EU-friendly data center when mirrored).
- Long-term memory stored in `g/memory/vector_index.json`; cleanup job enforces max retention of 365 days unless flagged important.
- RAG sources limited to approved directories; Drive/Slack connectors require residency tags before syncing.
- User feedback trimmed after 90 days unless linked to ongoing tickets.

## Encryption & Transport
- TLS termination handled by deployment platform (Cloudflare Pages/Netlify/Vercel). Local dev uses HTTP only.
- At-rest encryption delegated to host filesystem; recommended to run on encrypted volumes for production.
- Sensitive connector payloads encrypted using AES-256 via platform secrets module (TODO once connectors active).

## Human Approval for Risky Operations
1. System detects action with `riskScore >= 0.7` (deployments, mass updates, incident responses).
2. API responds with `requiresApproval: true` and records action in audit log.
3. UI prompts assigned human to approve/deny; action blocked until approval recorded.
4. Approved actions executed with Ops Atomic webhook; results appended to audit trail.

## Monitoring & Incident Response
- Health checks via `/healthz` and `/capabilities` endpoints.
- CI enforces smoke tests and optional Ops Atomic gating.
- Runbook stored in `g/reports/ASSISTANT_IMPLEMENTATION_README.md`.
- Incident triggers: repeated auth failures, rate limit breaches, or connector errors escalate to human on-call via Slack stub.
