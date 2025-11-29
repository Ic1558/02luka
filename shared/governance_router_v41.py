from __future__ import annotations

import logging
import os
from fnmatch import fnmatch
from pathlib import Path
from typing import Any, Dict, Iterable, List

import yaml

log = logging.getLogger(__name__)

# Canonical writer map to avoid case/alias drift.
CANON_WRITERS: Dict[str, str] = {
    "gg": "GG",
    "gc": "GC",
    "liam": "LIAM",
    "cls": "CLS",
    "codex": "CODEX",
    "gmx": "GMX",
    "clc": "CLC",
}

# Allowed dev lanes in the open zone.
OPEN_ZONE_LANES = {"dev_oss", "dev_gmxcli", "dev_codex"}


def _log_governance_event(event: str, **data: Any) -> None:
    """Lightweight structured logging for governance decisions."""
    if log.isEnabledFor(logging.INFO):
        log.info("governance.%s", event, extra={"governance": data})


def normalize_writer(writer: Any) -> str:
    """Return a canonical writer id; UNKNOWN if missing or unmapped."""
    if writer is None:
        return "UNKNOWN"
    key = str(writer).strip().lower()
    if not key:
        return "UNKNOWN"
    return CANON_WRITERS.get(key, "UNKNOWN")


def _definitions_path() -> Path:
    base_dir = os.getenv("LAC_BASE_DIR")
    root = Path(base_dir) if base_dir else Path.cwd()
    return root / "g/governance/zone_definitions_v41.yaml"


def _load_definitions() -> Dict[str, Any]:
    """
    Load zone definitions; fall back to a minimal secure set on error.
    """
    path = _definitions_path()
    fallback = {
        "version": "4.1",
        "zones": {
            "locked_zone": {
                "patterns": ["CLC/**", "CLS/**", "g/docs/AI_OP_001_v4.md"],
                "allowed_writers": ["CLC"],
            },
            "open_zone": {
                "patterns": ["agents/**", "g/config/**", "shared/**", "tests/**", "g/tools/**"],
                "allowed_writers": ["GG", "GC", "LIAM", "CLS", "CODEX", "GMX"],
            },
        },
    }
    if not path.exists():
        return fallback
    try:
        return yaml.safe_load(path.read_text(encoding="utf-8")) or fallback
    except Exception as exc:  # pragma: no cover - defensive fallback
        log.exception("Failed to load zone definitions: %s", exc)
        return fallback


def _iter_patterns(zone_key: str) -> Iterable[str]:
    defs = _load_definitions()
    return defs.get("zones", {}).get(zone_key, {}).get("patterns", []) or []


def _allowed_writers(zone_key: str) -> List[str]:
    defs = _load_definitions()
    return defs.get("zones", {}).get(zone_key, {}).get("allowed_writers", []) or []


def resolve_zone(files: List[str]) -> str:
    """
    Determine zone based on file paths.
    - Any locked pattern hit => locked_zone
    - All paths match open patterns => open_zone
    - Unknown/mixed => locked_zone (secure by default)
    - Empty list => open_zone (common for planning-only tasks)
    """
    if not files:
        return "open_zone"

    locked_patterns = list(_iter_patterns("locked_zone"))
    open_patterns = list(_iter_patterns("open_zone"))

    has_locked = False
    has_open = False

    for path in files:
        p = str(path)
        if any(fnmatch(p, pat) for pat in locked_patterns):
            has_locked = True
        elif any(fnmatch(p, pat) for pat in open_patterns):
            has_open = True
        else:
            # Unknown paths are treated as locked for safety.
            _log_governance_event("unknown_path_locked", path=p)
            has_locked = True

        if has_locked:
            # Locked wins immediately.
            return "locked_zone"

    return "open_zone" if has_open and not has_locked else "locked_zone"


def check_writer_permission(writer: str, zone: str) -> bool:
    writer_norm = normalize_writer(writer)
    if writer_norm == "UNKNOWN":
        return False
    if zone == "locked_zone":
        return writer_norm == "CLC"

    if zone == "open_zone":
        return writer_norm in _allowed_writers("open_zone")

    # Unknown zone is treated as locked by caller.
    return False


def policy_allow_lane(lane: str | None, zone: str, writer: str) -> bool:
    """
    Enforce lane-level rules:
    - Locked zone: no dev lane writes are allowed.
    - Open zone: allow OSS/GMX/Codex; else deny.
    """
    if lane is None:
        return True

    lane_norm = str(lane).strip()
    if zone == "locked_zone":
        return False

    if zone == "open_zone":
        return lane_norm in OPEN_ZONE_LANES

    return False


def evaluate_request(wo: Dict[str, Any]) -> Dict[str, Any]:
    """
    Evaluate a work order against governance rules.
    Returns a structured decision dict:
    {
      "ok": bool,
      "zone": "locked_zone" | "open_zone",
      "writer": "CLS",
      "lane": "dev_oss",
      "reason": "allowed" | "writer_not_allowed" | "lane_not_allowed" | "governance_error",
      "details": str,
    }
    """
    try:
        files = wo.get("files") or []
        # Source takes precedence over writer if both are present.
        writer_raw = wo.get("source") or wo.get("writer")
        lane = wo.get("routing_hint")

        writer = normalize_writer(writer_raw)
        zone = resolve_zone(files)

        if zone not in {"locked_zone", "open_zone"}:
            zone = "locked_zone"

        if not check_writer_permission(writer, zone):
            _log_governance_event(
                "writer_denied",
                writer_raw=writer_raw,
                writer_norm=writer,
                zone=zone,
                lane=lane,
            )
            return {
                "ok": False,
                "zone": zone,
                "writer": writer,
                "normalized_writer": writer,
                "lane": lane,
                "reason": "writer_not_allowed",
                "details": f"Writer {writer} not allowed for {zone}",
            }

        if not policy_allow_lane(lane, zone, writer):
            return {
                "ok": False,
                "zone": zone,
                "writer": writer,
                "normalized_writer": writer,
                "lane": lane,
                "reason": "lane_not_allowed",
                "details": f"Lane {lane} not allowed for {zone}",
            }

        return {
            "ok": True,
            "zone": zone,
            "writer": writer,
            "normalized_writer": writer,
            "lane": lane,
            "reason": "allowed",
            "details": "",
        }

    except Exception as exc:  # pragma: no cover - defensive path
        log.exception("Governance evaluation failed: %s", exc)
        return {
            "ok": False,
            "zone": "locked_zone",
            "writer": "UNKNOWN",
            "normalized_writer": "UNKNOWN",
            "lane": wo.get("routing_hint"),
            "reason": "governance_error",
            "details": str(exc),
        }


def to_telemetry_dict(result: Dict[str, Any]) -> Dict[str, Any]:
    """
    Convert an evaluate_request result to a telemetry-friendly dict.
    """
    return {
        "zone": result.get("zone"),
        "allowed": bool(result.get("ok")),
        "writer": result.get("writer"),
        "normalized_writer": result.get("normalized_writer", result.get("writer")),
        "lane": result.get("lane"),
        "reason": result.get("reason"),
        "details": result.get("details", ""),
    }


__all__ = [
    "normalize_writer",
    "resolve_zone",
    "check_writer_permission",
    "policy_allow_lane",
    "evaluate_request",
    "to_telemetry_dict",
]
