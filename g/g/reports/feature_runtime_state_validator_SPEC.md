# Phase 2.2 — Runtime State Validator (SPEC)

## Goal
Perform continuous runtime validation of all com.02luka.* LaunchAgents by
cross-checking:
- launchctl PID / exit status
- Redis subscriber count for expected channels
- Executable timestamps or crash loops
- Last heartbeat for agents that publish heartbeats

## Scope
- macOS only (LaunchAgents + launchctl)
- All com.02luka.*.plist under:
  - ~/02luka/LaunchAgents
  - ~/Library/LaunchAgents

## Requirements
1. For each LaunchAgent plist:
   - Extract: Label, Program / ProgramArguments[0]
   - Read launchctl runtime: PID, exit status
   - Infer expected Redis channel from label (strip "com.02luka.")
   - Query Redis: PUBSUB NUMSUB <channel>
   - Classify status: ok / warn / error

2. Output:
   - Markdown summary:
     - One section per label
     - Raw PID / exit / subs + derived status
   - JSONL:
     - One JSON object per label
     - Fields: label, program, pid, exit, channel, subs, status, timestamp

3. Storage:
   - Directory: g/reports/system/launchagents_runtime/
   - Filenames:
     - RUNTIME_YYYYMMDD_HHMMSS.md
     - RUNTIME_YYYYMMDD_HHMMSS.jsonl

4. Behavior:
   - No crash on missing Redis or missing label (degrade to WARN)
   - Safe to run manually or via LaunchAgent
   - No git tracking for runtime reports

5. Optional API:
   - GET /api/system/agents
   - Returns aggregated runtime state for dashboard

6. MLS integration:
   - Append entry to g/knowledge/mls_lessons.jsonl:
     - id: MLS-OPS-RUNTIME-STATE-20251117
     - type: solution
     - tags: ["ops","launchagent","monitoring","runtime"]
     - describes rules and storage layout

## Non-goals
- No auto-remediation (kill / restart) in this phase
- No modification of existing LaunchAgents
