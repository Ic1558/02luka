"""
Docs V4 Worker with direct-write capability for documentation files and catalog generation.
"""

from __future__ import annotations

import datetime as _dt
import json
import os
from pathlib import Path
from typing import Any, Dict, List, Optional

from agents.docs_v4.cataloger import build_catalog, write_catalog
from agents.docs_v4.listener import collect_events
from agents.docs_v4.scanner import scan_paths
from agents.docs_v4.summarizer import build_summary, summarize_conversations, summarize_events
from shared.policy import apply_patch, check_write_allowed


class DocsWorkerV4:
    def self_write(self, file_path: str, content: str) -> dict:
        """Direct write via shared policy."""
        return apply_patch(file_path, content)

    def write_doc_file(self, file_path: str, content: str) -> dict:
        """Write a documentation file using policy enforcement."""
        if content is None or content == "":
            return {
                "status": "failed",
                "reason": "MISSING_OR_EMPTY_CONTENT",
                "file": file_path,
            }
        return self.self_write(file_path, content)

    def plan_docs(self, task: Dict) -> Dict:
        return task.get("plan", task)

    def generate_doc_patches(self, plan: Dict) -> List[Dict]:
        return plan.get("patches", [])

    def execute_task(self, task: Dict) -> Dict:
        operation = (task.get("operation") or "").lower()
        if operation == "catalog" or task.get("catalog"):
            return self._run_catalog(task)
        if operation == "listen" or task.get("listen"):
            return self._run_listen(task)
        if operation == "summary":
            return self._run_summary(task)
        if operation == "background_summary":
            return self._run_background_summary(task)

        plan = self.plan_docs(task)
        patches = self.generate_doc_patches(plan)

        results = []
        for patch in patches:
            result = self.write_doc_file(patch["file"], patch.get("content", ""))
            results.append(result)
            if result["status"] == "blocked":
                return {
                    "status": "failed",
                    "reason": result["reason"],
                    "partial_results": results,
                }
            if result["status"] == "error":
                return {
                    "status": "failed",
                    "reason": result.get("reason", "FILE_WRITE_ERROR"),
                    "partial_results": results,
                }
            if result["status"] == "failed":
                return {
                    "status": "failed",
                    "reason": result.get("reason", "VALIDATION_FAILED"),
                    "partial_results": results,
                }

        return {
            "status": "success",
            "self_applied": True,
            "files_touched": [
                r["file"] for r in results if r.get("status") == "success"
            ],
        }

    def _run_catalog(self, task: Dict) -> Dict:
        base_dir = Path(os.getenv("LAC_BASE_DIR") or Path.cwd())
        roots = task.get("roots") or ["g/src", "g/docs"]
        catalog_path = Path(task.get("catalog_path") or (base_dir / "g/catalog/file_catalog.json"))

        entries = scan_paths(base_dir, roots)
        catalog = build_catalog(base_dir, entries)
        write_result = write_catalog(catalog_path, catalog)

        if write_result.get("status") != "success":
            return {
                "status": "failed",
                "reason": write_result.get("reason", "CATALOG_WRITE_FAILED"),
                "partial_results": [write_result],
            }

        return {
            "status": "success",
            "files_touched": [write_result.get("file")],
            "count": catalog.get("count", 0),
        }

    def _run_background_summary(self, task: Dict) -> Dict:
        base_dir_str = task.get("base_dir") or os.environ.get("LAC_BASE_DIR")
        base_dir = Path(base_dir_str) if base_dir_str else Path.cwd()
        telemetry_dir = base_dir / "g" / "telemetry"

        time_window_hours = int(task.get("time_window_hours", 24))
        limit = int(task.get("limit", 1000))
        output_dir = Path(task.get("output_dir", "g/reports/system"))
        output_dir = (base_dir / output_dir).resolve()
        output_dir.mkdir(parents=True, exist_ok=True)
        output_prefix = task.get("output_prefix", "lac_background_summary")

        now = _dt.datetime.utcnow()
        cutoff = now - _dt.timedelta(hours=time_window_hours)

        background_rows = self._load_jsonl(telemetry_dir / "background_tasks.jsonl", limit)
        rnd_rows = self._load_jsonl(telemetry_dir / "rnd_analysis.jsonl", limit)

        def _parse_ts(raw: Any) -> Optional[_dt.datetime]:
            if raw is None:
                return None
            if isinstance(raw, (int, float)):
                try:
                    return _dt.datetime.utcfromtimestamp(float(raw))
                except Exception:
                    return None
            if isinstance(raw, str):
                try:
                    return _dt.datetime.fromisoformat(raw.replace("Z", "+00:00")).astimezone(_dt.timezone.utc).replace(
                        tzinfo=None
                    )
                except Exception:
                    return None
            return None

        bg_stats: Dict[str, Dict[str, Any]] = {}
        recent_bg_rows: List[Dict[str, Any]] = []
        for row in background_rows:
            ts = _parse_ts(row.get("timestamp") or row.get("ts") or row.get("time"))
            if ts is None or ts < cutoff:
                continue
            recent_bg_rows.append(row)
            task_name = str(row.get("task") or row.get("name") or "unknown")
            status = str(row.get("status") or "unknown").lower()
            duration_ms = row.get("duration_ms") or row.get("duration") or row.get("duration_sec")

            if task_name not in bg_stats:
                bg_stats[task_name] = {
                    "total": 0,
                    "success": 0,
                    "fail": 0,
                    "durations": [],
                    "last_ts": None,
                    "last_status": None,
                    "last_error": None,
                }
            s = bg_stats[task_name]
            s["total"] += 1
            if status == "success":
                s["success"] += 1
            else:
                s["fail"] += 1

            if isinstance(duration_ms, (int, float)):
                s["durations"].append(float(duration_ms))

            if s["last_ts"] is None or (ts and ts > s["last_ts"]):
                s["last_ts"] = ts
                s["last_status"] = status
                s["last_error"] = row.get("error") or row.get("reason")

        recent_rnd_rows: List[Dict[str, Any]] = []
        for row in rnd_rows:
            ts = _parse_ts(row.get("timestamp") or row.get("ts") or row.get("time"))
            if ts is None or ts < cutoff:
                continue
            recent_rnd_rows.append(row)

        total_bg = len(recent_bg_rows)
        total_rnd = len(recent_rnd_rows)

        ts_str = now.strftime("%Y-%m-%d %H:%M:%S UTC")
        lines: List[str] = []
        lines.append(f"# LAC v4 Background Summary — {ts_str}")
        lines.append("")
        lines.append(f"Time window: last {time_window_hours} hours")
        lines.append("")
        lines.append("## Overview")
        lines.append("")
        lines.append(f"- Background task runs: {total_bg}")
        lines.append(f"- R&D analyses: {total_rnd}")
        lines.append("")

        lines.append("## Background Tasks")
        lines.append("")
        if bg_stats:
            for task_name, s in sorted(bg_stats.items()):
                total = s["total"]
                success = s["success"]
                fail = s["fail"]
                last_ts = s["last_ts"].strftime("%Y-%m-%d %H:%M:%S") if s["last_ts"] else "unknown"
                last_status = s["last_status"] or "unknown"
                last_error = s["last_error"]
                avg_duration = (
                    sum(s["durations"]) / len(s["durations"])
                    if s["durations"]
                    else None
                )
                lines.append(f"### {task_name}")
                lines.append(f"- Runs: {total} ({success} success / {fail} fail)")
                lines.append(f"- Last run: {last_ts} — {last_status}")
                if avg_duration is not None:
                    # if duration_ms was used, convert to seconds; if seconds provided, assume already seconds
                    if s["durations"] and max(s["durations"]) > 120:  # heuristic: likely ms
                        avg_secs = avg_duration / 1000
                    else:
                        avg_secs = avg_duration
                    lines.append(f"- Avg duration: {avg_secs:.2f}s")
                if last_error:
                    lines.append(f"- Last error: `{last_error}`")
                lines.append("")
        else:
            lines.append("_No background runs in this window._")
            lines.append("")

        lines.append("## R&D Analysis")
        lines.append("")
        if recent_rnd_rows:
            lines.append(f"- Total analyses: {total_rnd}")
            pattern_counts: Dict[str, int] = {}
            for row in recent_rnd_rows:
                patterns = row.get("patterns") or row.get("patterns_updated") or []
                if isinstance(patterns, dict):
                    patterns = list(patterns.keys())
                if isinstance(patterns, str):
                    patterns = [patterns]
                for pid in patterns:
                    pid_str = str(pid)
                    pattern_counts[pid_str] = pattern_counts.get(pid_str, 0) + 1
            if pattern_counts:
                lines.append("")
                lines.append("### Patterns Updated")
                lines.append("")
                for pid, count in sorted(pattern_counts.items(), key=lambda kv: kv[1], reverse=True):
                    lines.append(f"- {pid}: {count} updates")
                lines.append("")
        else:
            lines.append("_No R&D analyses in this window._")
            lines.append("")

        date_str = now.strftime("%Y-%m-%d")
        filename = f"{output_prefix}_{date_str}.md"
        output_path = output_dir / filename

        try:
            output_path.write_text("\n".join(lines), encoding="utf-8")
        except OSError as exc:
            return {
                "status": "error",
                "error": f"WRITE_FAILED: {exc}",
                "summary_path": str(output_path),
            }

        return {
            "status": "success",
            "summary_path": str(output_path.relative_to(base_dir)),
            "entries_background": total_bg,
            "entries_rnd": total_rnd,
        }

    def _run_summary(self, task: Dict) -> Dict:
        base_dir = Path(os.getenv("LAC_BASE_DIR") or Path.cwd())
        summary_path = Path(task.get("summary_path") or (base_dir / "g/docs/pipeline_summary.md"))
        catalog_path = Path(task.get("catalog_path") or (base_dir / "g/catalog/file_catalog.yaml"))

        requirement_id = task.get("requirement_id", "UNKNOWN")
        status = task.get("status", "unknown")
        lane = task.get("lane", "dev_oss")
        qa_status = task.get("qa_status", "unknown")
        files_touched = task.get("files_touched") or []
        pattern_warnings = task.get("pattern_warnings") or []

        lines = [
            "# Pipeline Summary",
            f"- Requirement: {requirement_id}",
            f"- Status: {status}",
            f"- Lane: {lane}",
            f"- QA Status: {qa_status}",
            f"- Files Touched: {', '.join(files_touched) if files_touched else 'none'}",
        ]
        if pattern_warnings:
            lines.append(f"- Pattern Warnings: {', '.join(pattern_warnings)}")
        summary_content = "\n".join(lines)

        summary_result = self.self_write(str(summary_path), summary_content)
        if summary_result.get("status") != "success":
            return {
                "status": "failed",
                "reason": summary_result.get("reason", "SUMMARY_WRITE_FAILED"),
                "partial_results": [summary_result],
            }

        catalog_entries = []
        for f in files_touched:
            path = (base_dir / f).resolve()
            if not path.exists():
                continue
            try:
                stat = path.stat()
            except OSError:
                continue
            catalog_entries.append(
                {"path": path.relative_to(base_dir).as_posix(), "size": stat.st_size, "mtime": int(stat.st_mtime)}
            )

        catalog = build_catalog(base_dir, catalog_entries)
        write_result = write_catalog(catalog_path, catalog)

        if write_result.get("status") != "success":
            return {
                "status": "failed",
                "reason": write_result.get("reason", "CATALOG_WRITE_FAILED"),
                "partial_results": [summary_result, write_result],
            }

        return {
            "status": "success",
            "files_touched": [summary_result.get("file"), write_result.get("file")],
            "count": catalog.get("count", 0),
        }

    def _run_listen(self, task: Dict) -> Dict:
        base_dir = Path(os.getenv("LAC_BASE_DIR") or Path.cwd())
        events_path = task.get("events_path")
        conversations_path = task.get("conversations_path")
        summary_path = Path(task.get("summary_path") or (base_dir / "g/docs/telemetry_summary.md"))

        collected = collect_events(base_dir, telemetry_path=events_path, conversations_path=conversations_path, limit=task.get("limit", 200))
        events_summary = summarize_events(collected.get("events", []))
        convo_summary = summarize_conversations(collected.get("conversations", []))
        summary_content = build_summary(events_summary, convo_summary)

        write_result = self.self_write(str(summary_path), summary_content)
        if write_result.get("status") != "success":
            return {
                "status": "failed",
                "reason": write_result.get("reason", "SUMMARY_WRITE_FAILED"),
                "partial_results": [write_result],
            }

        return {
            "status": "success",
            "files_touched": [write_result.get("file")],
            "events": events_summary,
            "conversations": convo_summary,
        }

    def _load_jsonl(self, path: Path, limit: int) -> List[Dict[str, Any]]:
        if not path.exists():
            return []
        rows: List[Dict[str, Any]] = []
        try:
            with path.open("r", encoding="utf-8") as f:
                for i, line in enumerate(f):
                    if i >= limit:
                        break
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        rows.append(json.loads(line))
                    except json.JSONDecodeError:
                        continue
        except OSError:
            return []
        return rows


__all__ = ["DocsWorkerV4", "check_write_allowed", "apply_patch", "scan_paths", "build_catalog", "write_catalog"]
