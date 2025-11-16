# CLS Memory

## Purpose
- Store CLS context, notes, and state (NOT source of truth)
- Track orchestration decisions and evidence

## Write Permissions
CLS may write freely within this directory per AI/OP-001 Rule 91.
See `ALLOWLIST.paths` for complete write permissions.

## Audit
All CLS file operations logged to: `~/02luka/g/telemetry/cls_audit.jsonl`

## Work Orders
For any changes to SOT (code/config/docs), CLS must create Work Order:
```bash
~/tools/bridge_cls_clc.zsh --title "Task" --body payload.yaml
```
