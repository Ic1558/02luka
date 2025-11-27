---
description: Ask LAC Docs lane to update or generate Antigravity docs
---

Use this when you want documentation updates for Antigravity handled by the LAC Docs lane.

## Usage
```
/ag-docs "Update README for new Greeter behavior"
/ag-docs "Add usage notes for antigravity tests"
```

## What it does
- Builds a Work Order targeting Antigravity docs (`system/antigravity/README.md` or related g/docs entries)
- Routes via LIAM → docs_v4 (self_apply allowed for simple doc updates)
- Keeps CLC optional per LAC Realignment V2

## Notes
- No direct Codex edits; goes through LAC pipeline
- Respects `shared/policy.py` for write permissions
