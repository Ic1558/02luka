#!/usr/bin/env python3
"""Infra 20.x verification helper.

Generates consolidated JSON snapshots under hub/ for:
- MCP registry summary
- MCP health overview
- Linked health status bridge
- Telemetry consolidation report
- LaunchAgent self-check summary
- Delegation watchdog dry-run report
"""
from __future__ import annotations

import json
import os
import plistlib
import re
from collections import Counter
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, List, Optional

ROOT = Path(__file__).resolve().parents[1]
HUB_DIR = ROOT / "hub"
MCP_HEALTH_REPORT = ROOT / "reports" / "mcp_health" / "latest.md"
OPS_HEALTH_METRICS = ROOT / "metrics" / "ops_health.json"
TELEMETRY_MANIFEST = ROOT / "telemetry_unified" / "manifest.json"
TELEMETRY_LOG = ROOT / "telemetry_unified" / "unified.jsonl"
LAUNCHAGENT_DIR = ROOT / "LaunchAgents"
WO_INBOX = ROOT / "bridge" / "inbox" / "CLC"

Timestamp = datetime


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def ensure_hub_dir() -> None:
    HUB_DIR.mkdir(parents=True, exist_ok=True)


@dataclass
class MCPService:
    name: str
    primary_state: Optional[str] = None
    job_state: Optional[str] = None
    pid: Optional[int] = None
    last_exit_code: Optional[int] = None
    raw: Optional[List[str]] = None
    port: Optional[int] = None
    port_label: Optional[str] = None
    port_process: Optional[str] = None

    @property
    def status(self) -> str:
        if self.primary_state == "running" or self.job_state == "running":
            return "online"
        if self.job_state == "exited":
            return "offline"
        if self.primary_state:
            return self.primary_state
        return "unknown"

    def to_registry_dict(self) -> Dict[str, object]:
        data = {
            "name": self.name,
            "state": self.primary_state,
            "job_state": self.job_state,
            "status": self.status,
        }
        if self.pid is not None:
            data["pid"] = self.pid
        if self.last_exit_code is not None:
            data["last_exit_code"] = self.last_exit_code
        if self.port is not None:
            data["port"] = {
                "number": self.port,
                "label": self.port_label,
                "process": self.port_process,
            }
        if self.raw:
            data["raw"] = self.raw
        return data

    def to_health_dict(self) -> Dict[str, object]:
        data = self.to_registry_dict()
        data["details"] = {
            "primary_state": self.primary_state,
            "job_state": self.job_state,
            "pid": self.pid,
            "last_exit_code": self.last_exit_code,
        }
        return data


def parse_mcp_health() -> Dict[str, object]:
    text = MCP_HEALTH_REPORT.read_text(encoding="utf-8") if MCP_HEALTH_REPORT.exists() else ""
    lines = text.splitlines()

    services: Dict[str, MCPService] = {}
    network_lines: List[str] = []
    cursor_servers: List[str] = []

    current_section: Optional[str] = None
    section_buffer: List[str] = []

    def flush_section(name: Optional[str], buffer: List[str]) -> None:
        if not name or not buffer:
            return
        if name.startswith("com.02luka.mcp."):
            svc = services.setdefault(name, MCPService(name=name, raw=[]))
            svc.raw = [line.rstrip() for line in buffer if line.strip()]
            for raw in svc.raw:
                state_match = re.search(r"state = ([^\s]+)$", raw.strip())
                if state_match and "job state" not in raw:
                    value = state_match.group(1)
                    if svc.primary_state is None:
                        svc.primary_state = value
                    elif value == "running" and svc.primary_state != "running":
                        svc.primary_state = value
                job_state_match = re.search(r"job state = ([^\s]+)$", raw.strip())
                if job_state_match:
                    svc.job_state = job_state_match.group(1)
                pid_match = re.search(r"pid = (\d+)", raw)
                if pid_match:
                    svc.pid = int(pid_match.group(1))
                last_exit_match = re.search(r"last exit code = (\-?\d+)", raw)
                if last_exit_match:
                    svc.last_exit_code = int(last_exit_match.group(1))
        elif name == "Network Services":
            network_lines.extend(buffer)
        elif name == "Cursor Config":
            for raw in buffer:
                stripped = raw.strip()
                if stripped.startswith("- Servers") or stripped.startswith("Servers"):
                    continue
                parts = [seg.strip() for seg in stripped.split(",") if seg.strip()]
                if parts:
                    cursor_servers.extend(parts)

    for line in lines:
        if line.startswith("### "):
            flush_section(current_section, section_buffer)
            current_section = line[4:].strip()
            section_buffer = []
        else:
            section_buffer.append(line)
    flush_section(current_section, section_buffer)

    # Map network ports to services if possible
    port_pattern = re.compile(r"- Port (\d+) \(([^)]+)\):")
    current_port: Optional[int] = None
    current_label: Optional[str] = None
    for raw in network_lines:
        match = port_pattern.search(raw)
        if match:
            current_port = int(match.group(1))
            current_label = match.group(2)
            continue
        cleaned = raw.strip()
        if current_port is not None and cleaned:
            for svc in services.values():
                if svc.name.endswith(current_label.lower()):
                    svc.port = current_port
                    svc.port_label = current_label
                    svc.port_process = cleaned
            current_port = None
            current_label = None

    return {
        "services": services,
        "cursor_servers": cursor_servers,
        "raw_text": text,
    }


