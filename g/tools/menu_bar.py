#!/usr/bin/env python3
"""
02LUKA Status Menu Bar App
--------------------------
Reads g/core_state/latest.json and displays system status.
Requires: pip install rumps
"""

import json
import rumps
import subprocess
import time
import os
from pathlib import Path
from datetime import datetime

# Configuration
REPO_ROOT = Path(os.environ.get("LUKA_ROOT", Path.home() / "02luka")).resolve()
STATE_DIR = REPO_ROOT / "g" / "core_state"
LATEST_JSON = STATE_DIR / "latest.json"
LATEST_MD = STATE_DIR / "latest.md"

class LukaStatusBarApp(rumps.App):
    def __init__(self):
        super(LukaStatusBarApp, self).__init__("⚪️ Luka")
        self.menu = ["Refresh", "Open Report", "Run Snapshot"]
        self.last_refresh = 0
        self.update_status(None)

    @rumps.timer(60)
    def auto_refresh(self, _):
        self.update_status(None)

    @rumps.clicked("Refresh")
    def update_status(self, _):
        if not LATEST_JSON.exists():
            self.title = "⚠️ No Data"
            return
            
        try:
            data = json.loads(LATEST_JSON.read_text())
            # Logic for status
            git_clean = data.get("git_status", {}).get("clean", False)
            guard_running = data.get("mls_symlink_guard", {}).get("running", False)
            
            # Simple heuristics
            if not guard_running:
                self.title = "❌ Guard Down"
            elif not git_clean:
                self.title = "📝 Dirty"
            else:
                self.title = "✅ Luka"
                
            # Add timestamp hover or sub-menu? (Rumps limitation: title is main arg)
            ts = data.get("timestamp", {}).get("local", "")
            self.menu["Refresh"].title = f"Refresh (Last: {ts[11:19]})"
            
        except Exception as e:
            self.title = "⚠️ Error"
            print(f"Error reading status: {e}")

    @rumps.clicked("Open Report")
    def open_report(self, _):
        if LATEST_MD.exists():
            subprocess.run(["open", str(LATEST_MD)])
        else:
            rumps.alert("Report not found", f"Checking {LATEST_MD}")

    @rumps.clicked("Run Snapshot")
    def run_snapshot(self, _):
        # Trigger core_latest_state.py --write
        script = REPO_ROOT / "g" / "tools" / "core_latest_state.py"
        if script.exists():
            subprocess.run(["python3", str(script), "--write"])
            self.update_status(None)
        else:
            rumps.alert("Snapshot tool not found")

if __name__ == "__main__":
    LukaStatusBarApp().run()
