# Context Engineering (Global) — LPE readiness update

## Local Patch Engine status
- ✅ LPE worker operational via `g/tools/lpe_worker.zsh`.
- ✅ LaunchAgent `com.02luka.lpe.worker` installed under `~/02luka/LaunchAgents` (RunAtLoad + KeepAlive).
- ✅ Mary dispatcher now routes write-type WOs with `fallback_order` containing `lpe` into the LPE queue.
- ✅ Every LPE patch append logs into `mls/ledger/<date>.jsonl` via `g/tools/append_mls_ledger.py`.
- ✅ Smoke validation available via `g/tools/lpe_smoke_test.zsh`.

## How to run
1. `launchctl load ~/02luka/LaunchAgents/com.02luka.lpe.worker.plist` — worker starts polling `bridge/inbox/LPE`.
2. Drop a WO in `bridge/inbox/ENTRY` with `task.type: write` and `route_hints.fallback_order` including `lpe`; Mary will route it automatically.
3. Confirm patches + ledger entries with `g/tools/lpe_smoke_test.zsh`.

## Notes
- Patch application is delegated to the Luka CLI (`tools/luka_cli.zsh lpe-apply`).
- Patch files referenced in WOs must stay within the repo root; the worker rejects paths that escape `${HOME}/02luka`.
