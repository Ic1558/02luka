# 02Luka Traffic Light

A minimal macOS menu bar indicator for 02Luka.
Reads `g/core_state/latest.json` every 5 seconds.

## Status Signals
- 🟢 **OK**: Git clean + MLS Guard running
- 🔴 **Attention**: Git dirty OR MLS Guard down
- ⚪️ **No Data**: Snapshot missing or unreadable

## Setup
1. Install string:
   ```bash
   pip install --user rumps
   ```
2. Run:
   ```bash
   python3 g/tools/menu_bar.py
   ```

## Note
This is a read-only indicator. It has no menu items or actions.
To quit, use Activity Monitor or `killall Python`.
