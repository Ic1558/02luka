#!/usr/bin/env python3
"""
system_truth_sync_p1.py

P1: Writable system truth sync helper (sandbox-safe).
- Generates JSON + Markdown (same inputs as P0).
- Default is dry-run: prints content, no file writes.
- --apply updates 02luka.md inside the managed marker block only, and creates a timestamped backup.
- Refuses to apply if markers are missing.
- Prints a small diff summary between current block and rendered block.
"""

import argparse
import difflib
import json
import sys
from dataclasses import dataclass, asdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

try:
    import yaml  # type: ignore
except Exception:  # pragma: no cover
    yaml = None


MARKER_START = "<!-- SYSTEM_TRUTH_SYNC_P1_START -->"
MARKER_END = "<!-- SYSTEM_TRUTH_SYNC_P1_END -->"


# ---- Path helpers ----

def repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def safe_under(root: Path, p: Path) -> bool:
    try:
        return p.resolve().is_relative_to(root.resolve())  # py3.11+
    except AttributeError:
        rp = p.resolve()
        rr = root.resolve()
        return rp == rr or rr in rp.parents


# ---- Data models ----

@dataclass
class SandboxStatus:
    status: str
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


# ---- Loaders (same as P0) ----

def load_latest_sandbox_report(root: Path) -> SandboxStatus:
    reports_dir = root / "g" / "sandbox" / "os_l0_l1" / "logs" / "liam_reports"
    if not reports_dir.exists():
        return SandboxStatus("UNKNOWN", "No sandbox health reports found", None, None)

    json_files = sorted(reports_dir.glob("health_*.json"), key=lambda p: p.stat().st_mtime)
    if not json_files:
        return SandboxStatus("UNKNOWN", "No sandbox health reports found", None, None)

    latest = json_files[-1]
    try:
        data = json.loads(latest.read_text())
    except Exception as e:
        return SandboxStatus("UNKNOWN", f"Failed to parse latest report: {e}", str(latest.relative_to(root)), None)

    status = str(data.get("status", "UNKNOWN"))
    msg = str(data.get("message", "") or "").strip() or "No message"
    ts = str(data.get("ts", "") or None)

    return SandboxStatus(status=status, message=msg, latest_report=str(latest.relative_to(root)), report_ts=ts)


def load_gateway_status(root: Path, limit: int = 2000) -> GatewayStatus:
    tel_path = root / "g" / "telemetry" / "gateway_v3_router.jsonl"
    if not tel_path.exists():
        return GatewayStatus(None, None, None, None, 0)

    try:
        lines = tel_path.read_text().splitlines()
    except Exception:
        return GatewayStatus(str(tel_path.relative_to(root)), None, None, "Failed to read telemetry file", 0)

    if not lines:
        return GatewayStatus(str(tel_path.relative_to(root)), None, None, "No telemetry events logged", 0)

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
        return GatewayStatus(str(tel_path.relative_to(root)), None, None, "Failed to parse latest telemetry JSON", total_events)

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
        return data if isinstance(data, dict) else {}
    except Exception:
        return {}


