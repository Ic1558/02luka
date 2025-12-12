#!/usr/bin/env python3
"""
Mary Router v5 — Governance v5 Compliant Routing Engine

This module implements the kernel-grade routing logic defined in:
- GOVERNANCE_UNIFIED_v5.md (Section 5: Routing Semantics)
- PERSONA_MODEL_v5.md (Section 3: Capability Matrix)
- SCOPE_DECLARATION_v1.md (Precedence Rules)

Author: 02luka System
Status: Implementation (Phase 3.3)
"""

import os
import json
import re
from pathlib import Path
from typing import Literal, Optional, Dict, List, Tuple
from dataclasses import dataclass
from enum import Enum

# ============================================================================
# TYPE DEFINITIONS (Kernel-Grade)
# ============================================================================

World = Literal["CLI", "BACKGROUND"]
Zone = Literal["OPEN", "LOCKED", "DANGER"]
Lane = Literal["FAST", "WARN", "STRICT", "BLOCKED"]
Actor = Literal[
    "Boss", "CLS", "Liam", "GMX", "Codex", "Gemini", "LAC",
    "GG", "GM", "Mary", "CLC", "LPE", "Cron", "Watchdog"
]
Operation = Literal["read", "write", "delete", "move", "exec"]


class WorldEnum(Enum):
    """Execution World (from GOVERNANCE v5 Section 1.1)"""
    CLI = "CLI"
    BACKGROUND = "BACKGROUND"


class ZoneEnum(Enum):
    """Zone Types (from GOVERNANCE v5 Section 3.1)"""
    OPEN = "OPEN"
    LOCKED = "LOCKED"
    DANGER = "DANGER"


class LaneEnum(Enum):
    """Lane Types (from GOVERNANCE v5 Section 5.3)"""
    FAST = "FAST"
    WARN = "WARN"
    STRICT = "STRICT"
    BLOCKED = "BLOCKED"


@dataclass
class RoutingDecision:
    """Router output structure (GOVERNANCE v5 Section 5.2)"""
    zone: Zone
    lane: Lane
    primary_writer: Optional[Actor]
    lawset: List[str]
    reason: str
    auto_approve_allowed: bool = False
    auto_approve_conditions: Optional[Dict[str, bool]] = None
    rollback_required: bool = False


# ============================================================================
# ZONE PATTERNS (from GOVERNANCE v5 Section 3.1)
# ============================================================================

# DANGER Zone patterns (checked first - highest priority)
DANGER_PATTERNS = [
    r"^/$",  # Root destructive ops
    r"^/System/",
    r"^/usr/",
    r"^/bin/",
    r"^/sbin/",
    r"^/etc/",
    r"^~/.ssh/",
    r"rm -rf.*02luka",  # Destructive ops on 02luka root
]

# LOCKED Zone patterns (from GOVERNANCE v5 Section 3.1)
LOCKED_PATTERNS = [
    r"^core/",
    r"^launchd/",
    r"^bridge/core/",
    r"^bridge/inbox/",
    r"^bridge/outbox/",
    r"^bridge/handlers/",
    r"^bridge/production/",
    r"^g/docs/governance/",
]

# OPEN Zone (default - everything else)
# No explicit patterns needed - resolved by exclusion

# ============================================================================
# MISSION SCOPE (from GOVERNANCE v5 Section 2.4)
# ============================================================================

# Mission Scope Whitelist (CLS Auto-approve allowed)
MISSION_SCOPE_WHITELIST = [
    r"^bridge/templates/",
    r"^g/reports/",
    r"^tools/",
    r"^agents/",
    r"^bridge/docs/",
]

# Mission Scope Blacklist (CLS Auto-approve NOT allowed)
MISSION_SCOPE_BLACKLIST = [
    r"^core/",
    r"^bridge/core/",
    r"^bridge/handlers/",
    r"^bridge/production/",
    r"^g/docs/governance/",
    r"^launchd/",
]


# ============================================================================
# CORE ROUTING FUNCTIONS
# ============================================================================

def get_luka_root() -> Path:
    """Resolve 02luka root directory."""
    env_root = os.environ.get("LUKA_ROOT") or os.environ.get("LUKA_SOT")
    if env_root:
        return Path(env_root).expanduser().resolve()
    return Path.home().joinpath("02luka").resolve()


def normalize_path(path_str: str) -> Tuple[Path, str]:
    """
    Normalize path against 02luka root.
    
    Returns:
        (absolute_path, relative_to_luka)
        If path is outside 02luka root, relative is empty string.
    """
    luka_root = get_luka_root()
    path = Path(path_str).expanduser()
    
    if not path.is_absolute():
        # Assume relative to current working directory
        path = Path.cwd() / path
    
    path = path.resolve()
    
    try:
        rel_path = path.relative_to(luka_root)
        return (path, str(rel_path))
    except ValueError:
        # Path is outside 02luka root
        return (path, "")


