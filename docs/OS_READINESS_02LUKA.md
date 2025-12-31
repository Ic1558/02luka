02LUKA OS — Readiness Declaration (Kernel + Control Plane P0)
=============================================================

Definition (scope)
- Agentic OS (not Unix kernel): truth store, memory, control-plane; separates decision/execution/logging.
- Layers in scope: L0 (storage), L1 (universal event log), L2 (shared query), Gateway v3 Phase 0 (ingress/routing), Truth Sync P0 (read-only reporting).
- Out of scope: ATG GC, tool hygiene, janitors, maintenance scripts.

Current status (ready for sandbox use)
- L0 storage substrate: SQLite append-only with SHA-256 hash-chain; tamper-detect; portable backend.
- L1 universal event log: no delete/update; trigger + verify_chain; used by session logs.
- L2 query CLI: sessions, session-timeline, session-summary, task-timeline; JSON output.
- Gateway v3 Phase 0: MAIN inbox ingest → normalize → route (Mary-centric); sandbox-safe; unit tests passing.
- Truth Sync P0: runtime truth snapshot (sandbox health, gateway telemetry, WO snapshot) → JSON + MD; read-only; installed and runnable.

Evidence (latest verification)
- L0/L1: verify_chain passes; enforcement active in workflows.
- L2: tools/os_l2_query.py exercised; outputs correct JSON for sessions/timelines.
- Gateway v3 P0: pytest g/gateway/v3/core/test_router.py (3 tests) passing.
- Truth Sync P0: g/tools/system_truth_sync_p0.py --md produces MD block; CLI installed.
- Runtime: rag.api green on real Mac (PID running, port 8765, /health ok, clean stderr); workflow governance active; strategic-change reminder WARN-only.

Operational readiness
- Supported environments: desktop macOS verified; design supports mobile/IoT/browser via SQLite portability.
- Interfaces: CLI for L2 queries; Gateway ingress for tasks; Truth Sync CLI for status.
- Persistence: append-only policy; tamper detection via hash-chain.
- Governance: event logging enforced; control-plane ingress logs into OS.

Known non-blockers (excluded from readiness)
- ATG GC, tool cleanup, janitor utilities, LaunchAgent for mcp.fs.

What “ready” means here
- Safe to use as sandbox OS and system of record for events/tasks.
- Stable kernel (L0/L1) with verified integrity checks.
- Usable control-plane ingress (Gateway P0) and truth reporting (Truth Sync P0).

Next actions (optional enhancements, not gating readiness)
- Layer 3 multi-agent coordination.
- Gateway v3 Phase 1: scheduling/retry/priority.
- Truth Sync P1: auto-patch 02luka.md (governed), expanded signals.
