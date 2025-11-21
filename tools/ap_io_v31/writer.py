import json
import uuid
import datetime
import os
from typing import Any, Optional

LEDGER_PATH = "g/ledger/ap_io_v31.jsonl"

def write_ledger_entry(
    agent: str,
    event: str,
    data: dict[str, Any],
    parent_id: Optional[str] = None,
    correlation_id: Optional[str] = None,
    execution_duration_ms: Optional[int] = None,
) -> str:
    """
    Writes a new entry to the AP/IO v3.1 ledger.
    Returns the generated ledger_id.
    """
    ledger_id = str(uuid.uuid4())
    timestamp = datetime.datetime.utcnow().isoformat() + "Z"
    
    entry = {
        "ledger_id": ledger_id,
        "parent_id": parent_id,
        "correlation_id": correlation_id,
        "timestamp": timestamp,
        "agent": agent,
        "event": event,
        "data": data,
        "execution_duration_ms": execution_duration_ms,
    }
    
    # Ensure directory exists
    os.makedirs(os.path.dirname(LEDGER_PATH), exist_ok=True)
    
    with open(LEDGER_PATH, "a") as f:
        f.write(json.dumps(entry) + "\n")
        
    return ledger_id
