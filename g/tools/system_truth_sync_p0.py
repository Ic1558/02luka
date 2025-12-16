#!/usr/bin/env python3
"""
system_truth_sync_p0.py

P0: Read-only system truth sync helper.

- อ่านสถานะจาก:
  - Sandbox health reports: g/sandbox/os_l0_l1/logs/liam_reports/*.json
  - Gateway v3 router telemetry: g/telemetry/gateway_v3_router.jsonl
  - Work Orders หลัก: bridge/outbox/CLC/WO-*.yaml

- สร้าง:
  - JSON summary (stdout หรือใช้ pipe ต่อ)
  - Markdown block ที่เอาไป paste ลง 02luka.md ได้เอง (script นี้จะไม่เขียนไฟล์)

Usage examples:

  # สรุปเต็ม (JSON + Markdown)
  python g/tools/system_truth_sync_p0.py

  # JSON อย่างเดียว
  python g/tools/system_truth_sync_p0.py --json

  # Markdown อย่างเดียว
  python g/tools/system_truth_sync_p0.py --md

  # โฟกัสเฉพาะ sandbox + gateway
  python g/tools/system_truth_sync_p0.py --mode core --md
"""

import argparse
import json
import sys
from dataclasses import dataclass, asdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional

try:
    import yaml  # type: ignore
except Exception:  # pragma: no cover
    yaml = None  # will handle later


# ---- Path helpers ----

def repo_root() -> Path:
    # This file: /02luka/g/tools/system_truth_sync_p0.py
    # parents[0] = tools, [1] = g, [2] = 02luka
    return Path(__file__).resolve().parents[2]


def safe_under(root: Path, p: Path) -> bool:
    """Return True if p is inside root (or equal)."""
    try:
        return p.resolve().is_relative_to(root.resolve())  # py3.11+
    except AttributeError:  # fallback
        rp = p.resolve()
        rr = root.resolve()
        return rp == rr or rr in rp.parents


# ---- Data models ----

@dataclass
class SandboxStatus:
    status: str  # "GREEN" | "RED" | "UNKNOWN"
    message: str
    latest_report: Optional[str]
    report_ts: Optional[str]


@dataclass
class GatewayStatus:
    telemetry_file: Optional[str]
    latest_event_ts: Optional[str]
    latest_level: Optional[str]
    latest_message: Optional[str]
    total_events: int


@dataclass
class WorkOrderStatus:
    id: str
    path: str
    status: Optional[str]
    priority: Optional[str]
    owner: Optional[str]
    title: Optional[str]


@dataclass
class TruthSyncSummary:
    generated_at: str
    version: str
    repo_root: str
    sandbox: SandboxStatus
    gateway_v3: GatewayStatus
    work_orders: List[WorkOrderStatus]


# ---- Loaders ----

def load_latest_sandbox_report(root: Path) -> SandboxStatus:
    reports_dir = root / "g" / "sandbox" / "os_l0_l1" / "logs" / "liam_reports"
    if not reports_dir.exists():
        return SandboxStatus(
            status="UNKNOWN",
            message="No sandbox health reports found",
            latest_report=None,
            report_ts=None,
        )

    json_files = sorted(
        reports_dir.glob("health_*.json"),
        key=lambda p: p.stat().st_mtime,
    )
    if not json_files:
        return SandboxStatus(
            status="UNKNOWN",
            message="No sandbox health reports found",
            latest_report=None,
            report_ts=None,
        )

    latest = json_files[-1]
    try:
        data = json.loads(latest.read_text())
    except Exception as e:
        return SandboxStatus(
            status="UNKNOWN",
            message=f"Failed to parse latest report: {e}",
            latest_report=str(latest.relative_to(root)),
            report_ts=None,
        )

    status = str(data.get("status", "UNKNOWN"))
    msg = str(data.get("message", "") or "").strip() or "No message"
    ts = str(data.get("ts", "") or None)

    return SandboxStatus(
        status=status,
        message=msg,
        latest_report=str(latest.relative_to(root)),
        report_ts=ts,
    )


