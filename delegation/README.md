# Codex Delegation Pipeline

This module implements the "prompt as contract" workflow for GG → CODE-IMPLEMENTER
hand-offs. Prompts are versioned, deterministically rendered, and validated before
any automated execution occurs.

## Key components

* `prompts/codex_delegation/v1.4.2/` – Versioned prompt assets (system prompt, spec, policy, schema).
* `runners/` – Python utilities for rendering prompts, calling the model, validating responses, and logging telemetry.
* `golden/` – Continuous evaluation corpus used to measure end-to-end health.
* `telemetry/` – JSONL event log for replayability and auditing.

See `delegation/runners/pipeline.py` for the high-level orchestration entry point.
