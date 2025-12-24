02LUKA OS vs Tool Boundary
==========================

What counts as OS (in scope)
- L0 Storage: SQLite append-only, SHA-256 hash-chain tamper detection.
- L1 Universal Event Log: immutable events, verify_chain enforcement, session/event logging.
- L2 Shared Query: tools/os_l2_query.py (sessions, session-timeline, session-summary, task-timeline).
- Gateway v3 Phase 0: MAIN inbox ingress → normalize → route (Mary-centric), sandbox-safe.
- Truth Sync P0: g/tools/system_truth_sync_p0.py (runtime truth snapshot to JSON/MD, read-only).

What is explicitly *not* OS (out of scope)
- ATG GC, tool hygiene, janitor/maintenance scripts, LaunchAgents for utilities.
- Dev ergonomics (aliases, CLI wrappers) unless they affect OS persistence/control-plane directly.
- One-off governance helpers that do not write to the OS event log.

Boundary rules
- OS components must log to L1, respect append-only policy, and be covered by integrity checks (verify_chain).
- Control-plane ingress must normalize/route via Gateway contracts before execution.
- Tools that do not meet the above are “utilities,” not OS; failures there do not block OS readiness.

Usage guidance
- For reliability/go-live questions, evaluate only the OS set above.
- For utility bugs (e.g., GC scripts), treat as non-blocking to OS unless they affect L0/L1 data or Gateway routing.
- When adding new capabilities, decide: does it log/route through OS? If yes, put it under OS contracts; otherwise keep it in tools.