def write_json(path: Path, data: Dict[str, object]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def generate_mcp_registry(parsed: Dict[str, object]) -> Dict[str, object]:
    services: Dict[str, MCPService] = parsed["services"]
    registry = {
        "generated_at": utc_now(),
        "source": str(MCP_HEALTH_REPORT.relative_to(ROOT)) if MCP_HEALTH_REPORT.exists() else None,
        "service_count": len(services),
        "services": [svc.to_registry_dict() for svc in services.values()],
        "cursor_servers": parsed.get("cursor_servers", []),
    }
    return registry


def generate_mcp_health(parsed: Dict[str, object]) -> Dict[str, object]:
    services: Dict[str, MCPService] = parsed["services"]
    status_counter = Counter(svc.status for svc in services.values())
    overall = "healthy" if status_counter.get("online", 0) == len(services) and len(services) > 0 else "degraded"
    if not services:
        overall = "unknown"
    health = {
        "generated_at": utc_now(),
        "source": str(MCP_HEALTH_REPORT.relative_to(ROOT)) if MCP_HEALTH_REPORT.exists() else None,
        "overall_status": overall,
        "status_breakdown": status_counter,
        "services": [svc.to_health_dict() for svc in services.values()],
    }
    return health


def load_ops_health_summary() -> Dict[str, object]:
    if not OPS_HEALTH_METRICS.exists():
        return {}
    metrics = json.loads(OPS_HEALTH_METRICS.read_text(encoding="utf-8"))
    checks = metrics.get("checks", [])
    last_check = checks[-1] if checks else None
    failing = []
    if last_check:
        for endpoint, detail in last_check.get("endpoints", {}).items():
            if not detail.get("success"):
                failing.append({
                    "endpoint": endpoint,
                    "error": detail.get("error"),
                    "latency_ms": detail.get("latency"),
                })
    return {
        "summary": metrics.get("summary", {}),
        "checks_total": len(checks),
        "last_check": last_check,
        "failing_endpoints": failing,
    }


def generate_health_link(registry: Dict[str, object]) -> Dict[str, object]:
    ops = load_ops_health_summary()
    links: List[Dict[str, object]] = []
    for svc in registry.get("services", []):
        port_info = svc.get("port") or {}
        links.append({
            "service": svc.get("name"),
            "status": svc.get("status"),
            "port": port_info.get("number"),
            "port_label": port_info.get("label"),
        })
    if ops:
        links.append({
            "service": "ops_api",
            "status": "offline" if ops.get("failing_endpoints") else "online",
            "failing_endpoints": ops.get("failing_endpoints"),
            "last_check": ops.get("last_check", {}).get("timestamp"),
        })
    return {
        "generated_at": utc_now(),
        "sources": {
            "mcp_registry": {
                "file": registry.get("source"),
                "service_count": registry.get("service_count"),
            },
            "ops_health_metrics": {
                "file": str(OPS_HEALTH_METRICS.relative_to(ROOT)) if OPS_HEALTH_METRICS.exists() else None,
                "summary": ops.get("summary"),
                "checks_total": ops.get("checks_total"),
            },
        },
        "links": links,
    }


def load_multiline_jsonl(path: Path) -> List[Dict[str, object]]:
    if not path.exists():
        return []
    events: List[Dict[str, object]] = []
    buffer = ""
    depth = 0
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        stripped = raw_line.strip()
        if not stripped:
            continue
        depth += stripped.count("{") - stripped.count("}")
        buffer += stripped
        if depth == 0 and buffer:
            try:
                events.append(json.loads(buffer))
            except json.JSONDecodeError:
                pass
            buffer = ""
    if buffer:
        try:
            events.append(json.loads(buffer))
        except json.JSONDecodeError:
            pass
    return events


def generate_telemetry_consolidated() -> Dict[str, object]:
    manifest = json.loads(TELEMETRY_MANIFEST.read_text(encoding="utf-8")) if TELEMETRY_MANIFEST.exists() else {}
    events = load_multiline_jsonl(TELEMETRY_LOG)

    event_types = Counter(evt.get("event") for evt in events if evt.get("event"))
    latest_ts = None
    for evt in events:
        ts = evt.get("timestamp") or evt.get("ts")
        if ts:
            latest_ts = max(latest_ts, ts) if latest_ts else ts

    alert_candidates = []
    for evt in events:
        event_name = evt.get("event") or ""
        if "error" in event_name or evt.get("level") == "error" or evt.get("status") not in (None, "ok", "success"):
            alert_candidates.append({
                "event": event_name,
                "timestamp": evt.get("timestamp") or evt.get("ts"),
                "details": evt,
            })

    return {
        "generated_at": utc_now(),
        "manifest": manifest,
        "telemetry_file": str(TELEMETRY_LOG.relative_to(ROOT)) if TELEMETRY_LOG.exists() else None,
        "total_events": len(events),
        "event_types": event_types,
        "latest_timestamp": latest_ts,
        "alert_route_dry_run": alert_candidates[:5],
    }


def generate_launchagent_selfcheck() -> Dict[str, object]:
    agents_summary: List[Dict[str, object]] = []
    for plist_path in sorted(LAUNCHAGENT_DIR.glob("*.plist")):
        try:
            data = plistlib.loads(plist_path.read_bytes())
        except Exception:
            data = {}
        label = data.get("Label")
        program = data.get("ProgramArguments") or data.get("Program")
        keepalive = data.get("KeepAlive")
        working_dir = data.get("WorkingDirectory")
        program_status = "missing"
        if isinstance(program, list) and program:
            target = Path(os.path.expandvars(os.path.expanduser(program[0])))
            program_status = "exists" if target.exists() else "missing"
        elif isinstance(program, str):
            target = Path(os.path.expandvars(os.path.expanduser(program)))
            program_status = "exists" if target.exists() else "missing"
        agents_summary.append({
            "file": str(plist_path.relative_to(ROOT)),
            "label": label,
            "keepalive": keepalive,
            "program": program,
            "program_status": program_status,
            "working_directory": working_dir,
            "status": "ok" if keepalive else "warn",
        })

    checks = []
    critical_files = [
        ROOT / "agent_listener.py",
        ROOT / "agent_router.py",
        ROOT / "scripts" / "smoke.sh",
    ]
    for path in critical_files:
        status = path.exists()
        checks.append({
            "path": str(path.relative_to(ROOT)),
            "status": "ok" if status else "missing",
        })

    return {
        "generated_at": utc_now(),
        "launchagents": agents_summary,
        "checks": checks,
    }


def generate_delegation_watchdog() -> Dict[str, object]:
    work_orders: List[Dict[str, object]] = []
    if WO_INBOX.exists():
        for wo in sorted(WO_INBOX.glob("WO-*.json")):
            stat = wo.stat()
            work_orders.append({
                "file": str(wo.relative_to(ROOT)),
                "size_bytes": stat.st_size,
                "modified": datetime.fromtimestamp(stat.st_mtime, tz=timezone.utc).isoformat(),
            })
        for wo in sorted(WO_INBOX.glob("WO-*.md")):
            stat = wo.stat()
            work_orders.append({
                "file": str(wo.relative_to(ROOT)),
                "size_bytes": stat.st_size,
                "modified": datetime.fromtimestamp(stat.st_mtime, tz=timezone.utc).isoformat(),
            })

    dry_run = {
        "result": "no_work_orders_found",
    }
    if work_orders:
        candidate = work_orders[0]
        dry_run = {
            "action": "drop",
            "target": candidate["file"],
            "status": "simulated",
            "timestamp": utc_now(),
        }

    return {
        "generated_at": utc_now(),
        "work_orders": work_orders,
        "dry_run": dry_run,
    }


def main() -> None:
    ensure_hub_dir()
    parsed_mcp = parse_mcp_health()

    registry = generate_mcp_registry(parsed_mcp)
    write_json(HUB_DIR / "mcp_registry.json", registry)

    health = generate_mcp_health(parsed_mcp)
    write_json(HUB_DIR / "mcp_health.json", health)

    health_link = generate_health_link(registry)
    write_json(HUB_DIR / "health_link.json", health_link)

    telemetry = generate_telemetry_consolidated()
    write_json(HUB_DIR / "telemetry_consolidated.json", telemetry)

    selfcheck = generate_launchagent_selfcheck()
    write_json(HUB_DIR / "selfcheck_report.json", selfcheck)

    delegation = generate_delegation_watchdog()
    write_json(HUB_DIR / "delegation_watchdog.json", delegation)

    print("Generated Infra 20.x snapshots:")
    for name in [
        "mcp_registry.json",
        "mcp_health.json",
        "health_link.json",
        "telemetry_consolidated.json",
        "selfcheck_report.json",
        "delegation_watchdog.json",
    ]:
        print(f"  - hub/{name}")


if __name__ == "__main__":
    main()
