#!/usr/bin/env python3
"""\
Core History Engine (Seatbelt-safe)

Purpose
- Generate Core History artifacts without shell here-docs.

Inputs
- g/telemetry/decision_log.jsonl
- decision_summarizer.py (rule source)

Outputs
- g/core_history/latest.json
- g/core_history/rule_table.json
- g/core_history/index.json
- g/core_history/latest.md

Behavior notes (must remain stable)
- Deterministic timestamp selection: prefer last decision 'ts' if present; else fallback to current UTC.
- write-if-changed semantics: avoid touching files if content identical.
- No rule tuning / no phase-logic changes: only execution boundary refactor.
"""

from __future__ import annotations

import datetime
import hashlib
import json
import os
import pathlib
import re
import subprocess
import sys
from typing import Any, Dict, List, Optional


REPO_ROOT = pathlib.Path(os.environ.get("REPO_ROOT", str(pathlib.Path.home() / "02luka"))).resolve()
CORE_DIR = REPO_ROOT / "g" / "core_history"
DEC_PATH = REPO_ROOT / "g" / "telemetry" / "decision_log.jsonl"
RULE_SRC = REPO_ROOT / "decision_summarizer.py"


def _utc_now_iso() -> str:
    return datetime.datetime.now(datetime.timezone.utc).isoformat().replace("+00:00", "Z")


def parse_ts(ts_val: Any) -> datetime.datetime:
    """Parse timestamp (int/float/ISO string) to datetime object."""
    if isinstance(ts_val, (int, float)):
        return datetime.datetime.fromtimestamp(float(ts_val), datetime.timezone.utc)
    try:
        return datetime.datetime.fromisoformat(str(ts_val).replace("Z", "+00:00"))
    except Exception:
        return datetime.datetime.now(datetime.timezone.utc)


def sha256_bytes(b: bytes) -> str:
    return hashlib.sha256(b).hexdigest()


def sha256_text(s: str) -> str:
    return sha256_bytes(s.encode("utf-8"))


def file_sha256(path: pathlib.Path) -> Optional[str]:
    if not path.exists() or not path.is_file():
        return None
    return sha256_bytes(path.read_bytes())


def write_if_changed(path: pathlib.Path, content: str) -> bool:
    """Write file only if content differs. Returns True if wrote."""
    new_sha = sha256_text(content)
    old_sha = file_sha256(path)
    if old_sha == new_sha:
        return False
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    return True


def run_git(args: List[str]) -> str:
    try:
        out = subprocess.check_output(["git", "-C", str(REPO_ROOT), *args], stderr=subprocess.DEVNULL)
        return out.decode("utf-8", errors="replace").strip()
    except Exception:
        return "unknown"


def git_metadata() -> Dict[str, str]:
    branch = run_git(["rev-parse", "--abbrev-ref", "HEAD"]) or "unknown"
    head = run_git(["rev-parse", "--short", "HEAD"]) or "unknown"
    status_raw = run_git(["status", "--porcelain"])  # empty => clean
    status = "clean" if (status_raw.strip() == "") else "dirty"
    return {"branch": branch, "head": head, "status": status}


def read_decision_rows_last_n(n: int = 50) -> List[Dict[str, Any]]:
    if not DEC_PATH.exists():
        return []
    try:
        lines = DEC_PATH.read_text(encoding="utf-8", errors="replace").splitlines()
        rows: List[Dict[str, Any]] = []
        for line in lines[-n:]:
            line = line.strip()
            if not line:
                continue
            try:
                rows.append(json.loads(line))
            except Exception:
                # Keep engine resilient: ignore malformed lines.
                continue
        return rows
    except Exception:
        return []


def decision_stats() -> Dict[str, Any]:
    if not DEC_PATH.exists():
        return {"status": "missing", "count": 0, "recent": []}

    try:
        # Count lines without loading JSON for speed.
        count = sum(1 for _ in DEC_PATH.read_text(encoding="utf-8", errors="replace").splitlines() if _.strip())
    except Exception:
        count = 0

    recent = read_decision_rows_last_n(50)
    return {"status": "present", "count": int(count), "recent": recent}


def pick_deterministic_ts(dec_recent: List[Dict[str, Any]]) -> str:
    """Prefer last decision row's 'ts' if present; else UTC now."""
    if dec_recent:
        last = dec_recent[-1]
        if "ts" in last:
            # Preserve original value type (int/float/str) but serialize as string in metadata.
            return str(last.get("ts"))
    return _utc_now_iso()