def extract_wo_status(root: Path) -> List[WorkOrderStatus]:
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
            result.append(WorkOrderStatus(fname.replace(".yaml", ""), str(p.relative_to(root)), None, None, None, None))
            continue
        data = load_wo_yaml(p)
        status = data.get("status")
        priority = data.get("priority")
        owner = data.get("owner") or data.get("assignee")
        title = data.get("title") or data.get("summary")
        result.append(
            WorkOrderStatus(
                fname.replace(".yaml", ""),
                str(p.relative_to(root)),
                str(status) if status is not None else None,
                str(priority) if priority is not None else None,
                str(owner) if owner is not None else None,
                str(title) if title is not None else None,
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

    if mode not in {"full", "sandbox", "gateway", "workorders", "core"}:
        mode = "full"

    return TruthSyncSummary(
        generated_at=now,
        version="system_truth_sync_p1",
        repo_root=str(root),
        sandbox=sandbox,
        gateway_v3=gateway,
        work_orders=wo_list,
    )


def render_markdown(summary: TruthSyncSummary) -> str:
    sb = summary.sandbox
    gw = summary.gateway_v3
    lines: List[str] = []
    lines.append(MARKER_START)
    lines.append("")
    lines.append("## System Truth Snapshot (P1 - Writable)")
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
    lines.append("> Managed by system_truth_sync_p1.py --apply (sandbox, append-only log inferred).")
    lines.append(MARKER_END)
    return "\n".join(lines)


# ---- Apply helpers ----

def load_target(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def find_block(text: str) -> Tuple[List[str], int, int, bool]:
    lines = text.splitlines()
    start = end = -1
    for idx, line in enumerate(lines):
        if MARKER_START in line:
            start = idx
            break
    for idx, line in enumerate(lines):
        if MARKER_END in line:
            end = idx
            break
    has_trailing_newline = text.endswith("\n")
    return lines, start, end, has_trailing_newline


def replace_block(original: str, new_block: str) -> Tuple[str, str]:
    lines, start, end, had_trailing_newline = find_block(original)
    if start == -1 or end == -1 or end <= start:
        raise ValueError("Markers not found or malformed")
    old_block = "\n".join(lines[start : end + 1])
    new_lines = lines[:start] + new_block.splitlines() + lines[end + 1 :]
    updated = "\n".join(new_lines)
    if had_trailing_newline:
        updated += "\n"
    return old_block, updated


def make_backup(target: Path) -> Path:
    ts = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
    backup = target.with_suffix(target.suffix + f".backup.{ts}")
    backup.write_text(load_target(target), encoding="utf-8")
    return backup


def diff_summary(old_block: str, new_block: str) -> str:
    diff = difflib.unified_diff(
        old_block.splitlines(),
        new_block.splitlines(),
        fromfile="current",
        tofile="rendered",
        lineterm="",
    )
    return "\n".join(diff)


# ---- CLI ----

def parse_args(argv: Optional[List[str]] = None) -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Writable system truth sync (P1).")
    p.add_argument("--mode", choices=["full", "sandbox", "gateway", "workorders", "core"], default="full")
    p.add_argument("--json", action="store_true", help="Print JSON summary")
    p.add_argument("--md", action="store_true", help="Print Markdown block")
    p.add_argument("--apply", action="store_true", help="Apply rendered block into 02luka.md (creates backup)")
    p.add_argument(
        "--target",
        default=str(repo_root() / "02luka.md"),
        help="Target file to update (default: repo_root/02luka.md)",
    )
    return p.parse_args(argv)


def main(argv: Optional[List[str]] = None) -> int:
    args = parse_args(argv)
    summary = build_summary(mode="full" if args.mode == "core" else args.mode)

    json_obj = {
        "generated_at": summary.generated_at,
        "version": summary.version,
        "repo_root": summary.repo_root,
        "sandbox": asdict(summary.sandbox),
        "gateway_v3": asdict(summary.gateway_v3),
        "work_orders": [asdict(wo) for wo in summary.work_orders],
    }
    md_block = render_markdown(summary)

    printed = False
    if args.json:
        json.dump(json_obj, sys.stdout, ensure_ascii=False, indent=2)
        sys.stdout.write("\n")
        printed = True
    if args.md:
        if printed:
            sys.stdout.write("\n")
        sys.stdout.write(md_block + "\n")
        printed = True
    if not printed and not args.apply:
        # default dry-run output: markdown block
        sys.stdout.write(md_block + "\n")
        printed = True

    target = Path(args.target)
    try:
        current_text = load_target(target)
    except FileNotFoundError:
        sys.stderr.write(f"[truth_sync_p1] target not found: {target}\n")
        return 1

    lines, start, end, _ = find_block(current_text)
    if start == -1 or end == -1 or end <= start:
        sys.stderr.write(f"[truth_sync_p1] markers not found in {target}. Add {MARKER_START} / {MARKER_END}.\n")
        return 1

    old_block = "\n".join(lines[start : end + 1])
    diff = diff_summary(old_block, md_block)
    if diff:
        sys.stdout.write("[truth_sync_p1] diff (current vs rendered):\n")
        sys.stdout.write(diff + "\n")
    else:
        sys.stdout.write("[truth_sync_p1] block already up to date.\n")

    if not args.apply:
        sys.stdout.write("[truth_sync_p1] dry-run (no write). Use --apply to update.\n")
        return 0

    if not diff:
        sys.stdout.write("[truth_sync_p1] apply skipped (no changes).\n")
        return 0

    backup = make_backup(target)
    try:
        _, updated_text = replace_block(current_text, md_block)
    except ValueError as e:
        sys.stderr.write(f"[truth_sync_p1] {e}\n")
        return 1

    target.write_text(updated_text, encoding="utf-8")
    sys.stdout.write(f"[truth_sync_p1] applied to {target}\n")
    sys.stdout.write(f"[truth_sync_p1] backup: {backup}\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