def load_gateway_status(root: Path, limit: int = 2000) -> GatewayStatus:
    tel_path = root / "g" / "telemetry" / "gateway_v3_router.jsonl"
    if not tel_path.exists():
        return GatewayStatus(
            telemetry_file=None,
            latest_event_ts=None,
            latest_level=None,
            latest_message=None,
            total_events=0,
        )

    # Read lines (limit to last N for safety)
    try:
        lines = tel_path.read_text().splitlines()
    except Exception:
        return GatewayStatus(
            telemetry_file=str(tel_path.relative_to(root)),
            latest_event_ts=None,
            latest_level=None,
            latest_message="Failed to read telemetry file",
            total_events=0,
        )

    if not lines:
        return GatewayStatus(
            telemetry_file=str(tel_path.relative_to(root)),
            latest_event_ts=None,
            latest_level=None,
            latest_message="No telemetry events logged",
            total_events=0,
        )

    tail = lines[-limit:]
    latest_data = None
    for raw in reversed(tail):
        raw = raw.strip()
        if not raw:
            continue
        try:
            obj = json.loads(raw)
            latest_data = obj
            break
        except Exception:
            continue

    total_events = len(lines)

    if latest_data is None:
        return GatewayStatus(
            telemetry_file=str(tel_path.relative_to(root)),
            latest_event_ts=None,
            latest_level=None,
            latest_message="Failed to parse latest telemetry JSON",
            total_events=total_events,
        )

    return GatewayStatus(
        telemetry_file=str(tel_path.relative_to(root)),
        latest_event_ts=str(latest_data.get("ts", "") or None),
        latest_level=str(latest_data.get("level", "") or None),
        latest_message=str(latest_data.get("message", "") or None),
        total_events=total_events,
    )


def load_wo_yaml(path: Path) -> Dict[str, Any]:
    if yaml is None:
        return {}
    try:
        text = path.read_text()
        data = yaml.safe_load(text) or {}
        if not isinstance(data, dict):
            return {}
        return data
    except Exception:
        return {}


def extract_wo_status(root: Path) -> List[WorkOrderStatus]:
    """
    Focus on key WOs we care about right now.
    If a file is missing, still report it with status=None.
    """
    base = root / "bridge" / "outbox" / "CLC"

    ids = [
        "WO-20251113-SYSTEM-TRUTH-SYNC.yaml",
        "WO-20251206-GATEWAY-V3-CORE.yaml",
        "WO-20251206-SANDBOX-FIX-V1.yaml",
        "WO-20251206-LOCAL-AGENT-REVIEW-PHASE1.yaml",
        "WO-TEST-GATEWAY-V3.yaml",
        "WO-20251206-LAR-GITDROP-SAVECHAIN-V1.yaml",
    ]

    result: List[WorkOrderStatus] = []
    for fname in ids:
        p = base / fname
        if not safe_under(root, p):
            continue

        if not p.exists():
            result.append(
                WorkOrderStatus(
                    id=fname.replace(".yaml", ""),
                    path=str(p.relative_to(root)),
                    status=None,
                    priority=None,
                    owner=None,
                    title=None,
                )
            )
            continue

        data = load_wo_yaml(p)
        status = data.get("status")
        priority = data.get("priority")
        owner = data.get("owner") or data.get("assignee")
        title = data.get("title") or data.get("summary")

        result.append(
            WorkOrderStatus(
                id=fname.replace(".yaml", ""),
                path=str(p.relative_to(root)),
                status=str(status) if status is not None else None,
                priority=str(priority) if priority is not None else None,
                owner=str(owner) if owner is not None else None,
                title=str(title) if title is not None else None,
            )
        )

    return result


# ---- Summary + rendering ----

def build_summary(mode: str = "full") -> TruthSyncSummary:
    root = repo_root()

    sandbox = load_latest_sandbox_report(root)
    gateway = load_gateway_status(root)
    wo_list = extract_wo_status(root)

    now = datetime.now(timezone.utc).isoformat()

    if mode == "sandbox":
        # still include others, but focus is sandbox; consumer can ignore
        pass
    elif mode == "gateway":
        pass
    elif mode == "workorders":
        pass
    # "full" and others -> all included

    return TruthSyncSummary(
        generated_at=now,
        version="system_truth_sync_p0",
        repo_root=str(root),
        sandbox=sandbox,
        gateway_v3=gateway,
        work_orders=wo_list,
    )


