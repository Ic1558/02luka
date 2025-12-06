# Workflow Dev Review Save - Usage Guide

**Date:** 2025-12-07
**Script:** `tools/workflow_dev_review_save.zsh`

## Overview
This workflow unifies three critical development tasks into a single atomic operation:
1.  **Local Agent Review:** Scans code changes for bugs/security issues (using Claude or offline checks).
2.  **GitDrop Snapshot:** Creates a safety backup of the workspace state.
3.  **Save Session:** Generates a session report with telemetry and commits changes to memory/main repos.

Using this workflow ensures code quality, data safety, and accurate session tracking with one command.

## Manual Usage

### Option 1: Alias (Recommended)
First, ensure you have sourced the aliases file (add to your `~/.zshrc`):
```zsh
source ~/02luka/tools/git_safety_aliases.zsh
```
Then simply run:
```zsh
drs
```
*(Stands for: **D**ev **R**eview **S**ave)*

### Option 2: Direct Script Execution
```zsh
~/02luka/tools/workflow_dev_review_save.zsh
```

## Git Hook Integration (Opt-in)

To automatically run this workflow before every `git push`, use the helper script in your pre-push hook.

**File:** `.git/hooks/pre-push`
```zsh
#!/bin/sh
# Call the 02luka pre-push helper
~/02luka/tools/git_hook_pre_push_dev_review_save.zsh
```
*Make sure the hook file is executable: `chmod +x .git/hooks/pre-push`*

**Behavior:**
- If the workflow succeeds (Exit 0), the push proceeds automatically.
- If issues are found (Review fails or Save error), it pauses and asks: `Continue push despite errors? [y/N]`

## Telemetry & Logs

The workflow logs execution metadata for system health monitoring:
*   **Workflow Chain Log:** `g/telemetry/workflow_dev_review_save.jsonl` (Tracks Review/Snapshot/Save exit codes)
*   **Save Session Log:** `g/telemetry/save_sessions.jsonl` (Tracks session artifacts created)
*   **Snapshots:** `g/snapshots/` (Managed by GitDrop)
