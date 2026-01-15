# 02Luka Menu Bar App

A minimal macOS menu bar status indicator for 02Luka.
Reads `g/core_state/latest.json` (does not poll system directly unless "Run Snapshot" is clicked).

## Setup

1. Install dependency:
   ```bash
   pip install --user rumps
   ```
   *(Note: rumps wraps PyObjC, so it needs a system python or venv with access to macOS frameworks)*

2. Ensure snapshot tool exists:
   `g/tools/core_latest_state.py`

## Usage

Run from repo root:
```bash
python3 g/tools/menu_bar.py
```

## Features
- **Auto-refresh**: Every 60s
- **Status Signals**:
  - `✅ Luka`: All good (Guard running, Git clean)
  - `📝 Dirty`: Git has uncommitted changes
  - `❌ Guard Down`: MLS Symlink Guard not running
  - `⚠️ No Data`: Snapshot missing
- **Actions**:
  - Open Report: Opens `latest.md`
  - Run Snapshot: Triggers `core_latest_state.py --write` immediately
