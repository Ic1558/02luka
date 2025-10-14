---
project: general
tags: [legacy]
---
# Agent State Snapshot - 2025-10-04

## Status
- Agents OK, bad_log_paths=0, exits=0
- Tag baseline: v2025-10-04-cursor-ready
- System clean and ready for development

## Morning Routine
Use this one-liner to start your day:
```bash
bash ./.codex/preflight.sh && bash ./run/dev_up_simple.sh && bash ./run/smoke_api_ui.sh
```

Or use the convenience script:
```bash
./run/dev_morning.sh
```
