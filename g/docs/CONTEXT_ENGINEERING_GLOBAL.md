# Context: Local Patch Engine wiring (global)

Status: **IMPLEMENTED** (LPE worker + LaunchAgent)

- LPE worker (`g/tools/lpe_worker.zsh`) now executes patches via the Luka CLI SIP handler and logs every attempt to the MLS ledger.
- LaunchAgent `com.02luka.lpe.worker` can be loaded via `launchctl load ~/02luka/LaunchAgents/com.02luka.lpe.worker.plist` and will keep the worker alive.
- Mary dispatcher routes write-type work orders with `fallback: lpe` into `bridge/inbox/LPE`, which the worker consumes.
- Routing rules are captured in `g/config/orchestrator/routing_rules.yaml` (v0) so orchestration code has a single reference point.
- Ledger entries are appended under `mls/ledger/YYYY-MM-DD.jsonl` with patch metadata for auditability.
- A smoke test script is available at `g/tools/lpe_smoke_test.zsh` to verify end-to-end patching and ledger logging.