def extract_rule_ids() -> List[str]:
    if not RULE_SRC.exists():
        return []
    try:
        text = RULE_SRC.read_text(encoding="utf-8", errors="replace")
        ids = sorted(set(re.findall(r"R[0-9]+_[A-Z0-9_]+", text)))
        return [i for i in ids if i]
    except Exception:
        return []


def render_latest_md(latest_json: Dict[str, Any]) -> str:
    """Generate latest.md from latest.json content.

    NOTE: This keeps Phase 12/13 rendering logic stable.
    """

    DEBUG = os.environ.get("BUILD_CORE_HISTORY_DEBUG") == "1"

    m = latest_json["metadata"]
    d = latest_json["decisions"]
    r = latest_json["rules"]

    lines: List[str] = []
    lines.append(f"# Core History - {m['ts']}")
    lines.append("")
    lines.append(f"- git: {m['git']['branch']} @ {m['git']['head']} ({m['git']['status']})")
    lines.append(f"- decision_log: {d['status']} (count={d['count']})")
    lines.append(f"- rules: {r['status']} (count={r['count']}, sha256={r.get('hash')})")
    lines.append("")
    lines.append("## Recent Decisions (last 5)")

    recent = d.get("recent", [])

    # 1. Cluster by time (gap > 60m starts new cluster)
    clusters: List[List[Dict[str, Any]]] = []
    current_cluster: List[Dict[str, Any]] = []
    last_dt: Optional[datetime.datetime] = None

    for item in recent:
        ts = item.get("ts", 0)
        dt = parse_ts(ts)
        if last_dt and (dt - last_dt).total_seconds() > 3600:
            clusters.append(current_cluster)
            current_cluster = []
        current_cluster.append(item)
        last_dt = dt
    if current_cluster:
        clusters.append(current_cluster)

    rendered: List[str] = []

    for cluster in clusters:
        if not cluster:
            continue

        rules_set = set()
        for item in cluster:
            rules_set.update(item.get("matched_rules", []))

        start_ts = parse_ts(cluster[0].get("ts", 0))
        end_ts = parse_ts(cluster[-1].get("ts", 0))
        duration_m = int((end_ts - start_ts).total_seconds() / 60)
        count = len(cluster)
        r5_only = (rules_set == {"R5_DEFAULT"})

        # Promotion Logic (Phase 12)
        promoted = False

        # R3 -> R2 (Actionable)
        action_rules = {rr for rr in rules_set if any(x in rr.lower() for x in ["save", "seal", "sync"])}

        if action_rules:
            rendered.append("- [ ACTIONABLE ] System State Shift")
            rendered.append(f"  - triggered by: {', '.join(list(action_rules)[:3])}")
            promoted = True
        elif len(rules_set) >= 2 and "R5_DEFAULT" in rules_set:
            rendered.append("- [ SIGNAL ] Sustained System Activity Detected")
            rendered.append(f"  - sources: {', '.join(list(rules_set)[:3])}")
            rendered.append(f"  - duration: {duration_m}m")
            promoted = True
        elif r5_only and count >= 5:
            rendered.append(f"- [ PATTERN ] Repeated Routine Snapshot (x{count} in {duration_m}m)")
            promoted = True

        if promoted:
            if DEBUG:
                print(f"DEBUG: Promoted cluster size={count} dur={duration_m} rules={rules_set}", file=sys.stderr)
            continue

        # Fallback: Standard Grouping
        sub_group_count = 0
        sub_last_ts: Any = 0
        for item in cluster:
            risk = item.get("risk", "?")
            r_list = item.get("matched_rules", [])
            is_routine = (risk == "low" and r_list == ["R5_DEFAULT"])

            if is_routine:
                sub_group_count += 1
                sub_last_ts = item.get("ts", 0)
            else:
                if sub_group_count > 0:
                    t_str = parse_ts(sub_last_ts).strftime("%H:%M")
                    rendered.append(f"- [ x{sub_group_count} ] Routine Snapshots (R5_DEFAULT) · last active {t_str}")
                    sub_group_count = 0

                preview = str(item.get("text_preview", ""))[:120]
                r_str = ",".join(r_list[:5])
                rendered.append(f"- risk={risk} rules=[{r_str}] preview={preview}")

        if sub_group_count > 0:
            t_str = parse_ts(sub_last_ts).strftime("%H:%M")
            rendered.append(f"- [ x{sub_group_count} ] Routine Snapshots (R5_DEFAULT) · last active {t_str}")

    # Phase 13: Auto-Hook Planner (Dry-Run) - Corrected Selection Logic
    hook_planned = False
    for cluster in reversed(clusters):
        if hook_planned:
            break

        rules_set = set()
        for item in cluster:
            rules_set.update(item.get("matched_rules", []))

        is_signal = (len(rules_set) >= 2 and "R5_DEFAULT" in rules_set)
        if not is_signal:
            continue

        action_rules = {rr for rr in rules_set if any(x in rr.lower() for x in ["save", "seal", "sync"])}
        if action_rules:
            continue

        last_event_dt = parse_ts(cluster[-1].get("ts", 0))
        now = datetime.datetime.now(datetime.timezone.utc)
        silence_min = (now - last_event_dt).total_seconds() / 60

        if DEBUG:
            duration_m = int((parse_ts(cluster[-1].get("ts", 0)) - parse_ts(cluster[0].get("ts", 0))).total_seconds() / 60)
            print(f"DEBUG[R2]: cluster duration={duration_m}m silence={int(silence_min)}m rules={rules_set}", file=sys.stderr)

        if 10 <= silence_min <= 120:
            if os.environ.get("R2_HOOKS", "1") != "0":
                rendered.append("- [ ACTIONABLE ] Hook Planned: save (dry-run)")
                rendered.append(f"  - trigger: signal cluster ended ({int(silence_min)}m ago)")
                hook_planned = True

    lines.extend(rendered[-5:])
    return "\n".join(lines) + "\n"


