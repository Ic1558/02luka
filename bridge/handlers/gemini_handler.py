#!/usr/bin/env python3
"""
Gemini Work Order handler (Phase 3)

Transforms WO YAML entries from bridge/inbox/GEMINI into normalized payloads
for the Gemini connector and writes results back to the GEMINI outbox.
"""

from __future__ import annotations

import logging
import sys
from datetime import datetime
from pathlib import Path
from typing import Any, Dict

import yaml

REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from g.connectors import gemini_connector

logger = logging.getLogger(__name__)


def handle_wo(wo: Dict[str, Any]) -> Dict[str, Any]:
    """Normalize a work order payload and execute it via the Gemini connector."""

    task_type = wo.get("task_type", "code_transform")
    input_block = wo.get("input", {}) if isinstance(wo, dict) else {}

    payload = {
        "instructions": input_block.get("instructions", ""),
        "target_files": input_block.get("target_files", []),
        "context": input_block.get("context", {}),
    }

    result = gemini_connector.run_gemini_task(task_type, payload)
    return {
        "ok": True,
        "engine": "gemini",
        "task_type": task_type,
        "result": result,
    }


def handle(task: Dict[str, Any]) -> Dict[str, Any]:
    """Compatibility shim that proxies to :func:`handle_wo`."""

    return handle_wo(task or {})


class GeminiHandler:
    """
    Processes Gemini work orders from bridge/inbox/GEMINI.

    Workflow:
    1. Read WO YAML from the GEMINI inbox
    2. Normalize payload → run_gemini_task()
    3. Persist results to bridge/outbox/GEMINI
    """

    def __init__(self, base_dir: Path | None = None):
        self.base_dir = base_dir or Path.home() / "02luka"
        self.inbox = self.base_dir / "bridge" / "inbox" / "GEMINI"
        self.outbox = self.base_dir / "bridge" / "outbox" / "GEMINI"

        self.inbox.mkdir(parents=True, exist_ok=True)
        self.outbox.mkdir(parents=True, exist_ok=True)

        logger.info("Gemini handler initialized")
        logger.info("  Inbox: %s", self.inbox)
        logger.info("  Outbox: %s", self.outbox)

    def process_work_order(self, wo_path: Path) -> bool:
        wo: Dict[str, Any] = {}
        try:
            logger.info("Processing work order: %s", wo_path.name)
            with wo_path.open("r", encoding="utf-8") as handle:
                wo = yaml.safe_load(handle) or {}

            wo_id = wo.get("wo_id") or wo_path.stem
            response = handle_wo(wo)

            if not response.get("ok"):
                self._write_error_result(wo_id, "Gemini execution failed")
                return False

            self._write_success_result(wo_id, response)
            return True
        except Exception as exc:  # pragma: no cover - defensive log path
            logger.exception("Error processing %s", wo_path)
            self._write_error_result(wo.get("wo_id", wo_path.stem), str(exc))
            return False

    def _write_success_result(self, wo_id: str, response: Dict[str, Any]) -> None:
        output_file = self.outbox / f"{wo_id}_result.yaml"
        result_data = {
            "wo_id": wo_id,
            "status": "success",
            "engine": response.get("engine", "gemini"),
            "task_type": response.get("task_type"),
            "completed_at": datetime.utcnow().isoformat() + "Z",
            "result": response.get("result"),
        }

        with output_file.open("w", encoding="utf-8") as handle:
            yaml.safe_dump(result_data, handle, sort_keys=False, allow_unicode=True)

        logger.info("  Result written: %s", output_file)

    def _write_error_result(self, wo_id: str, error: str) -> None:
        output_file = self.outbox / f"{wo_id}_result.yaml"
        result_data = {
            "wo_id": wo_id,
            "status": "failed",
            "completed_at": datetime.utcnow().isoformat() + "Z",
            "error": error,
        }

        with output_file.open("w", encoding="utf-8") as handle:
            yaml.safe_dump(result_data, handle, sort_keys=False, allow_unicode=True)

        logger.warning("  Error result written: %s", output_file)

    def process_inbox(self) -> int:
        count = 0
        wo_files = list(self.inbox.glob("*.yml")) + list(self.inbox.glob("*.yaml"))

        for wo_file in wo_files:
            if self.process_work_order(wo_file):
                processed_dir = self.inbox / "processed"
                processed_dir.mkdir(exist_ok=True)
                wo_file.rename(processed_dir / wo_file.name)
                count += 1
        return count


def main() -> int:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    )

    handler = GeminiHandler()
    logger.info("Starting Gemini handler...")
    count = handler.process_inbox()
    logger.info("Processed %s work orders", count)
    return 0 if count >= 0 else 1


if __name__ == "__main__":
    sys.exit(main())
