#!/usr/bin/env python3
"""
02LUKA Traffic Light Status
---------------------------
Reads g/core_state/latest.json and displays status:
🟢 = Clean & Guard Running
🔴 = Dirty or Guard Down
⚪️ = No Data / Error

No menu items. No actions.
"""

import json
import os
import rumps
from pathlib import Path

# Configuration
REPO_ROOT = Path(os.environ.get("LUKA_ROOT", Path.home() / "02luka")).resolve()
STATE_DIR = REPO_ROOT / "g" / "core_state"
LATEST_JSON = STATE_DIR / "latest.json"

OK_ICON = "🟢"
BAD_ICON = "🔴"
UNKNOWN_ICON = "⚪️"

class LukaTrafficLight(rumps.App):
    def __init__(self):
        super(LukaTrafficLight, self).__init__(UNKNOWN_ICON, quit_button=None)
        self.menu = [] # No menu items
        self.timer = rumps.Timer(self.update_status, 5)
        self.timer.start()
        self.update_status(None)

    def update_status(self, _):
        if not LATEST_JSON.exists():
            self.title = UNKNOWN_ICON
            return

        try:
            data = json.loads(LATEST_JSON.read_text())
            git_clean = data.get("git_status", {}).get("clean")
            guard_running = data.get("mls_symlink_guard", {}).get("running")

            if git_clean is True and guard_running is True:
                self.title = OK_ICON
            else:
                self.title = BAD_ICON
        except Exception:
            self.title = UNKNOWN_ICON

if __name__ == "__main__":
    LukaTrafficLight().run()
