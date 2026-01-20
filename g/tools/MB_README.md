# 02Luka Dashboard

A menu bar status monitor for 02Luka.
Reads `g/core_state/latest.json` every 5 seconds.

## Dashboard Features
- **Visuals**: Traffic Light Icon (Status) + Dropdown Details
- **Header**: Last update time
- **LAC**: Real-time Inbox & Processing counts
- **Bridge**: Process status (PID)
- **Repo**: Clean/Dirty status
- **Action**: One-click "Take Snapshot" (runs `system_snapshot.zsh`)
- **Server**: Exposes `latest.json` at `http://localhost:1558/status`

## Status Signals
- 🟢 **OK**: Git clean + MLS Guard running
- 🔴 **Attention**: Git dirty OR MLS Guard down
- ⚪️ **No Data**: Snapshot missing or unreadable

## Setup
1. Install requirements:
   ```bash
   pip install --user rumps
   ```
2. Run:
   ```bash
   python3 g/tools/menu_bar.py
   ```

## Note
This app runs a lightweight HTTP server on port 1558 (thread).
To quit, select "Quit 02Luka" from the menu.
