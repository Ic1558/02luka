# System Snapshot CLI

Date: 2025-11-15

## Overview

`tools/system_snapshot.zsh` creates a unified markdown report of the current
02luka state: git status, LaunchAgent services, health snapshots, and basic telemetry.

## Usage

```bash
cd ~/02luka/g
tools/system_snapshot.zsh
tools/system_snapshot.zsh --label "post_deploy"
```

## Output

Reports are stored under `g/reports/system/system_snapshot_YYYYMMDD_HHMMSS_<label>.md`.
