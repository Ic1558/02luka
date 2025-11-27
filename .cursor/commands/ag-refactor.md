---
description: Send an Antigravity refactor request to the LAC dev_oss lane via LIAM
---

Use this when you want the LAC engine to refactor Antigravity code through the dev_oss lane (local/free), with LIAM handling WO dispatch and self-apply for simple cases.

## Usage
```
/ag-refactor "Refactor greeting flow in core/hello.py"
/ag-refactor "Split Greeter responsibilities and add unit tests"
```

## What it does
- Builds a Work Order targeting `g/src/antigravity/**` (symlink to `system/antigravity`)
- Routes via LIAM → dev_oss (self_apply=true for simple patches)
- Keeps CLC optional (only for complex/multi-file per LAC Realignment V2)
- Respects `shared/policy.py` for write permissions

## Notes
- Use for Antigravity code changes (core/, tests/, docs within project)
- Leaves an audit trail in the LAC pipeline
