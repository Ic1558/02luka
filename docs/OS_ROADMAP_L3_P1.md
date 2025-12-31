02LUKA OS Roadmap (Near-Term)
=============================

Scope
- Layer 3 multi-agent coordination / shared planning.
- Gateway v3 Phase 1 (scheduling/retry/priority).
- Truth Sync P1 (governed auto-patch + richer signals).

Layer 3: Multi-agent coordination / shared planning
- Capabilities: shared task graph, role-aware planning (decision vs execution), plan revisions logged to L1, handoff metadata for agents.
- Success criteria: agents can read/write shared plan state via OS; plan diffs logged immutably; conflict detection for concurrent edits; minimal orchestration loop runs in sandbox (demo scenario).
- Dependencies: stable L0/L1; L2 query interface; Gateway ingress hooks for plan updates.

Gateway v3 Phase 1
- Capabilities: scheduled dispatch, retry/backoff, priority queueing, basic quotas; richer routing signals (task metadata, agent availability).
- Success criteria: tasks accepted via MAIN inbox are scheduled (time/priority-aware); retries happen with logged attempts; routing decisions recorded to L1; unit/integration tests covering success + retry + drop/poison cases.
- Dependencies: Gateway v3 P0 baseline; event logging to L1; lightweight scheduler loop; configuration schema for priorities/limits.

Truth Sync P1
- Capabilities: governed auto-patch to 02luka.md (or target MD) with status block; expanded signals (runtime health, Gateway queue stats, L3 plan snapshot); dry-run vs commit modes.
- Success criteria: generates MD + JSON; governance gate for writes; append-only log entries for sync actions; safe failure behavior (no partial writes); cron/daemon-friendly invocation.
- Dependencies: Truth Sync P0 CLI; write target and governance rules; L2 access to required signals; idempotent update logic.

Execution notes
- Treat each as a feature flaggable module; keep append-only logging.
- Maintain sandbox-safe defaults; disable network/side effects unless explicitly configured.
- Add targeted tests per module (unit + minimal integration) before toggling on.