def resolve_world(trigger: str, context: Optional[Dict] = None) -> World:
    """
    Resolve execution world from trigger source.
    
    Logic (GOVERNANCE v5 Section 1.1):
    - Human trigger → CLI World
    - System trigger → Background World
    
    Args:
        trigger: Source of operation
            - "human", "cursor", "terminal", "antigravity", "gmx", "codex" → CLI
            - "cron", "launchd", "daemon", "queue", "worker" → BACKGROUND
        context: Optional metadata (WO id, session id, etc.)
    
    Returns:
        World enum
    
    Raises:
        ValueError: If trigger is invalid/unknown and cannot be safely resolved
    """
    # Validate trigger input
    if not trigger or not isinstance(trigger, str):
        # Invalid trigger → reject safely
        if context and context.get("wo_id"):
            # If we have WO context, assume BACKGROUND (safer for autonomous operations)
            return "BACKGROUND"
        # Otherwise, reject (unknown trigger without context)
        raise ValueError(f"Invalid trigger: {trigger!r}. Must be a non-empty string.")
    
    trigger_lower = trigger.lower().strip()
    
    if not trigger_lower:
        # Empty trigger after strip → reject
        raise ValueError(f"Empty trigger after normalization: {trigger!r}")
    
    # CLI World triggers (explicit list)
    cli_triggers = [
        "human", "boss", "cursor", "terminal", "antigravity",
        "gmx", "codex", "gemini", "lac", "cls", "liam"
    ]
    
    # Background World triggers (explicit list)
    bg_triggers = [
        "cron", "launchd", "daemon", "queue", "worker",
        "watchdog", "scheduler", "background"
    ]
    
    # Check for exact match or substring match (for backward compatibility)
    if any(t in trigger_lower for t in cli_triggers):
        return "CLI"
    
    if any(t in trigger_lower for t in bg_triggers):
        return "BACKGROUND"
    
    # Unknown trigger: Use context to decide safely
    if context and context.get("wo_id"):
        # Has WO context → assume BACKGROUND (safer for autonomous operations)
        return "BACKGROUND"
    
    # Unknown trigger without context → reject (don't default to CLI for unknown)
    raise ValueError(
        f"Unknown trigger: {trigger!r}. "
        f"Must be one of: {cli_triggers + bg_triggers}. "
        f"Or provide WO context for BACKGROUND world."
    )


def resolve_zone(path_str: str) -> Zone:
    """
    Resolve zone from path.
    
    Algorithm (GOVERNANCE v5 Section 3.2):
    1. Check DANGER patterns first (highest priority)
    2. Check LOCKED patterns
    3. Default to OPEN
    
    Args:
        path_str: Path to check (can be absolute or relative)
    
    Returns:
        Zone enum
    """
    _, rel_path = normalize_path(path_str)
    
    # If outside 02luka root, treat as DANGER
    if not rel_path:
        return "DANGER"
    
    # Normalize path separators
    rel_path = rel_path.replace("\\", "/")
    
    # Check DANGER patterns first (ordered priority)
    for pattern in DANGER_PATTERNS:
        if re.match(pattern, rel_path) or re.search(pattern, rel_path):
            return "DANGER"
    
    # Check LOCKED patterns
    for pattern in LOCKED_PATTERNS:
        if re.match(pattern, rel_path):
            return "LOCKED"
    
    # Default: OPEN
    return "OPEN"


def check_mission_scope(path_str: str) -> Tuple[bool, bool]:
    """
    Check if path is in Mission Scope Whitelist/Blacklist.
    
    Returns:
        (is_whitelisted, is_blacklisted)
    """
    _, rel_path = normalize_path(path_str)
    
    if not rel_path:
        return (False, True)  # Outside root = blacklisted
    
    rel_path = rel_path.replace("\\", "/")
    
    # Check blacklist first (takes precedence)
    for pattern in MISSION_SCOPE_BLACKLIST:
        if re.match(pattern, rel_path):
            return (False, True)
    
    # Check whitelist
    for pattern in MISSION_SCOPE_WHITELIST:
        if re.match(pattern, rel_path):
            return (True, False)
    
    return (False, False)


