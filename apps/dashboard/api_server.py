#!/usr/bin/env python3
"""
Dashboard API Server - Serves WO data and logs
Runs alongside the static HTTP server on port 8767
"""

import json
import os
import re
from datetime import datetime
from pathlib import Path
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
import subprocess

# Paths
ROOT = Path.home() / "02luka"
BRIDGE = ROOT / "bridge"
TELEMETRY = ROOT / "telemetry"
LOGS = ROOT / "logs"

class WOCollector:
    """Collects and normalizes WO data from all sources"""

    def __init__(self):
        self.wos = []

    def collect_all(self):
        """Collect WOs from all locations"""
        self.wos = []

        # Collect from archive (completed .zsh scripts)
        self._collect_archived_scripts()

        # Collect from pending (JSON requests awaiting approval)
        self._collect_pending_requests()

        # Collect from inbox (scripts ready to execute)
        self._collect_inbox_scripts()

        return self.wos

    def _collect_archived_scripts(self):
        """Collect completed .zsh scripts from archive"""
        archive_dir = BRIDGE / "archive" / "WO"
        if not archive_dir.exists():
            return

        for zsh_file in archive_dir.rglob("*.zsh"):
            wo_id = zsh_file.stem

            # Find corresponding log file
            log_files = list(TELEMETRY.glob(f"wo_execution_{wo_id}_*.log"))
            log_path = str(log_files[0]) if log_files else None

            # Parse log to get metadata
            metadata = self._parse_log(log_path) if log_path else {}

            # Extract goal from script comments
            goal = self._extract_goal_from_script(zsh_file)

            wo = {
                "id": wo_id,
                "title": wo_id,
                "goal": goal or "Script execution",
                "owner": "CLC",
                "status": metadata.get("result", "success"),
                "op": "execute",
                "inputs": {"script": str(zsh_file)},
                "outputs": {},
                "started_at": metadata.get("started_at"),
                "completed_at": metadata.get("completed_at"),
                "duration_ms": metadata.get("duration_ms"),
                "current_step": "completed",
                "error": metadata.get("error"),
                "artifacts": [log_path] if log_path else [],
                "log_path": log_path,
                "script_path": str(zsh_file)
            }

            self.wos.append(wo)

    def _collect_pending_requests(self):
        """Collect JSON WO requests awaiting approval"""
        pending_dir = BRIDGE / "outbox" / "RD" / "pending"
        if not pending_dir.exists():
            return

        for json_file in pending_dir.glob("*.json"):
            try:
                with open(json_file) as f:
                    data = json.load(f)

                wo = {
                    "id": data.get("id", json_file.stem),
                    "title": data.get("id", json_file.stem),
                    "goal": f"{data.get('op', 'process')} operation",
                    "owner": "System",
                    "status": "pending",
                    "op": data.get("op", "unknown"),
                    "inputs": data.get("inputs", {}),
                    "outputs": {},
                    "cost_estimate_usd": data.get("cost_estimate_usd"),
                    "token_estimate": data.get("token_estimate"),
                    "current_step": "awaiting_approval",
                    "error": None,
                    "artifacts": [],
                    "script_path": str(json_file)
                }

                self.wos.append(wo)
            except Exception as e:
                print(f"Error reading {json_file}: {e}")

    def _collect_inbox_scripts(self):
        """Collect scripts in inbox ready to execute"""
        inbox_dir = BRIDGE / "inbox" / "LLM"
        if not inbox_dir.exists():
            return

        for zsh_file in inbox_dir.glob("*.zsh"):
            wo_id = zsh_file.stem
            goal = self._extract_goal_from_script(zsh_file)

            wo = {
                "id": wo_id,
                "title": wo_id,
                "goal": goal or "Script execution",
                "owner": "CLC",
                "status": "queued",
                "op": "execute",
                "inputs": {"script": str(zsh_file)},
                "outputs": {},
                "current_step": "queued_for_execution",
                "error": None,
                "artifacts": [],
                "script_path": str(zsh_file)
            }

            self.wos.append(wo)

        # Also check for JSON files in inbox
        for json_file in inbox_dir.glob("*.json"):
            try:
                with open(json_file) as f:
                    data = json.load(f)

                wo = {
                    "id": data.get("id", json_file.stem),
                    "title": data.get("id", json_file.stem),
                    "goal": f"{data.get('op', 'process')} operation",
                    "owner": "System",
                    "status": "queued",
                    "op": data.get("op", "unknown"),
                    "inputs": data.get("inputs", {}),
                    "outputs": {},
                    "current_step": "queued_for_execution",
                    "error": None,
                    "artifacts": [],
                    "script_path": str(json_file)
                }

                self.wos.append(wo)
            except Exception as e:
                print(f"Error reading {json_file}: {e}")

    def _extract_goal_from_script(self, script_path):
        """Extract goal from script comments"""
        try:
            with open(script_path) as f:
                lines = f.readlines()[:20]  # Check first 20 lines

            for line in lines:
                line = line.strip()
                if line.startswith('#') and any(keyword in line.lower() for keyword in ['goal:', 'purpose:', 'objective:']):
                    return line.lstrip('#').strip()
                elif line.startswith('#') and len(line) > 10 and not line.startswith('#!/'):
                    # Use first substantial comment as goal
                    return line.lstrip('#').strip()

            return None
        except Exception:
            return None

    def _parse_log(self, log_path):
        """Parse execution log to extract metadata"""
        if not log_path or not Path(log_path).exists():
            return {}

        metadata = {}

        try:
            with open(log_path) as f:
                content = f.read()

            # Extract timestamps
            started_match = re.search(r'Started: ([\d-]+ [\d:]+)', content)
            completed_match = re.search(r'Completed: ([\d-]+ [\d:]+)', content)

            if started_match:
                metadata['started_at'] = started_match.group(1)
            if completed_match:
                metadata['completed_at'] = completed_match.group(1)

            # Calculate duration if both timestamps exist
            if started_match and completed_match:
                try:
                    start = datetime.strptime(started_match.group(1), '%Y-%m-%d %H:%M:%S')
                    end = datetime.strptime(completed_match.group(1), '%Y-%m-%d %H:%M:%S')
                    metadata['duration_ms'] = int((end - start).total_seconds() * 1000)
                except Exception:
                    pass

            # Extract result
            result_match = re.search(r'Result: (\w+)', content)
            if result_match:
                metadata['result'] = result_match.group(1)

            # Check for errors
            if 'error' in content.lower() or 'failed' in content.lower():
                metadata['error'] = {
                    'message': 'Execution error (see log)',
                    'log_path': log_path
                }

        except Exception as e:
            print(f"Error parsing log {log_path}: {e}")

        return metadata

    def get_wo_by_id(self, wo_id):
        """Get detailed WO data by ID"""
        for wo in self.wos:
            if wo['id'] == wo_id:
                # Add log tail if available
                if wo.get('log_path'):
                    wo['log_tail'] = self._get_log_tail(wo['log_path'], 100)
                return wo
        return None

    def _get_log_tail(self, log_path, lines=100):
        """Get last N lines of a log file"""
        try:
            result = subprocess.run(
                ['tail', '-n', str(lines), log_path],
                capture_output=True,
                text=True,
                timeout=5
            )
            return result.stdout.split('\n') if result.returncode == 0 else []
        except Exception:
            return []

