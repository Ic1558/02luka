"""
QA Mode Selection Logic.

Determines appropriate QA mode based on:
- Hard overrides (WO/Requirement/Env)
- Risk & complexity
- History
- Environment
- Guardrails (budget limits, performance)

Returns: "basic" | "enhanced" | "full"
"""

import os
import json
from pathlib import Path
from typing import Dict, Any, Optional
from datetime import datetime, timezone

# Import guardrails (with fallback)
try:
    from agents.qa_v4.guardrails import get_guardrails
except ImportError:
    # Fallback if guardrails not available
    def get_guardrails():
        return None


def calculate_qa_mode_score(
    wo_spec: Optional[Dict[str, Any]] = None,
    requirement: Optional[Dict[str, Any]] = None,
    dev_result: Optional[Dict[str, Any]] = None,
    history: Optional[Dict[str, Any]] = None,
    env: Optional[Dict[str, Any]] = None,
) -> int:
    """
    Calculate score for QA mode selection.
    
    Scoring factors:
    - Risk level: high (+2), medium (+1), low (0)
    - Domain: security/auth/payment (+2), api (+1), generic (0)
    - Complexity: files >5 (+1), LOC >800 (+1)
    - History: recent failures >=2 (+1), fragile file (+1)
    
    Returns: Score (0-10)
    """
    score = 0
    wo_spec = wo_spec or {}
    requirement = requirement or {}
    dev_result = dev_result or {}
    history = history or {}
    env = env or {}
    
    # Risk factors
    risk = wo_spec.get("risk", {}) or requirement.get("risk", {})
    risk_level = risk.get("level", "low")
    if risk_level == "high":
        score += 2
    elif risk_level == "medium":
        score += 1
    
    domain = risk.get("domain", "generic")
    if domain in {"security", "auth", "payment"}:
        score += 2
    elif domain == "api":
        score += 1
    
    # Complexity
    files = dev_result.get("files_touched", [])
    if isinstance(files, str):
        files = [files]
    if len(files) > 5:
        score += 1
    
    loc = dev_result.get("lines_of_code", 0)
    if loc > 800:
        score += 1
    
    # History
    recent_failures = history.get("recent_qa_failures_for_module", 0)
    if recent_failures >= 2:
        score += 1
    
    fragile_file = history.get("is_fragile_file", False)
    if fragile_file:
        score += 1
    
    return score


def select_qa_mode(
    wo_spec: Optional[Dict[str, Any]] = None,
    requirement: Optional[Dict[str, Any]] = None,
    dev_result: Optional[Dict[str, Any]] = None,
    history: Optional[Dict[str, Any]] = None,
    env: Optional[Dict[str, Any]] = None,
) -> str:
    """
    Select appropriate QA mode.
    
    Priority:
    1. Hard override (WO/Requirement/Env) - highest priority
    2. Env-based defaults (prod → enhanced, dev → basic)
    3. QA_STRICT upgrade (upgrade by 1 level)
    4. Score-based upgrade (score >=4 → full, >=2 → enhanced)
    
    Args:
        wo_spec: Work order spec (optional)
        requirement: Requirement doc (optional)
        dev_result: Dev worker result (optional)
        history: History data (optional)
        env: Environment dict (optional)
    
    Returns:
        "basic" | "enhanced" | "full"
    """
    wo_spec = wo_spec or {}
    requirement = requirement or {}
    env = env or {}
    
    # 1. Hard override (highest priority)
    explicit_mode = (
        wo_spec.get("qa", {}).get("mode") or
        requirement.get("qa", {}).get("mode") or
        os.getenv("QA_MODE")
    )
    if explicit_mode in {"basic", "enhanced", "full"}:
        return explicit_mode
    
    # 2. Env-based defaults
    lac_env = env.get("LAC_ENV") or os.getenv("LAC_ENV", "dev")
    default_mode = "enhanced" if lac_env == "prod" else "basic"
    
    # 3. QA_STRICT upgrade
    if os.getenv("QA_STRICT") == "1":
        if default_mode == "basic":
            default_mode = "enhanced"
        elif default_mode == "enhanced":
            default_mode = "full"
    
    # 4. Score-based upgrade
    score = calculate_qa_mode_score(wo_spec, requirement, dev_result, history, env)
    
    if score >= 4:
        selected_mode = "full"
    elif score >= 2:
        selected_mode = "enhanced"
    else:
        selected_mode = default_mode
    
    # 5. Apply guardrails (budget limits, cooldown)
    guardrails = get_guardrails()
    degradation_reason = None
    if guardrails:
        # Check budget - keep degrading until we find an allowed mode
        current_mode = selected_mode
        while current_mode != "basic":
            allowed, budget_reason = guardrails.check_budget(current_mode)
            if allowed:
                selected_mode = current_mode
                break
            else:
                # Degrade mode
                degraded_mode = guardrails.get_degraded_mode(current_mode)
                if degraded_mode == current_mode:
                    # Can't degrade further
                    break
                current_mode = degraded_mode
                degradation_reason = budget_reason
        else:
            # Fallback to basic if all else fails
            selected_mode = "basic"
            if not degradation_reason:
                degradation_reason = "Budget limits exhausted, degraded to basic"
    
    return selected_mode


