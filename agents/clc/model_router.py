"""
CLC model router — optional specialist route logic.
Returns "clc_local" only for explicit/complex cases.
"""

from __future__ import annotations

from typing import Any, Dict, Optional


THRESHOLD_FILES = 3


def should_route_to_clc(wo: Dict[str, Any]) -> Optional[str]:
    """
    Decide whether to route a work order to CLC.
    Rules (align with lac_contract_v2, SPEC/PLAN v2):
      - requires_clc == True → route
      - complexity == "complex" → route
      - file_count (or len(files)) > THRESHOLD_FILES → route
    Otherwise, return None to stay on standard lanes.
    """
    if wo.get("requires_clc"):
        return "clc_local"

    if wo.get("complexity") == "complex":
        return "clc_local"

    file_count = wo.get("file_count")
    if file_count is None:
        files = wo.get("files") or []
        file_count = len(files)

    if file_count and file_count > THRESHOLD_FILES:
        return "clc_local"

    return None


__all__ = ["should_route_to_clc", "THRESHOLD_FILES"]
