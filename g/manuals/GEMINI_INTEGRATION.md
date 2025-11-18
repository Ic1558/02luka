# Gemini Integration

This guide tracks the Gemini integration phases. Phase 3 introduces a dedicated work
order lane so heavy, non-locked tasks can be routed through the audited bridge.

## WO Lane

- Inbox: `bridge/inbox/GEMINI`
- Outbox: `bridge/outbox/GEMINI`
- Handler: `bridge/handlers/gemini_handler.py`
- Dispatcher: `tools/wo_dispatcher.zsh` (supports `engine: gemini` / `GEMINI`)

### Example WO YAML

```yaml
wo_id: "GEMINI_YYYYMMDD_0001"
engine: "gemini"
task_type: "bulk_test_generation"
priority: "normal"

input:
  instructions: |
    Generate tests for the following module with at least 80% branch coverage.
  target_files:
    - "g/apps/dashboard/api_server.py"
  context:
    repo_root: "/Users/icmini/02luka"
    impact_zone: "apps"
    locked_zone: false

output:
  expected_format: "patch"
  reviewer: "andy"

meta:
  created_by: "gg"
  source: "kim_telegram"
  notes: []
```
