"""
I/O utilities for CLS Cursor Wrapper.
"""

import json
import time
from pathlib import Path
from typing import Dict, Optional


def drop_wo_to_inbox(wo: Dict, inbox_path: Path) -> Path:
    """
    Write Work Order JSON to inbox.
    Returns path to written file.
    """
    wo_id = wo["wo_id"]
    wo_file = inbox_path / f"{wo_id}.json"
    
    # Atomic write: write to temp, then move
    temp_file = wo_file.with_suffix(".tmp")
    with temp_file.open("w", encoding="utf-8") as f:
        json.dump(wo, f, indent=2, ensure_ascii=False)
    
    temp_file.replace(wo_file)
    
    return wo_file


def poll_for_result(
    wo_id: str,
    outbox_path: Path,
    timeout_seconds: int = 60,
    poll_interval: float = 1.0,
) -> Optional[Dict]:
    """
    Poll outbox for result JSON matching wo_id.
    Returns result dict if found, None if timeout.
    """
    result_pattern = f"{wo_id}*RESULT.json"
    start_time = time.time()
    
    while time.time() - start_time < timeout_seconds:
        # Look for matching result file
        matching_files = list(outbox_path.glob(result_pattern))
        
        if matching_files:
            # Read first matching file
            result_file = matching_files[0]
            try:
                with result_file.open("r", encoding="utf-8") as f:
                    return json.load(f)
            except (json.JSONDecodeError, IOError) as e:
                # Invalid JSON or read error - continue polling
                pass
        
        time.sleep(poll_interval)
    
    return None  # Timeout


def format_result_summary(result: Dict) -> str:
    """
    Format result JSON into human-readable summary for Cursor.
    """
    wo_id = result.get("wo_id", "unknown")
    status = result.get("status", "unknown")
    
    lines = [
        f"✅ CLS Processing Complete",
        f"WO-ID: {wo_id}",
        f"Status: {status}",
    ]
    
    if "files_touched" in result:
        files = result["files_touched"]
        if files:
            lines.append(f"\nFiles Modified ({len(files)}):")
            for file in files[:10]:  # Limit to 10 files
                lines.append(f"  • {file}")
            if len(files) > 10:
                lines.append(f"  ... and {len(files) - 10} more")
    
    if "merge_type" in result:
        lines.append(f"\nMerge Type: {result['merge_type']}")
    
    if "used_clc" in result:
        lines.append(f"Used CLC: {result['used_clc']}")
    
    if "used_paid" in result:
        lines.append(f"Used Paid Lane: {result['used_paid']}")
    
    if "errors" in result and result["errors"]:
        lines.append(f"\n⚠️ Errors:")
        for error in result["errors"][:5]:
            lines.append(f"  • {error}")
    
    return "\n".join(lines)


def format_timeout_message(wo_id: str, outbox_path: Path) -> str:
    """
    Format timeout message for user.
    """
    return (
        f"⏳ CLS processing is still running.\n"
        f"WO-ID: {wo_id}\n"
        f"Check results later in: {outbox_path}"
    )


def format_error_message(error_type: str, detail: str) -> str:
    """
    Format error message for user.
    """
    return f"❌ CLS wrapper: {error_type}: {detail}"

