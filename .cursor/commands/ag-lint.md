---
description: Run Antigravity QA/tests via the LAC QA lane
---

Use this to trigger QA checks for Antigravity through the LAC QA lane (local-first).

## Usage
```
/ag-lint
/ag-lint "Run smoke tests for antigravity core"
```

## What it does
- Builds a Work Order for QA on `system/antigravity` (reachable via `g/src/antigravity`)
- Asks QA lane to run lightweight lint/pytest per the new QA actions
- Returns pass/fail summary (exit codes, stderr snippet)

## Notes
- No direct edits; this is routed through LAC QA
- Honors `shared/policy.py` and existing pipeline semantics
