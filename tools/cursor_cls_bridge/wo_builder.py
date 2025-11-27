"""
Work Order builder for CLS Cursor Wrapper.
"""

import json
import random
import string
from datetime import datetime
from pathlib import Path
from typing import Dict, Optional


def generate_wo_id() -> str:
    """
    Generate unique WO ID: WO-CLS-YYYYMMDD-HHMMSS-XXXX
    """
    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    random_suffix = "".join(random.choices(string.ascii_uppercase + string.digits, k=4))
    return f"WO-CLS-{timestamp}-{random_suffix}"


def detect_routing_hint(command_text: str) -> str:
    """
    Detect routing hint from command text.
    Default: "oss"
    """
    text_lower = command_text.lower()
    if "gmx" in text_lower or "gmxcli" in text_lower:
        return "gmxcli"
    elif "gptdeep" in text_lower or "deep" in text_lower:
        return "gptdeep"
    else:
        return "oss"


def detect_complexity(command_text: str, file_count: int = 1) -> str:
    """
    Simple complexity detection.
    """
    text_lower = command_text.lower()
    if "complex" in text_lower or "refactor" in text_lower or file_count > 2:
        return "complex"
    return "simple"


def build_work_order(
    command_text: str,
    base_dir: Path,
    file_path: Optional[str] = None,
    selection_start: Optional[int] = None,
    selection_end: Optional[int] = None,
) -> Dict:
    """
    Build Work Order JSON matching schemas/work_order.schema.json
    """
    wo_id = generate_wo_id()
    routing_hint = detect_routing_hint(command_text)
    complexity = detect_complexity(command_text)
    
    wo = {
        "wo_id": wo_id,
        "objective": command_text,
        "routing_hint": routing_hint,
        "priority": "P1",
        "self_apply": True,
        "complexity": complexity,
        "requires_paid_lane": False,
        "source": "cursor_cls_wrapper",
    }
    
    # Add context if file/selection provided
    context = {
        "project_root": str(base_dir),
        "cursor_command": "/cls-apply",
        "cursor_prompt": command_text,
    }
    
    if file_path:
        context["file_path"] = file_path
        if selection_start is not None and selection_end is not None:
            context["selection"] = {
                "start_line": selection_start,
                "end_line": selection_end,
            }
    
    wo["context"] = context
    
    return wo


def validate_wo_schema(wo: Dict) -> bool:
    """
    Basic validation against schema.
    Returns True if valid, raises ValueError if not.
    """
    required_fields = ["wo_id", "objective", "routing_hint", "priority"]
    for field in required_fields:
        if field not in wo:
            raise ValueError(f"Missing required field: {field}")
    
    if wo["routing_hint"] not in ["oss", "gmxcli", "gptdeep"]:
        raise ValueError(f"Invalid routing_hint: {wo['routing_hint']}")
    
    if wo["priority"] not in ["P0", "P1", "P2", "P3"]:
        raise ValueError(f"Invalid priority: {wo['priority']}")
    
    return True

