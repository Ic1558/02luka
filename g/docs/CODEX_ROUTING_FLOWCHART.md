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
