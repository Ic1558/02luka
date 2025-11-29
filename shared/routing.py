"""
Shared Routing Engine - LAC v4
Implements "Free-First" Model Strategy and Cost Guards.
"""
import os
import yaml
from typing import Dict, Any, Optional

# Default configuration (Free-First)
DEFAULT_ROUTING_CONFIG = {
    "routing_rules": {
        "simple": {
            "file_count_max": 3,
            "lane": "dev_oss",
            "model": "deepseek-coder",
            "cost": 0
        },
        "moderate": {
            "file_count_max": 10,
            "lane": "dev_gmxcli",
            "model": "gemini-2.0-flash-thinking-exp",
            "cost": 0
        },
        "complex": {
            "file_count_min": 10,
            "lane": "dev_paid",
            "model": "claude-sonnet-4",
            "requires_approval": True
        }
    },
    "paid_lanes": {
        "enabled": False,  # OFF by default
        "emergency_budget_thb": 50
    }
}

def load_routing_config() -> Dict[str, Any]:
    """Load routing config from file or return default."""
    config_path = "config/routing_rules.yaml"
    if os.path.exists(config_path):
        try:
            with open(config_path, 'r') as f:
                return yaml.safe_load(f) or DEFAULT_ROUTING_CONFIG
        except Exception:
            return DEFAULT_ROUTING_CONFIG
    return DEFAULT_ROUTING_CONFIG

def determine_lane(complexity: str, file_count: int = 0, hint: Optional[str] = None) -> Dict[str, Any]:
    """
    Determine the appropriate execution lane based on complexity and policy.
    
    Args:
        complexity: 'simple', 'moderate', or 'complex'
        file_count: Number of files involved (estimated)
        hint: Optional routing hint ('dev_oss', 'dev_gmxcli', 'dev_paid')
        
    Returns:
        Dict with 'lane', 'model', 'approved', 'reason'
    """
    config = load_routing_config()
    rules = config.get("routing_rules", DEFAULT_ROUTING_CONFIG["routing_rules"])
    paid_config = config.get("paid_lanes", DEFAULT_ROUTING_CONFIG["paid_lanes"])
    
    # 1. Honor Hints (if safe)
    if hint:
        if hint == "dev_oss":
            return {"lane": "dev_oss", "model": rules["simple"]["model"], "approved": True, "reason": "hint_oss"}
        if hint == "dev_gmxcli":
            return {"lane": "dev_gmxcli", "model": rules["moderate"]["model"], "approved": True, "reason": "hint_gmx"}
        if hint == "dev_codex":
            return {"lane": "dev_codex", "model": rules["moderate"]["model"], "approved": True, "reason": "hint_codex"}
        if hint == "dev_paid":
            # Paid hint requires checks
            if not paid_config.get("enabled", False):
                return {"lane": "dev_gmxcli", "model": rules["moderate"]["model"], "approved": False, "reason": "paid_disabled_fallback_gmx"}
            # In a real system, we'd check approval logs here.
            # For now, we assume if enabled=True, it's approved or will be requested.
            return {"lane": "dev_paid", "model": rules["complex"]["model"], "approved": True, "reason": "hint_paid_enabled"}

    # 2. Complexity-Based Routing
    if complexity == "simple" and file_count <= rules["simple"]["file_count_max"]:
        return {"lane": "dev_oss", "model": rules["simple"]["model"], "approved": True, "reason": "complexity_simple"}
    
    if complexity == "moderate" and file_count <= rules["moderate"]["file_count_max"]:
        return {"lane": "dev_gmxcli", "model": rules["moderate"]["model"], "approved": True, "reason": "complexity_moderate"}
    
    # 3. Complex / Fallback
    # Default to GMX unless Paid is explicitly enabled
    if paid_config.get("enabled", False):
        return {"lane": "dev_paid", "model": rules["complex"]["model"], "approved": True, "reason": "complexity_complex_paid_enabled"}
    
    return {"lane": "dev_gmxcli", "model": rules["moderate"]["model"], "approved": True, "reason": "complexity_complex_fallback_gmx"}

def check_budget_guard(estimated_cost_thb: float) -> bool:
    """Check if cost is within emergency budget."""
    config = load_routing_config()
    limit = config.get("paid_lanes", {}).get("emergency_budget_thb", 50)
    # In a real implementation, we would check daily spend from a ledger.
    # For now, just check the limit against the estimate.
    return estimated_cost_thb <= limit
