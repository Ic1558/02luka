# Codex Routing Flowchart

Text-based decision guide for "CLC or Codex?"

```
Start
  |
  v
Is it in a locked zone (core/governance/launchd/memory)?
  |-- Yes --> CLC
  |-- No --> Security-critical?
              |-- Yes --> CLC
              |-- No --> 4+ files or design-heavy change?
                          |-- Yes --> CLC
                          |-- No --> Clear patch (1-3 files)?
                                      |-- Yes --> Codex (interactive)
                                      |-- No --> CLC
```

Notes:
- If Codex needs `codex-task`, run interactively (TTY required) or use CLC fallback.
- If scope expands mid-task, switch to CLC or split into smaller Codex tasks.

---

## Governance Task Execution Model

**CLC-routed tasks operate independently and do NOT block Codex execution:**

✅ **Non-Blocking:** Governance tasks are ROUTED to CLC, not BLOCKING operational work
✅ **Queue-Based:** CLC tasks queue independently; Codex continues immediately
✅ **Zero Impact:** No synchronous wait required for governance completion

**Metrics Proof:** Week 1+2 achieved 86% CLC savings with only 2-3 governance tasks total.

**Rule:** Governance routing is a LANE ASSIGNMENT, not a BLOCKING DEPENDENCY.
