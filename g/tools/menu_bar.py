#!/usr/bin/env python3
"""
02Luka Dashboard & Traffic Light
--------------------------------
1. Visuals: Traffic Light (Status) + Dropdown Dashboard (Details)
2. Server: Exposes `latest.json` at http://localhost:1558/status
3. Actions: Trigger System Snapshot
"""

import json
import os
import rumps
import subprocess
import threading
import socket
from http.server import HTTPServer, BaseHTTPRequestHandler
from pathlib import Path
from typing import Optional, Dict, Any

# Configuration
REPO_ROOT = Path(os.environ.get("LUKA_ROOT", Path.home() / "02luka")).resolve()
STATE_DIR = REPO_ROOT / "g" / "core_state"
LATEST_JSON = STATE_DIR / "latest.json"
SNAPSHOT_SCRIPT = REPO_ROOT / "g" / "tools" / "system_snapshot.zsh"

SERVER_PORT = 1558
BIND_ADDR = "127.0.0.1"

# Icons
ICON_OK = "🟢"
ICON_WARN = "🔴"
ICON_UNKNOWN = "⚪️"
ICON_SYNC = "🔄"

class StateHandler(BaseHTTPRequestHandler):
    """Serve latest.json over HTTP for external tools."""
    def do_GET(self):
        if self.path == "/status":
            if LATEST_JSON.exists():
                try:
                    content = LATEST_JSON.read_bytes()
                    self.send_response(200)
                    self.send_header("Content-type", "application/json")
                    self.end_headers()
                    self.wfile.write(content)
                except Exception as e:
                    self.send_error(500, str(e))
            else:
                self.send_error(404, "State file not found")
        else:
            self.send_error(404, "Not Found")

    def log_message(self, format, *args):
        pass # Suppress server logs to console

class LukaDashboard(rumps.App):
    def __init__(self):
        super(LukaDashboard, self).__init__(ICON_UNKNOWN, quit_button="Quit 02Luka")
        
        # Menu Items
        self.menu_header = rumps.MenuItem("02Luka Dashboard")
        self.menu_lac = rumps.MenuItem("LAC: Checking...")
        self.menu_bridge = rumps.MenuItem("Bridge: Checking...")
        self.menu_git = rumps.MenuItem("Repo: Checking...")
        self.menu_server = rumps.MenuItem(f"Server: http://{BIND_ADDR}:{SERVER_PORT}/status")
        
        self.menu.add(self.menu_header)
        self.menu.add(rumps.separator)
        self.menu.add(self.menu_lac)
        self.menu.add(self.menu_bridge)
        self.menu.add(self.menu_git)
        self.menu.add(rumps.separator)
        self.menu.add(self.menu_server)
        self.menu.add(rumps.separator)
        self.menu.add(rumps.MenuItem("📸 Take Snapshot", callback=self.trigger_snapshot))

        # Start Background Server
        self.server_thread = threading.Thread(target=self.start_server, daemon=True)
        self.server_thread.start()

        # Start Poll Timer
        self.timer = rumps.Timer(self.update_status, 5)
        self.timer.start()
        self.update_status(None)

    def start_server(self):
        try:
            httpd = HTTPServer((BIND_ADDR, SERVER_PORT), StateHandler)
            httpd.serve_forever()
        except OSError:
            # Port likely busy, fail silently for UI but mark in menu
            self.menu_server.title = f"Server: Port {SERVER_PORT} Busy!"

    def trigger_snapshot(self, _):
        """Run snapshot script in background."""
        if SNAPSHOT_SCRIPT.exists():
            subprocess.Popen(["/bin/zsh", str(SNAPSHOT_SCRIPT)], cwd=str(REPO_ROOT))
            rumps.notification("02Luka", "Snapshot Started", "Check magic_bridge/ for results.")
        else:
            rumps.alert("Error", f"Snapshot script not found:\n{SNAPSHOT_SCRIPT}")

    def update_status(self, _):
        if not LATEST_JSON.exists():
            self.title = ICON_UNKNOWN
            self.menu_header.title = "Status: No Data"
            return

        try:
            data = json.loads(LATEST_JSON.read_text())
            
            # 1. Overall Health (Traffic Light)
            git_clean = data.get("git_status", {}).get("clean")
            guard_running = data.get("mls_symlink_guard", {}).get("running")
            
            if git_clean is True and guard_running is True:
                self.title = ICON_OK
            else:
                self.title = ICON_WARN

            # 2. Extract Details for Dashboard
            # LAC
            queues = data.get("lac_queues", {})
            inbox_count = queues.get("lac_inbox", {}).get("file_count", "?")
            proc_count = queues.get("lac_processing", {}).get("file_count", "?")
            self.menu_lac.title = f"LAC: Inbox {inbox_count} | Proc {proc_count}"

            # Bridge (Process)
            bridge_pid = data.get("processes", {}).get("gemini_bridge", {}).get("pid")
            if bridge_pid:
                self.menu_bridge.title = f"Bridge: {ICON_OK} Running (PID {bridge_pid})"
            else:
                self.menu_bridge.title = f"Bridge: {ICON_WARN} Stopped"

            # Git
            if git_clean:
                self.menu_git.title = f"Repo: {ICON_OK} Clean"
            else:
                self.menu_git.title = f"Repo: {ICON_WARN} Dirty"

            self.menu_header.title = f"Status: Updated {data.get('timestamp', {}).get('local', '').split('T')[1][:8]}"

        except Exception as e:
            self.title = ICON_UNKNOWN
            self.menu_header.title = f"Error: {str(e)[:20]}"

if __name__ == "__main__":
    LukaDashboard().run()