def get_mode_selection_reason(
    mode: str,
    wo_spec: Optional[Dict[str, Any]] = None,
    requirement: Optional[Dict[str, Any]] = None,
    dev_result: Optional[Dict[str, Any]] = None,
    history: Optional[Dict[str, Any]] = None,
    env: Optional[Dict[str, Any]] = None,
) -> str:
    """
    Generate human-readable reason for mode selection.
    
    Args:
        mode: Selected mode
        wo_spec: Work order spec
        requirement: Requirement doc
        dev_result: Dev worker result
        history: History data
        env: Environment dict
    
    Returns:
        Human-readable reason string
    """
    reasons = []
    wo_spec = wo_spec or {}
    requirement = requirement or {}
    env = env or {}
    
    # Check override
    explicit = (
        wo_spec.get("qa", {}).get("mode") or
        requirement.get("qa", {}).get("mode") or
        os.getenv("QA_MODE")
    )
    if explicit:
        reasons.append(f"override={explicit}")
        return ", ".join(reasons)
    
    # Check score factors
    risk = wo_spec.get("risk", {}) or requirement.get("risk", {})
    
    if risk.get("level") == "high":
        reasons.append("risk.level=high")
    if risk.get("domain") in {"security", "auth", "payment"}:
        reasons.append(f"domain={risk.get('domain')}")
    
    files = (dev_result or {}).get("files_touched", [])
    if isinstance(files, str):
        files = [files]
    if len(files) > 5:
        reasons.append(f"files_count={len(files)}")
    
    if not reasons:
        lac_env = env.get("LAC_ENV") or os.getenv("LAC_ENV", "dev")
        reasons.append(f"env_default={lac_env}")
    
    return ", ".join(reasons) if reasons else "default"


def log_mode_decision(
    task_id: str,
    mode: str,
    reason: str,
    score: int,
    override: bool,
    inputs: Dict[str, Any],
    degraded: bool = False,
    degradation_reason: Optional[str] = None,
) -> None:
    """
    Log mode decision to telemetry.
    
    Args:
        task_id: Task identifier
        mode: Selected mode
        reason: Human-readable reason
        score: Calculated score
        override: Whether mode was overridden
        inputs: Input parameters for debugging
        degraded: Whether mode was degraded by guardrails
        degradation_reason: Reason for degradation (if any)
    """
    telemetry_file = Path("g/telemetry/qa_mode_decisions.jsonl")
    telemetry_file.parent.mkdir(parents=True, exist_ok=True)
    
    entry = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "task_id": task_id,
        "mode_selected": mode,
        "mode_reason": reason,
        "mode_score": score,
        "override": override,
        "degraded": degraded,
        "inputs": inputs,
    }
    
    if degradation_reason:
        entry["degradation_reason"] = degradation_reason
    
    try:
        with open(telemetry_file, "a") as f:
            f.write(json.dumps(entry) + "\n")
    except Exception as e:
        # Silent failure - don't break QA if telemetry write fails
        print(f"[QA Mode Selector] Warning: Failed to log mode decision: {e}", file=os.sys.stderr)


__all__ = [
    "calculate_qa_mode_score",
    "select_qa_mode",
    "get_mode_selection_reason",
    "log_mode_decision",
]