def check_cls_auto_approve_conditions(
    actor: Actor,
    zone: Zone,
    path_str: str,
    context: Optional[Dict] = None
) -> Tuple[bool, Dict[str, bool]]:
    """
    Check if CLS can auto-approve (GOVERNANCE v5 Section 5.3).
    
    Conditions (ALL must be met):
    1. Actor is CLS
    2. Zone is LOCKED
    3. Path in Mission Scope Whitelist
    4. Risk level = LOW (non-governance, non-routing, non-security)
    5. Rollback strategy exists
    6. Full audit log enabled
    7. Boss previously approved similar patterns
    
    Returns:
        (can_auto_approve, conditions_status)
    """
    if actor != "CLS" or zone != "LOCKED":
        return (False, {})
    
    is_whitelisted, is_blacklisted = check_mission_scope(path_str)
    
    conditions = {
        "actor_is_cls": actor == "CLS",
        "zone_is_locked": zone == "LOCKED",
        "path_in_whitelist": is_whitelisted,
        "path_not_blacklisted": not is_blacklisted,
        "risk_level_low": True,  # TODO: Implement risk assessment
        "rollback_strategy_exists": context.get("rollback_strategy") is not None if context else False,
        "audit_log_enabled": True,  # Always enabled in v5
        "boss_approved_similar": context.get("boss_approved_pattern") is not None if context else False,
    }
    
    can_auto_approve = all(conditions.values())
    
    return (can_auto_approve, conditions)


def resolve_lane(world: World, zone: Zone, actor: Actor, op: Operation) -> Lane:
    """
    Resolve lane from world, zone, actor, and operation.
    
    Logic (GOVERNANCE v5 Section 5.3):
    - DANGER → BLOCKED (any world)
    - BACKGROUND → STRICT (any zone)
    - CLI + OPEN → FAST
    - CLI + LOCKED → WARN
    
    Args:
        world: Execution world
        zone: Zone type
        actor: Acting agent
        op: Operation type
    
    Returns:
        Lane enum
    """
    # DANGER zone → BLOCKED (highest priority)
    if zone == "DANGER":
        return "BLOCKED"
    
    # Background world → STRICT
    if world == "BACKGROUND":
        return "STRICT"
    
    # CLI world
    if world == "CLI":
        if zone == "OPEN":
            return "FAST"
        elif zone == "LOCKED":
            return "WARN"
    
    # Fallback (should not happen)
    return "BLOCKED"


def determine_primary_writer(
    world: World,
    zone: Zone,
    lane: Lane,
    actor: Actor
) -> Optional[Actor]:
    """
    Determine primary writer based on routing decision.
    
    Logic (GOVERNANCE v5 Section 4.2):
    - CLI World: Actor can write (if allowed by capability matrix)
    - Background World: CLC (or LPE in emergency)
    - BLOCKED: None
    
    Returns:
        Primary writer actor, or None if blocked
    """
    if lane == "BLOCKED":
        return None
    
    if world == "BACKGROUND":
        # Background world → CLC (or LPE in emergency)
        return "CLC"
    
    if world == "CLI":
        # CLI world → actor can write (if allowed)
        # Check capability matrix (PERSONA_MODEL_v5 Section 3.1)
        cli_writers = ["Boss", "CLS", "Liam", "GMX", "Codex", "Gemini", "LAC"]
        if actor in cli_writers:
            return actor
        
        # Planners cannot write
        if actor in ["GG", "GM"]:
            return None
        
        # Router cannot write
        if actor == "Mary":
            return None
        
        # Background actors sleep in CLI
        if actor in ["CLC", "LPE"]:
            return None
    
    return None


def determine_lawset(world: World, zone: Zone) -> List[str]:
    """
    Determine which governance documents apply.
    
    Logic (GOVERNANCE v5 Section 5.2, SCOPE_DECLARATION_v1):
    - Always: GOVERNANCE_UNIFIED_v5.md (kernel)
    - CLI World: HOWTO_TWO_WORLDS_v2.md
    - Background World: AI_OP_001_v5.md
    - Always: PERSONA_MODEL_v5.md (capabilities)
    
    Returns:
        List of governance document references
    """
    lawset = ["GOVERNANCE_UNIFIED_v5.md"]
    
    if world == "CLI":
        lawset.append("HOWTO_TWO_WORLDS_v2.md")
    elif world == "BACKGROUND":
        lawset.append("AI_OP_001_v5.md")
    
    lawset.append("PERSONA_MODEL_v5.md")
    
    return lawset


