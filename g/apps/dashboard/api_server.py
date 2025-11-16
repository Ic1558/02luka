#!/usr/bin/env python3
"""
Dashboard API Server - Serves WO data and logs
Runs alongside the static HTTP server on port 8767
"""

import glob
import json
import os
import re
import subprocess
from collections import deque
from datetime import datetime
from http.server import HTTPServer, BaseHTTPRequestHandler
from pathlib import Path
from urllib.parse import parse_qs, urlparse

# Paths
ROOT = Path.home() / "02luka"
BRIDGE = ROOT / "bridge"
TELEMETRY = ROOT / "telemetry"
LOGS = ROOT / "logs"


class WOHistoryBuilder:
    """Builds a normalized timeline/history view for work orders."""

    STATUS_MAP = {
        'open': 'queued',
        'inprogress': 'running',
        'in_progress': 'running',
        'running': 'running',
        'queued': 'queued',
        'complete': 'success',
        'completed': 'success',
        'success': 'success',
        'ok': 'success',
        'failed': 'failed',
        'failure': 'failed',
        'error': 'failed',
        'cancelled': 'dropped',
        'canceled': 'dropped',
        'dropped': 'dropped',
        'timeout': 'timeout',
        'timed_out': 'timeout'
    }

    FOLLOWUP_CANDIDATES = (
        ROOT / 'followup' / 'followup.json',
        ROOT / 'apps' / 'dashboard' / 'data' / 'followup.json',
        ROOT / 'g' / 'apps' / 'dashboard' / 'data' / 'followup.json',
    )

    def __init__(self, root=ROOT, logs_dir=LOGS):
        self.root = Path(root)
        self.state_dir = self.root / 'followup' / 'state'
        self.logs_dir = Path(logs_dir)
        self.mls_file = self.root / 'g' / 'knowledge' / 'mls_lessons.jsonl'

    def build_history(self, collector_wos, tail_lines=50):
        """Build a sorted history list from all available sources."""
        entries = {}

        for wo in collector_wos:
            self._merge_entry(entries, wo, 'collector')

        for state_entry in self._load_state_files():
            self._merge_entry(entries, state_entry, 'state')

        for followup_entry in self._load_followup_items():
            self._merge_entry(entries, followup_entry, 'followup')

        mls_map = self._load_mls_map()

        normalized = []
        for wo_id, entry in entries.items():
            if mls_map.get(wo_id):
                entry['mls_lessons'] = mls_map[wo_id]
                tags = entry.get('mls_tags', [])
                for lesson in mls_map[wo_id]:
                    tags.extend(lesson.get('tags') or [])
                entry['mls_tags'] = sorted({tag for tag in tags if tag})
            else:
                entry['mls_lessons'] = []
                entry['mls_tags'] = []

            entry['log_tail'] = self._ensure_log_tail(entry, tail_lines)
            entry['status'] = self._normalize_status(entry.get('status'))
            entry['agent'] = entry.get('agent') or entry.get('owner') or 'unknown'
            entry['type'] = entry.get('type') or self._infer_type(entry)
            entry['summary'] = self._infer_summary(entry)
            entry['started_at'] = self._normalize_timestamp(
                entry.get('started_at')
                or entry.get('created_at')
                or entry.get('ts_create')
            )
            entry['finished_at'] = self._normalize_timestamp(
                entry.get('finished_at')
                or entry.get('completed_at')
                or entry.get('ts_update')
            )
            entry['duration_seconds'] = self._compute_duration(entry)
            entry['timeline_segments'] = self._build_segments(entry)
            entry['sources'] = sorted(set(entry.get('sources', [])))

            normalized.append(entry)

        normalized.sort(key=lambda item: self._sort_key(item), reverse=True)
        return normalized

    def _merge_entry(self, entries, data, source):
        wo_id = (data.get('id') or data.get('wo_id') or data.get('work_order_id'))
        if not wo_id:
            return

        wo_id = str(wo_id).strip()
        if not wo_id:
            return

        normalized = {
            'id': wo_id,
            'status': data.get('status'),
            'agent': data.get('agent') or data.get('owner'),
            'type': data.get('type'),
            'source': data.get('source') or source,
            'summary': data.get('summary') or data.get('goal') or data.get('description'),
            'started_at': data.get('started_at'),
            'finished_at': data.get('finished_at'),
            'created_at': data.get('created_at'),
            'completed_at': data.get('completed_at'),
            'ts_create': data.get('ts_create'),
            'ts_update': data.get('ts_update'),
            'duration_ms': data.get('duration_ms'),
            'log_tail': data.get('log_tail') if isinstance(data.get('log_tail'), list) else None,
            'sources': [source],
        }

        existing = entries.get(wo_id)
        if not existing:
            entries[wo_id] = normalized
            return

        for key, value in normalized.items():
            if key == 'sources':
                continue
            if value and not existing.get(key):
                existing[key] = value

        existing.setdefault('sources', []).append(source)

    def _load_state_files(self):
        if not self.state_dir.exists():
            return []

        records = []
        for path in sorted(self.state_dir.glob('*.json')):
            try:
                with open(path, 'r', encoding='utf-8') as handle:
                    payload = json.load(handle)
                    records.append(payload)
            except Exception as exc:
                print(f"Warning: unable to parse state file {path}: {exc}")
        return records

    def _load_followup_items(self):
        for candidate in self.FOLLOWUP_CANDIDATES:
            if candidate.exists():
                try:
                    with open(candidate, 'r', encoding='utf-8') as handle:
                        payload = json.load(handle)
                except Exception as exc:
                    print(f"Warning: unable to read followup data {candidate}: {exc}")
                    return []
                items = payload.get('items') or payload.get('work_orders') or []
                return items if isinstance(items, list) else []
        return []

    def _load_mls_map(self):
        if not self.mls_file.exists():
            return {}

        try:
            with open(self.mls_file, 'r', encoding='utf-8') as handle:
                content = handle.read()
        except Exception as exc:
            print(f"Warning: unable to read MLS ledger: {exc}")
            return {}

        decoder = json.JSONDecoder()
        idx = 0
        length = len(content)
        entries = {}

        while idx < length:
            while idx < length and content[idx].isspace():
                idx += 1
            if idx >= length:
                break
            try:
                payload, offset = decoder.raw_decode(content, idx)
            except json.JSONDecodeError:
                break
            idx = offset

            wo_id = payload.get('related_wo') or payload.get('wo_id')
            if not wo_id:
                continue

            lesson = {
                'id': payload.get('id'),
                'type': payload.get('type', 'note'),
                'title': payload.get('title') or (payload.get('description') or '')[:140],
                'tags': payload.get('tags') or [],
                'summary': payload.get('description') or '',
            }
            entries.setdefault(wo_id, []).append(lesson)

        return entries

    def _ensure_log_tail(self, entry, limit):
        if entry.get('log_tail'):
            return entry['log_tail'][-limit:]
        return self._read_log_tail(entry['id'], limit)

    def _read_log_tail(self, wo_id, limit):
        pattern = str(self.logs_dir / f"wo_execution_{wo_id}_*.log")
        for candidate in sorted(glob.glob(pattern), reverse=True):
            try:
                with open(candidate, 'r', encoding='utf-8', errors='replace') as handle:
                    buffer = deque(handle, maxlen=limit)
                return [line.rstrip('\n') for line in buffer]
            except OSError:
                continue
        return []

    def _normalize_timestamp(self, value):
        if not value:
            return None
        if isinstance(value, (int, float)):
            try:
                return datetime.fromtimestamp(value).isoformat()
            except Exception:
                return None
        if isinstance(value, datetime):
            return value.isoformat()
        text = str(value).strip()
        for fmt in ('%Y-%m-%d %H:%M:%S', '%Y-%m-%dT%H:%M:%S', '%Y-%m-%dT%H:%M:%S.%fZ'):
            try:
                return datetime.strptime(text[:len(fmt)], fmt).isoformat()
            except Exception:
                continue
        try:
            return datetime.fromisoformat(text.replace('Z', '+00:00')).isoformat()
        except ValueError:
            return text

    def _compute_duration(self, entry):
        if entry.get('duration_ms'):
            try:
                return round(entry['duration_ms'] / 1000, 2)
            except Exception:
                pass
        start = self._parse_datetime(entry.get('started_at'))
        end = self._parse_datetime(entry.get('finished_at'))
        if start and end:
            return round((end - start).total_seconds(), 2)
        return None

    def _parse_datetime(self, value):
        if not value:
            return None
        if isinstance(value, datetime):
            return value
        try:
            return datetime.fromisoformat(str(value).replace('Z', '+00:00'))
        except ValueError:
            return None

    def _build_segments(self, entry):
        segments = []
        if entry.get('started_at'):
            segments.append({'label': 'Started', 'value': entry['started_at']})
        if entry.get('finished_at'):
            segments.append({'label': 'Finished', 'value': entry['finished_at']})
        if entry.get('duration_seconds'):
            segments.append({'label': 'Duration', 'value': f"{entry['duration_seconds']}s"})
        return segments

    def _infer_summary(self, entry):
        for key in ('summary', 'goal', 'description', 'notes', 'title'):
            if entry.get(key):
                return entry[key]
        return 'Work order'

    def _infer_type(self, entry):
        if entry.get('source'):
            return entry['source']
        tags = entry.get('tags') or entry.get('mls_tags') or []
        if tags:
            return tags[0]
        wo_id = entry.get('id', '')
        if isinstance(wo_id, str) and 'fix' in wo_id.lower():
            return 'fix'
        return 'operation'

    def _normalize_status(self, status):
        if not status:
            return 'unknown'
        key = str(status).lower()
        return self.STATUS_MAP.get(key, key)

    def _sort_key(self, entry):
        return (
            entry.get('finished_at')
            or entry.get('started_at')
            or entry.get('ts_update')
            or entry.get('ts_create')
            or entry.get('id')
        )

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
    history_builder = WOHistoryBuilder()

    def do_GET(self):
        """Handle GET requests"""
        parsed = urlparse(self.path)
        path = parsed.path
        query = parse_qs(parsed.query)

        if path == '/api/wos':
            self.handle_list_wos(query)
        elif path == '/api/wos/history':
            self.handle_list_wos_history(query)
        elif path.startswith('/api/wos/'):
            wo_id = path.split('/')[-1]
            self.handle_get_wo(wo_id, query)
        elif path == '/api/wos/history':
            self.handle_wo_history(query)
        elif path == '/api/services':
            self.handle_list_services(query)
        elif path == '/api/mls':
            self.handle_list_mls(query)
        elif path == '/api/health/logs':
            self.handle_get_logs(query)
        elif path == '/api/reality/snapshot':
            self.handle_reality_snapshot(query)
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

    def handle_list_wos_history(self, query):
        """Handle GET /api/wos/history - normalized WO history view."""
        # Refresh WO list
        self.collector.collect_all()

        wos = self.collector.wos or []

        status_filter = query.get('status', [''])[0]
        statuses = []
        if status_filter:
            statuses = [s.strip().lower() for s in status_filter.split(',') if s.strip()]
        status_set = set(statuses)

        agent_filter = query.get('agent', [''])[0].strip().lower()

        limit_raw = query.get('limit', [''])[0]
        limit_value = 100
        if limit_raw:
            try:
                limit_value = max(1, min(1000, int(limit_raw)))
            except (TypeError, ValueError):
                limit_value = 100

        include_mls = query.get('include_mls', ['0'])[0] == '1'

        mls_by_wo = {}
        if include_mls:
            try:
                mls_entries = self._load_mls_entries()
                for entry in mls_entries:
                    wo_id = entry.get('related_wo')
                    if not wo_id:
                        continue

                    bucket = mls_by_wo.setdefault(wo_id, {
                        'total': 0,
                        'solutions': 0,
                        'failures': 0,
                        'patterns': 0,
                        'improvements': 0,
                    })

                    bucket['total'] += 1
                    entry_type = entry.get('type')
                    if entry_type in bucket:
                        bucket[entry_type] += 1
            except Exception as exc:
                print(f"Warning: failed to load MLS entries for timeline: {exc}")

        def normalize(wo):
            started_at = wo.get('started_at')
            finished_at = wo.get('finished_at') or wo.get('completed_at')
            duration = None
            if started_at and finished_at:
                try:
                    start_dt = datetime.fromisoformat(started_at.replace('Z', '+00:00'))
                    finish_dt = datetime.fromisoformat(finished_at.replace('Z', '+00:00'))
                    duration = int((finish_dt - start_dt).total_seconds())
                except Exception:
                    duration = None

            item = {
                'id': wo.get('id'),
                'status': wo.get('status'),
                'type': wo.get('type'),
                'agent': wo.get('agent') or wo.get('runner'),
                'started_at': started_at,
                'finished_at': finished_at,
                'created_at': wo.get('created_at') or wo.get('id'),
                'duration_sec': duration,
                'summary': wo.get('summary') or wo.get('title'),
                'log_tail': wo.get('log_tail'),
                'related_pr': wo.get('related_pr'),
                'tags': wo.get('tags', []),
            }

            if include_mls and item['id'] in mls_by_wo:
                item['mls_summary'] = mls_by_wo[item['id']]

            return item

        items = []
        for wo in wos:
            if status_set:
                status_value = str(wo.get('status') or '').lower()
                if status_value not in status_set:
                    continue

            if agent_filter:
                agent_value = str(wo.get('agent') or wo.get('runner') or '').lower()
                if agent_value != agent_filter:
                    continue

            items.append(normalize(wo))

        items_sorted = sorted(
            items,
            key=lambda w: w.get('started_at') or w.get('created_at') or w.get('id'),
            reverse=True
        )

        if limit_value > 0:
            items_sorted = items_sorted[:limit_value]

        self.send_json_response({
            'items': items_sorted,
            'summary': {
                'total': len(items_sorted),
                'status_counts': {
                    'success': len([i for i in items_sorted if i['status'] == 'success']),
                    'failed': len([i for i in items_sorted if i['status'] == 'failed']),
                    'running': len([i for i in items_sorted if i['status'] == 'running']),
                    'queued': len([i for i in items_sorted if i['status'] == 'queued']),
                }
            }
        })

    def _build_wo_timeline(self, wo):
        """Build a derived timeline for a work order from timestamps and log tail."""
        events = []

        created = wo.get('created_at') or wo.get('id')
        if created:
            events.append({'ts': created, 'type': 'created', 'label': 'WO created'})

        if wo.get('started_at'):
            events.append({'ts': wo['started_at'], 'type': 'started', 'label': 'Execution started'})

        if wo.get('finished_at'):
            events.append({
                'ts': wo['finished_at'],
                'type': 'finished',
                'label': 'Execution finished',
                'status': wo.get('status')
            })

        log_tail = wo.get('log_tail')
        if isinstance(log_tail, list):
            for line in log_tail:
                text = line.strip()
                if not text:
                    continue
                if 'ERROR' in text:
                    events.append({'ts': None, 'type': 'error', 'label': text[:200]})
                elif 'STATE:' in text:
                    events.append({'ts': None, 'type': 'state', 'label': text[:200]})

        events.sort(key=lambda e: (e['ts'] is None, e['ts'] or ''))
        return events

    def handle_get_wo(self, wo_id, query):
        """Handle GET /api/wos/:id - get WO details"""
        # Refresh WO list
        self.collector.collect_all()

        wo = self.collector.get_wo_by_id(wo_id)

        if wo:
            # Add log tail if requested
            if 'tail' in query:
                try:
                    lines = int(query['tail'][0])
                except (ValueError, TypeError):
                    lines = 200
                if wo.get('log_path'):
                    wo['log_tail'] = self.collector._get_log_tail(wo['log_path'], lines)

            timeline_flag = query.get('timeline', ['0'])[0]
            if timeline_flag == '1':
                try:
                    wo['timeline'] = self._build_wo_timeline(wo)
                except Exception as e:
                    print(f"Warning: failed to build timeline for WO {wo_id}: {e}")

            self.send_json_response(wo)
        else:
            self.send_error(404, f"WO {wo_id} not found")

    def handle_wo_history(self, query):
        """Handle GET /api/wos/history - unified timeline view"""
        self.collector.collect_all()

        limit = query.get('limit', [''])
        try:
            limit = int(limit[0]) if limit and limit[0] else None
        except ValueError:
            limit = None

        tail_param = query.get('tail', ['50'])
        try:
            tail_lines = max(5, min(500, int(tail_param[0])))
        except (ValueError, TypeError):
            tail_lines = 50

        history = self.history_builder.build_history(self.collector.wos, tail_lines=tail_lines)

        status_filter = query.get('status', [''])[0]
        if status_filter:
            statuses = {value.strip().lower() for value in status_filter.split(',') if value.strip()}
            history = [entry for entry in history if entry.get('status', '').lower() in statuses]

        agent_filter = query.get('agent', [''])[0]
        if agent_filter:
            agents = {value.strip().lower() for value in agent_filter.split(',') if value.strip()}
            history = [entry for entry in history if entry.get('agent', '').lower() in agents]

        type_filter = query.get('type', [''])[0]
        if type_filter:
            types = {value.strip().lower() for value in type_filter.split(',') if value.strip()}
            history = [entry for entry in history if entry.get('type', '').lower() in types]

        if limit:
            history = history[:limit]

        self.send_json_response(history)

    def handle_list_services(self, query):
        """Handle GET /api/services - list all 02luka LaunchAgent services"""
        try:
            # Run launchctl list and filter for 02luka services
            result = subprocess.run(
                ['launchctl', 'list'],
                capture_output=True,
                text=True,
                timeout=5
            )

            if result.returncode != 0:
                raise Exception(f"launchctl failed: {result.stderr}")

            # Parse launchctl output
            services = []
            lines = result.stdout.strip().split('\n')[1:]  # Skip header

            for line in lines:
                parts = line.split('\t')
                if len(parts) < 3:
                    continue

                pid = parts[0].strip()
                status_code = parts[1].strip()
                label = parts[2].strip()

                # Only include 02luka services
                if '02luka' not in label.lower():
                    continue

                # Determine status
                if pid == '-':
                    status = 'stopped'
                elif status_code != '0' and status_code != '-':
                    status = 'failed'
                else:
                    # Check if it's on-demand (WatchPaths trigger)
                    status = 'running'

                service = {
                    'label': label,
                    'pid': int(pid) if pid.isdigit() else None,
                    'status': status,
                    'exit_code': int(status_code) if status_code.isdigit() else None,
                    'type': self._get_service_type(label)
                }

                services.append(service)

            # Filter by status if requested
            status_filter = query.get('status', [''])[0]
            if status_filter:
                services = [s for s in services if s['status'] == status_filter]

            # Sort by label
            services.sort(key=lambda s: s['label'])

            # Add summary
            response = {
                'services': services,
                'summary': {
                    'total': len(services),
                    'running': len([s for s in services if s['status'] == 'running']),
                    'stopped': len([s for s in services if s['status'] == 'stopped']),
                    'failed': len([s for s in services if s['status'] == 'failed'])
                }
            }

            self.send_json_response(response)

        except subprocess.TimeoutExpired:
            self.send_error(500, "launchctl command timed out")
        except Exception as e:
            self.send_error(500, f"Failed to get services: {str(e)}")

    def _get_service_type(self, label):
        """Determine service type from label"""
        label_lower = label.lower()
        if 'bridge' in label_lower or 'telegram' in label_lower:
            return 'bridge'
        elif 'worker' in label_lower or 'processor' in label_lower:
            return 'worker'
        elif 'autopilot' in label_lower or 'scanner' in label_lower:
            return 'automation'
        elif 'health' in label_lower or 'watchdog' in label_lower:
            return 'monitoring'
        else:
            return 'other'

    def handle_list_mls(self, query):
        """Handle GET /api/mls - list all MLS lessons"""
        try:
            raw_entries = self._load_mls_entries()
            if not raw_entries:
                self.send_json_response({'entries': [], 'summary': {'total': 0, 'solutions': 0, 'failures': 0, 'patterns': 0, 'improvements': 0}})
                return

            entries = []
            for entry in raw_entries:
                entries.append({
                    'id': entry.get('id', 'MLS-UNKNOWN'),
                    'type': entry.get('type', 'other'),
                    'title': entry.get('title', 'Untitled'),
                    'details': entry.get('description', ''),
                    'context': entry.get('context', ''),
                    'time': entry.get('timestamp', ''),
                    'related_wo': entry.get('related_wo'),
                    'related_session': entry.get('related_session'),
                    'tags': entry.get('tags', []),
                    'verified': entry.get('verified', False),
                    'score': entry.get('usefulness_score', 0)
                })

            # Filter by type if requested
            type_filter = query.get('type', [''])[0]
            filtered_entries = entries
            if type_filter:
                filtered_entries = [e for e in entries if e['type'] == type_filter]

            # Filter by related WO id if requested
            wo_filter = query.get('wo_id', [''])[0]
            if wo_filter:
                filtered_entries = [
                    e for e in filtered_entries
                    if (e.get('related_wo') or '') == wo_filter
                ]

            # Sort by timestamp descending (newest first)
            filtered_entries.sort(key=lambda e: e['time'], reverse=True)

            # Calculate summary from all entries
            summary = {
                'total': len(entries),
                'solutions': len([e for e in entries if e['type'] == 'solution']),
                'failures': len([e for e in entries if e['type'] == 'failure']),
                'patterns': len([e for e in entries if e['type'] == 'pattern']),
                'improvements': len([e for e in entries if e['type'] == 'improvement'])
            }

            response = {
                'entries': filtered_entries,
                'summary': summary
            }

            self.send_json_response(response)

        except Exception as e:
            print(f"Error reading MLS lessons: {e}")
            self.send_error(500, f"Failed to read MLS lessons: {str(e)}")

    def _load_mls_entries(self):
        """Internal helper: read MLS lessons JSONL and return raw entries."""
        mls_file = ROOT / "g" / "knowledge" / "mls_lessons.jsonl"
        if not mls_file.exists():
            return []

        try:
            with open(mls_file, 'r') as handle:
                content = handle.read().strip()
        except Exception as exc:
            print(f"Warning: failed to read MLS file: {exc}")
            return []

        if not content:
            return []

        parts = content.split('}\n{')
        json_objects = []
        for index, part in enumerate(parts):
            if index == 0:
                json_str = part + '}'
            elif index == len(parts) - 1:
                json_str = '{' + part
            else:
                json_str = '{' + part + '}'
            json_objects.append(json_str)

        entries = []
        for json_str in json_objects:
            try:
                entries.append(json.loads(json_str))
            except json.JSONDecodeError as exc:
                print(f"Warning: skipping invalid MLS JSON object: {exc}")
                continue

        return entries

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

    def _read_reality_advisory(self):
        """Read the latest Reality Hooks advisory summary if available."""
        advisory = {
            "deployment": {"status": "unknown"},
            "save_sh": {"status": "unknown"},
            "orchestrator": {"status": "unknown"},
        }

        latest = LOGS / "reality_hooks_advisory_latest.md"
        if not latest.exists():
            return advisory

        try:
            statuses = []
            with open(latest, 'r', encoding='utf-8') as handle:
                for raw_line in handle:
                    line = raw_line.strip()
                    if line.startswith("- Advisory: **"):
                        parts = line.split("**")
                        if len(parts) >= 3:
                            statuses.append(parts[1].strip())
                        if len(statuses) >= 3:
                            break

            keys = ["deployment", "save_sh", "orchestrator"]
            for key, status in zip(keys, statuses):
                if status:
                    advisory[key]["status"] = status
        except Exception as exc:
            print(f"Error reading Reality advisory: {exc}")

        return advisory

    def handle_reality_snapshot(self, query):
        """Handle GET /api/reality/snapshot - return latest reality hooks snapshot"""
        try:
            base_patterns = [
                LOGS.parent / "reality_hooks_snapshot_*.json",
                LOGS.parent / "g" / "reports" / "system" / "reality_hooks_snapshot_*.json",
            ]

            snapshot_files = []
            for pattern in base_patterns:
                snapshot_files.extend(glob.glob(str(pattern)))
                if snapshot_files:
                    break

            include_advisory = query.get('advisory', ['0'])[0] == '1'

            if not snapshot_files:
                response = {
                    "status": "no_snapshot",
                    "snapshot_path": None,
                    "data": None,
                }
                if include_advisory:
                    response["advisory"] = self._read_reality_advisory()
                self.send_json_response(response)
                return

            latest_file = max(snapshot_files)
            with open(latest_file, 'r', encoding='utf-8') as handle:
                try:
                    data = json.load(handle)
                except json.JSONDecodeError:
                    response = {
                        "status": "error",
                        "snapshot_path": latest_file,
                        "data": None,
                        "error": "invalid_json",
                    }
                    if include_advisory:
                        response["advisory"] = self._read_reality_advisory()
                    self.send_json_response(response)
                    return

            response = {
                "status": "ok",
                "snapshot_path": latest_file,
                "data": data,
            }

            if include_advisory:
                response["advisory"] = self._read_reality_advisory()

            self.send_json_response(response)

        except Exception as exc:
            print(f"Error reading Reality Hooks snapshot: {exc}")
            self.send_error(500, f"Failed to read Reality Hooks snapshot: {str(exc)}")

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
    print(f"   - GET /api/wos/history - Unified timeline view")
    print(f"   - GET /api/services - List all 02luka services (v2.2.0)")
    print(f"   - GET /api/services?status=stopped - Filter services by status")
    print(f"   - GET /api/mls - List all MLS lessons (v2.2.0)")
    print(f"   - GET /api/mls?type=solution - Filter MLS by type")
    print(f"   - GET /api/health/logs?lines=200 - Get system logs")
    server.serve_forever()

if __name__ == '__main__':
    run_server()
