"""
Docs V4 Worker with direct-write capability for documentation files and catalog generation.
"""

from __future__ import annotations

import os
from pathlib import Path
from typing import Dict, List

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
        if task.get("operation") == "catalog" or task.get("catalog"):
            return self._run_catalog(task)
        if task.get("operation") == "listen" or task.get("listen"):
            return self._run_listen(task)
        if task.get("operation") == "summary":
            return self._run_summary(task)

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

    def _run_summary(self, task: Dict) -> Dict:
        base_dir = Path(os.getenv("LAC_BASE_DIR") or Path.cwd())
        summary_path = Path(task.get("summary_path") or (base_dir / "g/docs/pipeline_summary.md"))
        catalog_path = Path(task.get("catalog_path") or (base_dir / "g/catalog/file_catalog.yaml"))

        requirement_id = task.get("requirement_id", "UNKNOWN")
        status = task.get("status", "unknown")
        lane = task.get("lane", "dev_oss")
        qa_status = task.get("qa_status", "unknown")
        files_touched = task.get("files_touched") or []

        lines = [
            "# Pipeline Summary",
            f"- Requirement: {requirement_id}",
            f"- Status: {status}",
            f"- Lane: {lane}",
            f"- QA Status: {qa_status}",
            f"- Files Touched: {', '.join(files_touched) if files_touched else 'none'}",
        ]
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
            stat = path.stat()
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


__all__ = ["DocsWorkerV4", "check_write_allowed", "apply_patch", "scan_paths", "build_catalog", "write_catalog"]