def render_markdown(summary: TruthSyncSummary) -> str:
    sb = summary.sandbox
    gw = summary.gateway_v3

    lines: List[str] = []
    lines.append("<!-- SYSTEM_TRUTH_SYNC_P0_START -->")
    lines.append("")
    lines.append("## System Truth Snapshot (P0 - Read-Only)")
    lines.append("")
    lines.append(f"- Generated at (UTC): `{summary.generated_at}`")
    lines.append("")
    lines.append("### Sandbox OS L0/L1")
    lines.append(f"- Status: **{sb.status}**")
    lines.append(f"- Message: {sb.message}")
    if sb.latest_report:
        lines.append(f"- Latest report: `{sb.latest_report}`")
    if sb.report_ts:
        lines.append(f"- Report timestamp: `{sb.report_ts}`")
    lines.append("")
    lines.append("### Gateway v3 Router")
    if gw.telemetry_file:
        lines.append(f"- Telemetry file: `{gw.telemetry_file}`")
    else:
        lines.append("- Telemetry file: *(not found)*")
    lines.append(f"- Total events: {gw.total_events}")
    if gw.latest_event_ts:
        lines.append(f"- Latest event ts: `{gw.latest_event_ts}`")
    if gw.latest_level or gw.latest_message:
        lvl = gw.latest_level or "N/A"
        msg = gw.latest_message or "N/A"
        lines.append(f"- Latest: `{lvl}` - {msg}")
    lines.append("")
    lines.append("### Key Work Orders (Snapshot)")
    if not summary.work_orders:
        lines.append("- *(none found)*")
    else:
        for wo in summary.work_orders:
            status = wo.status or "unknown"
            prio = wo.priority or "-"
            owner = wo.owner or "-"
            title = wo.title or ""
            lines.append(
                f"- **{wo.id}** "
                f"(status: `{status}`, priority: `{prio}`, owner: `{owner}`)  "
                f"`{wo.path}`  "
                f"{title}"
            )
    lines.append("")
    lines.append("> Note: This block is generated by system_truth_sync_p0.py (read-only).")
    lines.append("> Apply updates to 02luka.md manually or via approved writer flow.")
    lines.append("")
    lines.append("<!-- SYSTEM_TRUTH_SYNC_P0_END -->")
    return "\n".join(lines)


# ---- CLI ----

def parse_args(argv: Optional[List[str]] = None) -> argparse.Namespace:
    p = argparse.ArgumentParser(
        prog="system_truth_sync_p0",
        description="Read-only system truth sync (sandbox + gateway + WOs).",
    )
    p.add_argument(
        "--mode",
        choices=["full", "sandbox", "gateway", "workorders", "core"],
        default="full",
        help="Scope of summary (default: full).",
    )
    p.add_argument(
        "--json",
        action="store_true",
        help="Print JSON summary only.",
    )
    p.add_argument(
        "--md",
        action="store_true",
        help="Print Markdown block only.",
    )
    p.add_argument(
        "--dry-run",
        action="store_true",
        help="No-op flag for future write modes; P0 is always read-only.",
    )
    return p.parse_args(argv)


def main(argv: Optional[List[str]] = None) -> int:
    args = parse_args(argv)
    mode = args.mode

    # For "core" we still build full summary; consumer can choose fields.
    summary = build_summary(mode="full" if mode == "core" else mode)

    json_obj = {
        "generated_at": summary.generated_at,
        "version": summary.version,
        "repo_root": summary.repo_root,
        "sandbox": asdict(summary.sandbox),
        "gateway_v3": asdict(summary.gateway_v3),
        "work_orders": [asdict(wo) for wo in summary.work_orders],
    }

    want_json = args.json
    want_md = args.md

    if not want_json and not want_md:
        # default: both, JSON then MD (separated)
        json.dump(json_obj, sys.stdout, ensure_ascii=False, indent=2)
        sys.stdout.write("\n\n")
        sys.stdout.write(render_markdown(summary))
        sys.stdout.write("\n")
        return 0

    if want_json:
        json.dump(json_obj, sys.stdout, ensure_ascii=False, indent=2)
        sys.stdout.write("\n")

    if want_md:
        if want_json:
            sys.stdout.write("\n")
        sys.stdout.write(render_markdown(summary))
        sys.stdout.write("\n")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