def build() -> None:
    CORE_DIR.mkdir(parents=True, exist_ok=True)

    # Decisions
    d = decision_stats()

    # TS
    ts_iso = pick_deterministic_ts(d.get("recent", []))

    # Rules
    rule_ids = extract_rule_ids()
    rule_hash = file_sha256(RULE_SRC) if RULE_SRC.exists() else None

    # latest.json
    latest_obj: Dict[str, Any] = {
        "metadata": {
            "ts": ts_iso,
            "git": git_metadata(),
            "generated_by": "build_core_history_engine.py",
        },
        "snapshot": {"status": "unknown", "md_path": None, "summary_path": None},
        "decisions": {
            "status": d["status"],
            "count": int(d["count"]),
            "recent": d.get("recent", []),
        },
        "rules": {
            "status": "ok" if rule_hash else "missing",
            "hash": rule_hash or "missing",
            "count": int(len(rule_ids)),
            "ids": rule_ids,
        },
    }

    latest_json_text = json.dumps(latest_obj, ensure_ascii=False, indent=2)
    latest_path = CORE_DIR / "latest.json"
    write_if_changed(latest_path, latest_json_text + "\n")

    # rule_table.json
    rule_table_obj = {
        "source": str(RULE_SRC.name),
        "sha256": (rule_hash or "missing"),
        "rule_count": int(len(rule_ids)),
        "rule_ids": rule_ids,
    }
    rule_table_text = json.dumps(rule_table_obj, ensure_ascii=False, indent=2)
    rule_table_path = CORE_DIR / "rule_table.json"
    write_if_changed(rule_table_path, rule_table_text + "\n")

    # index.json checksums (computed from just-written content on disk)
    latest_sha = file_sha256(latest_path) or "missing"
    rulet_sha = file_sha256(rule_table_path) or "missing"

    index_obj = {
        "ts": ts_iso,
        "files": {
            "latest.json": {"sha256": latest_sha},
            "rule_table.json": {"sha256": rulet_sha},
        },
    }
    index_text = json.dumps(index_obj, ensure_ascii=False, indent=2)
    index_path = CORE_DIR / "index.json"
    write_if_changed(index_path, index_text + "\n")

    # latest.md
    latest_md_text = render_latest_md(latest_obj)
    latest_md_path = CORE_DIR / "latest.md"
    write_if_changed(latest_md_path, latest_md_text)

    print("✅ Core History built (deterministic)")


def main() -> None:
    # Arg parsing reserved for future phases; keep stable now.
    # We intentionally accept and ignore args for CLI compatibility.
    try:
        build()
    except KeyboardInterrupt:
        raise
    except Exception as e:
        print(f"❌ Core History build failed: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
