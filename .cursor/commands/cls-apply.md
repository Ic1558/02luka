---
description: Apply changes via CLS V4 (LAC local-first engine)
---

Use this command when you want the 02luka LAC/CLS engine to handle complex or multi-file work:

- Large refactors
- Multi-file patches
- Pipeline operations (DEV→QA→DOCS→MERGE)
- Work that should be logged and audited in 02luka

## Usage Examples

```
/cls-apply "Refactor this module into smaller functions"
/cls-apply "Apply a safe patch across all files in this folder"
/cls-apply "Run DEV→QA→DOCS→DIRECT_MERGE for this feature"
```

## What It Does

1. Captures the current file, selection, and your description
2. Creates a Work Order for CLS V4
3. Sends it to the 02luka LAC engine (local-first, free)
4. Returns a summary/diff once processing completes

## When to Use

**Use `/cls-apply` for:**
- Multi-file operations (3+ files)
- Large refactors
- When you need pipeline automation (QA/Docs/Merge)
- When you need audit trail/logging
- When you want consistency with 02luka architecture

**Use direct Cursor AI for:**
- Simple single-file edits
- Quick fixes
- Learning/exploring code
- Interactive debugging

## Technical Details

The command calls `tools/cursor_cls_wrapper.py` which:
- Builds a Work Order JSON matching `schemas/work_order.schema.json`
- Drops it to `g/bridge/inbox/CLC/`
- Polls `g/bridge/outbox/CLC/` for results
- Returns formatted output to Cursor

All operations use the LAC V2 local-first engine (OSS/GMX) and respect `shared/policy.py` for file write permissions.

