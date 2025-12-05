"""
LAC Telemetry - Event building and logging utilities.
"""

from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, Optional


def build_event(
    event_type: str,
    wo_id: str = "unknown",
    lane: str = "unknown",
    status: str = "unknown",
    duration_ms: int = 0,
    paid: bool = False,
    extra: Optional[Dict[str, Any]] = None,
) -> Dict[str, Any]:
    """
    Build a telemetry event dictionary.
    
    Args:
        event_type: Type of event (e.g., "MERGE_COMPLETED", "WO_PROCESSED")
        wo_id: Work Order ID
        lane: Processing lane (e.g., "direct_merge", "lac_manager")
        status: Event status (e.g., "success", "error")
        duration_ms: Duration in milliseconds
        paid: Whether paid lane was used
        extra: Additional metadata
    
    Returns:
        Event dictionary ready for logging
    """
    event = {
        "event_type": event_type,
        "wo_id": wo_id,
        "lane": lane,
        "status": status,
        "duration_ms": duration_ms,
        "paid": paid,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }
    
    if extra:
        event["extra"] = extra
    
    return event


def log_event(event: Dict[str, Any], log_path: Optional[Path] = None) -> None:
    """
    Log a telemetry event to JSONL file.
    
    Args:
        event: Event dictionary from build_event()
        log_path: Optional custom log path (defaults to g/telemetry/lac_events.jsonl)
    """
    if log_path is None:
        log_path = Path("g/telemetry/lac_events.jsonl")
    
    log_path.parent.mkdir(parents=True, exist_ok=True)
    
    with log_path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(event) + "\n")


__all__ = ["build_event", "log_event"]
