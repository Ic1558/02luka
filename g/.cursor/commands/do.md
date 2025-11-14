# /do — Create & DROP a Work Order (ENTRY→Mary)
You will create a WO YAML from my text and atomically drop it into
`~/02luka/bridge/inbox/ENTRY/` for Mary to dispatch. Use ONE schema below.

## WO Schema (single source of truth)
id: auto
intent: <apply_sip_patch|run_shell|deploy|review|plan>
summary: <one-line>
priority: <low|normal|high|urgent>
target_candidates: [clc, shell]
strict_target: false
timeout_sec: 900
cost_cap_usd: 0.50
artifacts:
  - type: <sip_patch|shell_script|plan_md|files>
    path: <relative path if any>
route_hints:
  fallback_order: [clc, shell]
notify:
  telegram: true
return_channel: "shell:response:shell"

## Task
Write a concise WO from my input. If I paste code, make `artifacts` accordingly.