def route(
    trigger: str,
    actor: Actor,
    path: str,
    op: Operation = "write",
    context: Optional[Dict] = None
) -> RoutingDecision:
    """
    Main routing function (GOVERNANCE v5 Section 5.4).
    
    This is the core routing algorithm that implements:
    - World resolution
    - Zone resolution
    - Lane resolution
    - Primary writer determination
    - CLS auto-approve check
    
    Args:
        trigger: Source of operation (human/system)
        actor: Acting agent
        path: Target path
        op: Operation type
        context: Optional metadata (WO id, rollback strategy, etc.)
    
    Returns:
        RoutingDecision with all routing information
    """
    # Step 1: Resolve World (with safe error handling for unknown triggers)
    try:
        world = resolve_world(trigger, context)
    except ValueError as e:
        # Unknown/invalid trigger → BLOCKED lane (safe rejection)
        return RoutingDecision(
            zone="DANGER",  # Unknown trigger is dangerous
            lane="BLOCKED",
            primary_writer=None,
            lawset=[],
            reason=f"Invalid trigger rejected: {e}",
            auto_approve_allowed=False,
            rollback_required=False
        )
    
    # Step 2: Resolve Zone
    zone = resolve_zone(path)
    
    # Step 3: Resolve Lane
    lane = resolve_lane(world, zone, actor, op)
    
    # Step 4: Determine Primary Writer
    primary_writer = determine_primary_writer(world, zone, lane, actor)
    
    # Step 5: Determine Lawset
    lawset = determine_lawset(world, zone)
    
    # Step 6: Check CLS Auto-approve (if applicable)
    auto_approve_allowed = False
    auto_approve_conditions = None
    
    if lane == "WARN" and actor == "CLS":
        auto_approve_allowed, auto_approve_conditions = check_cls_auto_approve_conditions(
            actor, zone, path, context
        )
    
    # Step 7: Determine rollback requirement
    rollback_required = (
        lane == "WARN" or
        lane == "STRICT" or
        (auto_approve_allowed and auto_approve_conditions)
    )
    
    # Step 8: Generate reason
    reason = _generate_reason(world, zone, lane, actor, auto_approve_allowed)
    
    return RoutingDecision(
        zone=zone,
        lane=lane,
        primary_writer=primary_writer,
        lawset=lawset,
        reason=reason,
        auto_approve_allowed=auto_approve_allowed,
        auto_approve_conditions=auto_approve_conditions,
        rollback_required=rollback_required
    )


def _generate_reason(
    world: World,
    zone: Zone,
    lane: Lane,
    actor: Actor,
    auto_approve_allowed: bool
) -> str:
    """Generate human-readable reason for routing decision."""
    if lane == "BLOCKED":
        return f"DANGER zone operation blocked (world={world}, zone={zone})"
    
    if lane == "STRICT":
        return f"Background world requires WO → CLC (zone={zone})"
    
    if lane == "WARN":
        if auto_approve_allowed:
            return f"LOCKED zone - CLS auto-approve allowed (Mission Scope + safety conditions met)"
        return f"LOCKED zone - Boss/CLS override required or WO → CLC"
    
    if lane == "FAST":
        return f"OPEN zone - direct write allowed (world={world})"
    
    return "Unknown routing state"


# ============================================================================
# CLI INTERFACE
# ============================================================================

def main():
    """CLI entry point for router."""
    import argparse
    
    parser = argparse.ArgumentParser(
        description="Mary Router v5 — Governance v5 Compliant Routing Engine"
    )
    parser.add_argument("--trigger", required=True, help="Operation trigger (human/system)")
    parser.add_argument("--actor", required=True, help="Acting agent")
    parser.add_argument("--path", required=True, help="Target path")
    parser.add_argument("--op", default="write", choices=["read", "write", "delete", "move", "exec"])
    parser.add_argument("--json", action="store_true", help="Output JSON")
    parser.add_argument("--context", help="Context JSON (optional)")
    
    args = parser.parse_args()
    
    context = None
    if args.context:
        context = json.loads(args.context)
    
    decision = route(
        trigger=args.trigger,
        actor=args.actor,
        path=args.path,
        op=args.op,
        context=context
    )
    
    if args.json:
        output = {
            "zone": decision.zone,
            "lane": decision.lane,
            "primary_writer": decision.primary_writer,
            "lawset": decision.lawset,
            "reason": decision.reason,
            "auto_approve_allowed": decision.auto_approve_allowed,
            "auto_approve_conditions": decision.auto_approve_conditions,
            "rollback_required": decision.rollback_required,
        }
        print(json.dumps(output, indent=2))
    else:
        print("🚦 MARY ROUTER v5 DECISION:")
        print(f"   ZONE  : {decision.zone}")
        print(f"   LANE  : {decision.lane}")
        print(f"   WRITER: {decision.primary_writer}")
        print(f"   REASON: {decision.reason}")
        if decision.auto_approve_allowed:
            print(f"   ✅ CLS Auto-approve: ALLOWED")
            print(f"   Conditions: {decision.auto_approve_conditions}")
        print(f"   LAWSET: {', '.join(decision.lawset)}")


if __name__ == "__main__":
    main()

