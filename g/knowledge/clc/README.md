# CLC Knowledge Zone

This directory serves as the dedicated, long-term memory store for the CLC (Code & Logic Companion) agent system. It is designed to be separate from the global `MLS` (Multi-Layered System) memory and the `02luka.md` master document.

The primary consumer of this knowledge is the **GMX CLC Orchestrator**, which uses the data here to reason about system state and plan future Work Orders for the CLC Worker.

## Directory Structure

- **`event_log.jsonl`**: (Planned) A log of significant events executed by the CLC Worker. Each line is a JSON object containing details like `wo_id`, `files_touched`, `status`, and a `summary` of the action. This provides a granular history of operations.

- **`topic_memory.yaml`**: (Planned) A structured summary of key topics, learnings, and architectural decisions derived from the event log. This file is periodically updated by a GMX-driven process to provide a high-level, semantic understanding of past work without needing to parse the entire event log.

- **`snapshots/`**: (Planned) A directory to store periodic snapshots of important file states or configurations. This can be used as a reference point for complex refactoring tasks.

- **`*.md`**: Ad-hoc markdown documents for specific, human-readable notes or summaries related to CLC's operational context.

## Principles

1.  **CLC-Centric**: All data within this zone pertains directly to the operational context of the CLC agent.
2.  **GMX-Readable**: The formats (`.jsonl`, `.yaml`) are chosen for easy parsing and processing by the GMX planner.
3.  **Append-Oriented**: The primary data stores (like `event_log.jsonl`) should be treated as append-only logs to ensure a durable and auditable history.
