# Delegation Telemetry

All Codex delegation requests append structured JSONL events to `events.jsonl`.
Each line contains hashed prompt metadata and execution outcomes, allowing
replayability without storing raw prompts.
