#!/usr/bin/env python3
"""
MLS Logging Function - Agent Protocol Layer
Async, non-blocking wrapper for mls_add.zsh

Usage:
    from g.tools.mls_log import mls_log
    
    # Fire-and-forget logging
    mls_log("solution", "Task completed", {"result": "success"}, "gmx")
"""

import subprocess
import json
import threading
from datetime import datetime, timezone
from typing import Dict, Any, Optional, List
from pathlib import Path


def mls_log(
    event_type: str,
    title: str,
    summary: str,
    agent_name: str,
    state: Optional[Dict[str, Any]] = None,
    tags: Optional[List[str]] = None,
    confidence: float = 0.9,
    wo_id: Optional[str] = None,
) -> None:
    """
    Log an event to MLS asynchronously (fire-and-forget).
    
    Args:
        event_type: "solution", "failure", "improvement", "pattern", "session_state"
        title: Event title (concise)
        summary: Event summary (detailed)
        agent_name: Name of the agent logging the event
        state: Optional state dict (for session_state events)
        tags: Optional list of tags
        confidence: Confidence score (0.0-1.0)
        wo_id: Optional Work Order ID
    
    Returns:
        None (async, fire-and-forget)
    
    Example:
        mls_log(
            "solution",
            "QA Worker executed",
            "All checks passed",
            "qa_worker",
            state={"files_checked": 5},
            tags=["qa", "automated"],
            confidence=0.95
        )
    """
    # Launch async thread (daemon=True for fire-and-forget)
    thread = threading.Thread(
        target=_log_sync,
        args=(event_type, title, summary, agent_name, state, tags, confidence, wo_id),
        daemon=True
    )
    thread.start()


def _log_sync(
    event_type: str,
    title: str,
    summary: str,
    agent_name: str,
    state: Optional[Dict[str, Any]],
    tags: Optional[List[str]],
    confidence: float,
    wo_id: Optional[str],
) -> None:
    """
    Synchronous logging function (called by async thread).
    Internal use only.
    """
    try:
        # Find mls_add.zsh
        project_root = Path(__file__).parent.parent.parent
        mls_add = project_root / "tools" / "mls_add.zsh"
        
        if not mls_add.exists():
            _log_error(f"mls_add.zsh not found at {mls_add}")
            return
        
        # Build tags
        tag_list = tags or []
        tag_list.extend(["agent", agent_name])
        tag_str = ",".join(tag_list)
        
        # Build summary (include state if present)
        full_summary = summary
        if state:
            full_summary += f" | State: {json.dumps(state)}"
        
        # Build command
        cmd = [
            str(mls_add),
            "--type", event_type,
            "--title", title,
            "--summary", full_summary,
            "--producer", agent_name,
            "--context", "antigravity",
            "--tags", tag_str,
            "--author", agent_name,
            "--confidence", str(confidence),
        ]
        
        # Add optional wo_id
        if wo_id:
            cmd.extend(["--wo-id", wo_id])
        
        # Execute (ignore output)
        subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=5,
            cwd=project_root
        )
        
    except Exception as e:
        _log_error(f"MLS logging failed: {e}")


def _log_error(message: str) -> None:
    """Log errors to file (silent failure)."""
    try:
        error_log = Path.home() / "LocalProjects" / "02luka_local_g" / "g" / "logs" / "mls_agent_errors.log"
        error_log.parent.mkdir(parents=True, exist_ok=True)
        
        timestamp = datetime.now(timezone.utc).isoformat()
        with open(error_log, "a") as f:
            f.write(f"[{timestamp}] {message}\n")
    except Exception:
        pass  # Ultimate silent failure


def mls_session_start(
    agent_name: str,
    task: str,
    files: List[str],
    conversation_id: Optional[str] = None,
) -> None:
    """
    Log session start event.
    
    Args:
        agent_name: Name of the agent
        task: Current task description
        files: List of files in context
        conversation_id: Optional conversation ID
    """
    state = {
        "current_task": task,
        "active_files": files,
        "decisions": [],
        "next_steps": []
    }
    
    tags = ["session", "start"]
    if conversation_id:
        tags.append(f"conv:{conversation_id}")
    
    mls_log(
        "session_state",
        f"{agent_name}: Starting task",
        task,
        agent_name,
        state=state,
        tags=tags,
        confidence=1.0
    )


def mls_session_end(
    agent_name: str,
    task: str,
    outcome: str,
    decisions: List[str],
    conversation_id: Optional[str] = None,
) -> None:
    """
    Log session end event.
    
    Args:
        agent_name: Name of the agent
        task: Task that was completed
        outcome: Outcome description
        decisions: List of key decisions made
        conversation_id: Optional conversation ID
    """
    state = {
        "current_task": task,
        "active_files": [],
        "decisions": decisions,
        "next_steps": []
    }
    
    tags = ["session", "end"]
    if conversation_id:
        tags.append(f"conv:{conversation_id}")
    
    mls_log(
        "session_state",
        f"{agent_name}: Task complete",
        outcome,
        agent_name,
        state=state,
        tags=tags,
        confidence=1.0
    )


if __name__ == "__main__":
    # Test
    print("Testing MLS logging...")
    mls_log(
        "solution",
        "Test: mls_log.py",
        "Testing async MLS logging from Python",
        "mls_log_test",
        state={"test": True},
        tags=["test"],
        confidence=1.0
    )
    print("Test event sent (check MLS ledger in 1-2 seconds)")
