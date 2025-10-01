# Golden Delegation Tasks

This directory contains a curated set of delegation scenarios used for continuous evaluation.

* `tasks/` – individual task briefs that mimic day-to-day GG workflows.
* `expected/` – optional ground-truth responses for deterministic regressions.

To add a new task, drop a JSON file in `tasks/` with the following keys:

```json
{
  "id": "task-021",
  "title": "Short title",
  "description": "One sentence summary of the requested change.",
  "expected_outcome": "What success looks like.",
  "tags": ["feature", "frontend"]
}
```

Keep the set between 30 and 100 tasks to ensure meaningful coverage without ballooning runtime.
