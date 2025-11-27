# CLC-METADATA:
#   agent: "codex-cli"
#   role: "CLC_PRIMARY"
#   wo_id: "WO-CLC-FIX-CODEX-ROLLOUT-V1"
#   change_id: "5ee9ad6d1ecfb610"
#   ts: "2025-11-26T18:34:30.235603Z"
#   action: "create"
#   file: "/Users/icmini/02luka/g/reports/system/251127_codex_rollout_audit.md"
#   checksum_before: "6ce634d2e33f23e0f41d3231b56c6461facacea5a6e38b15f6e038fdfe083402"
#   checksum_after: ""
# Codex Rollout Recorder Audit (251127)

- Issue: `codex exec` fails with `failed to initialize rollout recorder: Operation not permitted (os error 1)` when invoked by CLC bridge.
- Root cause: Codex CLI attempts to initialize its rollout recorder in a location not writable under our environment (likely SIP/home restrictions). No API-key mode available; ChatGPT-auth only, so deep model unavailable.
- Mitigation applied:
  - Force rollout recorder off and/or to a writable dir via flags and env in `g/tools/clc_run_wo.zsh`.
  - Writable dir: `/Users/icmini/02luka/tmp/codex_rollouts` (created on demand).
  - Env: `CODEX_DISABLE_ROLLOUT_RECORDER=1`, `CODEX_ROLLOUT_RECORDER_DIRECTORY=$ROOT/tmp/codex_rollouts`.
  - Flags: `-c rollout_recorder.enabled=false` and `-c rollout_recorder.directory=$ROLLOUT_DIR`.
  - Added probe script `g/tools/clc_codex_probe.zsh` to exercise Codex with the same settings and log to `g/logs/clc_codex_runner.log`.
- Open risk:
  - Codex “deep” model remains blocked for ChatGPT-auth; use OpenAI API–based deep agent instead (see WO-CREATE-DEEP-AGENT / WO-INTEGRATE-DEEP-AGENT).
  - If rollout recorder still fails on some hosts, rerun the probe and capture stderr in `g/logs/clc_codex_runner.log` for escalation.
