#!/usr/bin/env python3
"""
launchagent_status.py

Reads the LaunchAgent priority list and reports running status.

Inputs:
  - g/reports/system/launchagent_priority_list.md

Outputs:
  - JSON (default)
  - Markdown block (optional)

Logic:
  - P0 missing -> RED
  - P0 all running, optional missing -> YELLOW
  - All running -> GREEN
  - Entries marked "(if deployed)" are required only if their plist exists.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from dataclasses import dataclass, asdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable


def repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


PRIORITY_MD = Path("g/reports/system/launchagent_priority_list.md")


@dataclass
class AgentStatus:
    label: str
    tier: str  # P0 | Optional
    required: bool
    conditional: bool
    state: str  # running | not_running | unknown
    pid: int | None
    detail: str | None


def parse_priority_list(md_text: str) -> tuple[list[tuple[str, str, bool]], list[tuple[str, str, bool]]]:
    """
    Returns (p0, optional) where each item is (label, note, conditional).
    conditional=True for entries annotated with "(if ...)".
    """

    def extract(section_title: str) -> list[tuple[str, str, bool]]:
        in_section = False
        out: list[tuple[str, str, bool]] = []
        for raw in md_text.splitlines():
            line = raw.strip()
            if line.startswith("## "):
                in_section = line.lower().startswith(f"## {section_title.lower()}")
                continue
            if not in_section:
                continue
            if line.startswith("## "):
                break
            if not line.startswith("- `com."):
                continue
            m = re.match(r"-\s+`([^`]+)`\s*(?:-\s*(.*))?$", line)
            if not m:
                continue
            label = m.group(1).strip()
            note = (m.group(2) or "").strip()
            conditional = "(if " in note.lower()
            out.append((label, note, conditional))
        return out

    p0 = extract("P0 (Critical) - Must Be Running")
    optional = extract("Optional - Nice to Have Running")
    return p0, optional


def plist_exists(label: str) -> bool:
    p = Path.home() / "Library" / "LaunchAgents" / f"{label}.plist"
    return p.exists()


def launchctl_print(label: str) -> tuple[str | None, int | None, str | None]:
    """
    Returns (state, pid, detail) from `launchctl print`.
    """
    uid = os.getuid()
    target = f"gui/{uid}/{label}"
    try:
        res = subprocess.run(
            ["launchctl", "print", target],
            capture_output=True,
            text=True,
            check=False,
        )
    except Exception as e:
        return None, None, f"launchctl_error: {e}"

    out = (res.stdout or "") + (res.stderr or "")
    if res.returncode != 0 and "could not find service" in out.lower():
        return "not_running", None, "not_loaded"

    state = None
    pid = None

    m_state = re.search(r"^\s*state\s*=\s*([a-zA-Z ]+)\s*$", out, flags=re.MULTILINE)
    if m_state:
        state = m_state.group(1).strip().lower().replace(" ", "_")

    m_pid = re.search(r"^\s*pid\s*=\s*([0-9]+)\s*$", out, flags=re.MULTILINE)
    if m_pid:
        try:
            pid = int(m_pid.group(1))
        except Exception:
            pid = None

    if state is None:
        # Older launchctl variants might omit state; infer from pid.
        if pid:
            state = "running"
        else:
            state = "unknown"

    if state not in {"running", "not_running"}:
        # Normalize variants like "spawn_scheduled" etc.
        if pid:
            state = "running"
        else:
            state = "not_running"

    return state, pid, None if res.returncode == 0 else f"rc={res.returncode}"


def compute_overall(statuses: Iterable[AgentStatus]) -> str:
    p0 = [s for s in statuses if s.tier == "P0" and s.required]
    opt = [s for s in statuses if s.tier == "Optional"]

    if any(s.state != "running" for s in p0):
        return "RED"
    if any(s.state != "running" for s in opt):
        return "YELLOW"
    return "GREEN"


def render_md(generated_at: str, overall: str, statuses: list[AgentStatus]) -> str:
    p0 = [s for s in statuses if s.tier == "P0"]
    opt = [s for s in statuses if s.tier == "Optional"]

    def line_for(s: AgentStatus) -> str:
        cond = " (conditional)" if s.conditional else ""
        pid = f" pid={s.pid}" if s.pid else ""
        return f"- `{s.label}`: **{s.state}**{pid}{cond}"

    lines: list[str] = []
    lines.append("<!-- LAUNCHAGENT_STATUS_START -->")
    lines.append("")
    lines.append("## LaunchAgent Status")
    lines.append("")
    lines.append(f"- Generated at (UTC): `{generated_at}`")
    lines.append(f"- Overall: **{overall}**")
    lines.append("")
    lines.append("### P0")
    lines.extend([line_for(s) for s in p0])
    lines.append("")
    lines.append("### Optional (sample)")
    # Keep it short in MD.
    for s in opt[:20]:
        lines.append(line_for(s))
    if len(opt) > 20:
        lines.append(f"- … ({len(opt) - 20} more)")
    lines.append("")
    lines.append("<!-- LAUNCHAGENT_STATUS_END -->")
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="LaunchAgent status dashboard helper.")
    ap.add_argument("--md", action="store_true", help="Print Markdown block instead of JSON.")
    ap.add_argument("--priority-md", default=str(PRIORITY_MD), help="Path to launchagent_priority_list.md")
    args = ap.parse_args(argv)

    root = repo_root()
    md_path = (root / args.priority_md).resolve()
    if not md_path.exists():
        print(f"missing_priority_file: {md_path}", file=sys.stderr)
        return 2

    p0, optional = parse_priority_list(md_path.read_text(encoding="utf-8"))

    statuses: list[AgentStatus] = []
    for label, _note, conditional in p0:
        required = True
        if conditional:
            required = plist_exists(label)
        state, pid, detail = launchctl_print(label)
        statuses.append(
            AgentStatus(
                label=label,
                tier="P0",
                required=required,
                conditional=conditional,
                state=state or "unknown",
                pid=pid,
                detail=detail,
            )
        )

    for label, _note, conditional in optional:
        required = False
        state, pid, detail = launchctl_print(label)
        statuses.append(
            AgentStatus(
                label=label,
                tier="Optional",
                required=required,
                conditional=conditional,
                state=state or "unknown",
                pid=pid,
                detail=detail,
            )
        )

    generated_at = datetime.now(timezone.utc).isoformat()
    overall = compute_overall(statuses)

    payload = {
        "generated_at": generated_at,
        "overall": overall,
        "p0_total": len([s for s in statuses if s.tier == "P0" and s.required]),
        "p0_running": len([s for s in statuses if s.tier == "P0" and s.required and s.state == "running"]),
        "optional_total": len([s for s in statuses if s.tier == "Optional"]),
        "optional_running": len([s for s in statuses if s.tier == "Optional" and s.state == "running"]),
        "agents": [asdict(s) for s in statuses],
    }

    if args.md:
        sys.stdout.write(render_md(generated_at, overall, statuses))
        sys.stdout.write("\n")
    else:
        json.dump(payload, sys.stdout, ensure_ascii=False, indent=2)
        sys.stdout.write("\n")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
