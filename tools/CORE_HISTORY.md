# Core History Generator (`tools/core_history_sync.zsh`)

Standalone entrypoint to produce shared history bundles for any agent (Codex CLI/IDE, Gemini CLI, cron/LaunchAgent) without relying on Raycast/Antigravity.

## Usage
- Dry-run (no writes): `zsh tools/core_history_sync.zsh --dry-run`
- Write outputs (atomic): `zsh tools/core_history_sync.zsh --run`
- Options: `--out-dir DIR` (default `g/telemetry/core_history`), `--max-decisions N` (default 40), `--max-ops N` (default 40)

## Outputs (on --run)
- `g/telemetry/core_history/latest.json` — machine-readable bundle
- `g/telemetry/core_history/latest.md` — human-readable summary
- `g/telemetry/core_history/core_history_status.json` — quick health snapshot (has_decisions, has_snapshot, hashes)

## Inputs (best-effort)
- Decisions: `g/telemetry/decision_log.jsonl` (from `decision_summarizer` via bridge) — if missing, decisions section is `status: missing`
- Snapshots: `magic_bridge/inbox/atg_snapshot.md` (+ `.summary.txt` if bridge produced it)
- Ops: `g/telemetry/atg_runner.jsonl`, `g/telemetry/fs_index.jsonl`
- Codex routing log: `g/reports/codex_routing_log.jsonl`

## Notes
- Missing inputs are non-blocking; they’re marked in the output.
- RULE_TABLE integrity is hashed from `decision_summarizer.py` (sha256 of RULE_TABLE JSON).
- Atomic writes: mktemp + mv; safe to call from cron/LaunchAgent/Raycast adapters.