class APIHandler(BaseHTTPRequestHandler):
    """HTTP request handler for WO API"""

    collector = WOCollector()

    def do_GET(self):
        """Handle GET requests"""
        parsed = urlparse(self.path)
        path = parsed.path
        query = parse_qs(parsed.query)

        if path == '/api/wos':
            self.handle_list_wos(query)
        elif path.startswith('/api/wos/'):
            wo_id = path.split('/')[-1]
            self.handle_get_wo(wo_id, query)
        elif path == '/api/health/logs':
            self.handle_get_logs(query)
        else:
            self.send_error(404, "Not found")

    def do_OPTIONS(self):
        """Handle preflight CORS requests"""
        self.send_response(200)
        self.send_cors_headers()
        self.end_headers()

    def send_cors_headers(self):
        """Send CORS headers"""
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')

    def handle_list_wos(self, query):
        """Handle GET /api/wos - list all WOs"""
        # Refresh WO list
        self.collector.collect_all()

        # Filter by status if requested
        status_filter = query.get('status', [''])[0]
        wos = self.collector.wos

        if status_filter:
            statuses = status_filter.split(',')
            wos = [wo for wo in wos if wo['status'] in statuses]

        # Sort by started_at descending (newest first)
        wos_sorted = sorted(
            wos,
            key=lambda w: w.get('started_at') or w.get('id'),
            reverse=True
        )

        self.send_json_response(wos_sorted)

    def handle_get_wo(self, wo_id, query):
        """Handle GET /api/wos/:id - get WO details"""
        # Refresh WO list
        self.collector.collect_all()

        wo = self.collector.get_wo_by_id(wo_id)

        if wo:
            # Add log tail if requested
            if 'tail' in query:
                lines = int(query['tail'][0])
                if wo.get('log_path'):
                    wo['log_tail'] = self.collector._get_log_tail(wo['log_path'], lines)

            self.send_json_response(wo)
        else:
            self.send_error(404, f"WO {wo_id} not found")

    def handle_get_logs(self, query):
        """Handle GET /api/health/logs - get system logs"""
        lines = int(query.get('lines', ['200'])[0])

        # Get logs from WO executor
        log_file = LOGS / "wo_executor.out.log"

        if log_file.exists():
            try:
                result = subprocess.run(
                    ['tail', '-n', str(lines), str(log_file)],
                    capture_output=True,
                    text=True,
                    timeout=5
                )
                log_lines = result.stdout.split('\n') if result.returncode == 0 else []
                self.send_json_response({'lines': log_lines})
            except Exception as e:
                self.send_json_response({'lines': [f"Error reading logs: {e}"]})
        else:
            self.send_json_response({'lines': ['No logs available']})

    def send_json_response(self, data):
        """Send JSON response"""
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_cors_headers()
        self.end_headers()
        self.wfile.write(json.dumps(data, indent=2).encode())

    def log_message(self, format, *args):
        """Override to reduce logging noise"""
        pass

def run_server(port=8767):
    """Run the API server"""
    server = HTTPServer(('127.0.0.1', port), APIHandler)
    print(f"🚀 Dashboard API server running on http://127.0.0.1:{port}")
    print(f"   - GET /api/wos - List all WOs")
    print(f"   - GET /api/wos/:id - Get WO details")
    print(f"   - GET /api/health/logs?lines=200 - Get system logs")
    server.serve_forever()

if __name__ == '__main__':
    run_server()
