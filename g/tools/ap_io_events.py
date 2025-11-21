#!/usr/bin/env python3
"""
AP/IO V4 Event Definitions
Extends AP/IO v3.1 with V4-specific lifecycle events for FDE and Memory Hub.
"""

from typing import Dict, Any, Optional
from tools.ap_io_v31.writer import write_ledger_entry

# --- V4 Event Classes ---

class V4Events:
    """V4-specific event names for FDE and Memory lifecycle."""
    
    # FDE Events
    FDE_VALIDATION_PASSED = "v4_fde_validation_passed"
    FDE_VALIDATION_FAILED = "v4_fde_validation_failed"
    FDE_OVERRIDE_REQUESTED = "v4_fde_override_requested"
    
    # Memory Events
    MEMORY_LOADED = "v4_memory_loaded"
    MEMORY_SAVED = "v4_memory_saved"
    MEMORY_VALIDATION_PASSED = "v4_memory_validation_passed"
    MEMORY_VALIDATION_FAILED = "v4_memory_validation_failed"
    
    # Persona Events
    PERSONA_MIGRATED = "v4_persona_migrated"
    PERSONA_VALIDATION_PASSED = "v4_persona_validation_passed"
    PERSONA_VALIDATION_FAILED = "v4_persona_validation_failed"

# --- Helper Functions ---

def log_fde_validation(
    agent: str,
    action: str,
    path: str,
    allowed: bool,
    rule_id: Optional[str] = None,
    reason: Optional[str] = None,
    parent_id: Optional[str] = None
) -> str:
    """Log an FDE validation event."""
    event = V4Events.FDE_VALIDATION_PASSED if allowed else V4Events.FDE_VALIDATION_FAILED
    
    data = {
        "action": action,
        "path": path,
        "allowed": allowed,
        "rule_id": rule_id,
        "reason": reason
    }
    
    return write_ledger_entry(
        agent=agent,
        event=event,
        data=data,
        parent_id=parent_id
    )

def log_memory_loaded(
    agent: str,
    agent_name: str,
    count: int,
    parent_id: Optional[str] = None
) -> str:
    """Log a memory load event."""
    data = {
        "agent_name": agent_name,
        "learnings_count": count
    }
    
    return write_ledger_entry(
        agent=agent,
        event=V4Events.MEMORY_LOADED,
        data=data,
        parent_id=parent_id
    )

def log_memory_saved(
    agent: str,
    agent_name: str,
    outcome: str,
    learning: str,
    parent_id: Optional[str] = None
) -> str:
    """Log a memory save event."""
    data = {
        "agent_name": agent_name,
        "outcome": outcome,
        "learning": learning
    }
    
    return write_ledger_entry(
        agent=agent,
        event=V4Events.MEMORY_SAVED,
        data=data,
        parent_id=parent_id
    )

def log_memory_validation(
    agent: str,
    passed: bool,
    validation_details: Dict[str, Any],
    parent_id: Optional[str] = None
) -> str:
    """Log a memory validation (Proof of Use) event."""
    event = V4Events.MEMORY_VALIDATION_PASSED if passed else V4Events.MEMORY_VALIDATION_FAILED
    
    return write_ledger_entry(
        agent=agent,
        event=event,
        data=validation_details,
        parent_id=parent_id
    )

def log_persona_migration(
    agent: str,
    persona_file: str,
    success: bool,
    details: Optional[Dict[str, Any]] = None,
    parent_id: Optional[str] = None
) -> str:
    """Log a persona migration event."""
    event = V4Events.PERSONA_MIGRATED
    
    data = {
        "persona_file": persona_file,
        "success": success,
        "details": details or {}
    }
    
    return write_ledger_entry(
        agent=agent,
        event=event,
        data=data,
        parent_id=parent_id
    )
