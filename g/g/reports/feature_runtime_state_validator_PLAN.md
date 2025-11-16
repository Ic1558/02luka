# Phase 2.2 — Runtime State Validator (PLAN)

## Overview
Add a runtime validator for com.02luka.* LaunchAgents that:
- Reads live state from launchctl
- Checks Redis subscriber count for expected channels
- Classifies status (ok / warn / error)
- Emits Markdown + JSONL reports to g/reports/system/launchagents_runtime/
- Optionally exposes a dashboard-friendly API

## Tasks

### T1 — Script implementation (tools/validate_runtime_state.zsh)
- Parse all com.02luka.*.plist from:
  - ~/02luka/LaunchAgents
  - ~/Library/LaunchAgents
- For each plist:
  - Extract Label, Program / ProgramArguments[0]
  - Query launchctl list for PID + exit status
  - Derive expected Redis channel from label (strip prefix)
  - Query redis-cli PUBSUB NUMSUB <channel>
  - Classify status:
    - ok: PID running AND exit in {0,-} AND subs >= 1
    - warn: PID running but subs == 0 OR unknown label
    - error: PID '-' with non-zero exit OR launchctl missing

### T2 — Report writer
- Create directory: g/reports/system/launchagents_runtime/
- Filenames:
  - RUNTIME_YYYYMMDD_HHMMSS.md
  - RUNTIME_YYYYMMDD_HHMMSS.jsonl
- Markdown:
  - One section per label
  - Show PID, exit, channel, subs, status
- JSONL:
  - One JSON per label (flat fields + timestamp)

### T3 — LaunchAgent
- File: LaunchAgents/com.02luka.runtime_state.plist
- ProgramArguments[0]: /Users/icmini/02luka/g/tools/validate_runtime_state.zsh
- StartInterval: 60 seconds
- Stdout/Stderr to logs/runtime_state.*.log

### T4 — Optional dashboard API
- Endpoint: GET /api/system/agents
- Read latest JSONL under g/reports/system/launchagents_runtime/
- Return array of agent runtime entries

### T5 — MLS entry
- Append to g/knowledge/mls_lessons.jsonl:
  - id: MLS-OPS-RUNTIME-STATE-20251117
  - type: solution
  - title: "Runtime LaunchAgent validation logic"
  - description: runtime rules + storage+ classification
  - tags: ["ops","launchagent","monitoring","runtime"]
  - verified: false

### T6 — Commit + PR
- Branch: feature/phase2-runtime-state-validator
- Commit: feat(ops): add runtime LaunchAgent validator (Phase 2.2)
- PR: describe validator, reports, MLS entry
