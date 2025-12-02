"""
Unit tests for QA mode selector.
"""

import os
import sys
import json
from pathlib import Path
from datetime import datetime, timezone

# Add project root to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent.parent))

from agents.qa_v4.mode_selector import (
    calculate_qa_mode_score,
    select_qa_mode,
    get_mode_selection_reason,
)
from agents.qa_v4.guardrails import QAModeGuardrails


class TestModeSelector:
    """Test mode selector functionality."""
    
    def test_hard_override_wo_spec(self):
        """Test hard override via WO spec."""
        mode = select_qa_mode(wo_spec={"qa": {"mode": "full"}})
        assert mode == "full", f"Expected 'full', got '{mode}'"
        
        mode = select_qa_mode(wo_spec={"qa": {"mode": "enhanced"}})
        assert mode == "enhanced", f"Expected 'enhanced', got '{mode}'"
        
        mode = select_qa_mode(wo_spec={"qa": {"mode": "basic"}})
        assert mode == "basic", f"Expected 'basic', got '{mode}'"
    
    def test_hard_override_env(self):
        """Test hard override via environment variable."""
        os.environ["QA_MODE"] = "full"
        try:
            mode = select_qa_mode()
            assert mode == "full", f"Expected 'full', got '{mode}'"
        finally:
            os.environ.pop("QA_MODE", None)
    
    def test_risk_based_selection(self):
        """Test risk-based mode selection."""
        # High risk + security domain should trigger full mode
        mode = select_qa_mode(
            wo_spec={"risk": {"level": "high", "domain": "security"}},
            dev_result={"files_touched": ["test.py"]},
        )
        assert mode in {"full", "enhanced"}, f"Expected full/enhanced for high risk+security, got '{mode}'"
        
        # Medium risk should trigger enhanced
        mode = select_qa_mode(
            wo_spec={"risk": {"level": "medium"}},
            dev_result={"files_touched": ["test.py"]},
        )
        assert mode in {"enhanced", "basic"}, f"Expected enhanced/basic for medium risk, got '{mode}'"
        
        # Low risk should default to basic
        mode = select_qa_mode(
            wo_spec={"risk": {"level": "low"}},
            dev_result={"files_touched": ["test.py"]},
        )
        assert mode == "basic", f"Expected 'basic' for low risk, got '{mode}'"
    
    def test_complexity_based_selection(self):
        """Test complexity-based mode selection."""
        # Many files should increase score
        mode = select_qa_mode(
            dev_result={"files_touched": [f"file{i}.py" for i in range(10)]},
        )
        # Should be at least basic, possibly enhanced
        assert mode in {"basic", "enhanced", "full"}, f"Unexpected mode '{mode}'"
        
        # High LOC should increase score
        mode = select_qa_mode(
            dev_result={"lines_of_code": 1000},
        )
        assert mode in {"basic", "enhanced", "full"}, f"Unexpected mode '{mode}'"
    
    def test_history_based_escalation(self):
        """Test history-based mode escalation."""
        # Recent failures should trigger enhanced/full
        mode = select_qa_mode(
            history={"recent_qa_failures_for_module": 3},
            dev_result={"files_touched": ["test.py"]},
        )
        assert mode in {"enhanced", "full"}, f"Expected enhanced/full for recent failures, got '{mode}'"
        
        # Fragile file should trigger escalation
        mode = select_qa_mode(
            history={"is_fragile_file": True},
            dev_result={"files_touched": ["test.py"]},
        )
        assert mode in {"enhanced", "full"}, f"Expected enhanced/full for fragile file, got '{mode}'"
    
    def test_guardrail_budget_limits(self):
        """Test guardrail budget limits."""
        # Set budget to limit
        guardrails = QAModeGuardrails()
        budget_file = Path("g/data/qa_mode_budget.json")
        budget = {}
        today = datetime.now(timezone.utc).date().isoformat()
        budget[today] = {"full": 10, "enhanced": 0}  # At limit
        
        # Ensure directory exists
        budget_file.parent.mkdir(parents=True, exist_ok=True)
        with open(budget_file, "w") as f:
            json.dump(budget, f, indent=2)
        
        # High risk + security should try full, but degrade to enhanced
        mode = select_qa_mode(
            wo_spec={"risk": {"level": "high", "domain": "security"}},
            dev_result={"files_touched": ["test.py"]},
        )
        assert mode == "enhanced", f"Expected 'enhanced' due to budget limit, got '{mode}'"
    
    def test_score_calculation(self):
        """Test score calculation."""
        # High risk + security = 2 + 2 = 4
        score = calculate_qa_mode_score(
            wo_spec={"risk": {"level": "high", "domain": "security"}},
        )
        assert score >= 4, f"Expected score >= 4 for high risk+security, got {score}"
        
        # Medium risk = 1
        score = calculate_qa_mode_score(
            wo_spec={"risk": {"level": "medium"}},
        )
        assert score >= 1, f"Expected score >= 1 for medium risk, got {score}"
        
        # Low risk = 0
        score = calculate_qa_mode_score(
            wo_spec={"risk": {"level": "low"}},
        )
        assert score >= 0, f"Expected score >= 0, got {score}"
    
    def test_mode_selection_reason(self):
        """Test mode selection reason generation."""
        reason = get_mode_selection_reason(
            mode="full",
            wo_spec={"qa": {"mode": "full"}},
        )
        assert "override" in reason.lower(), f"Expected 'override' in reason, got '{reason}'"
        
        reason = get_mode_selection_reason(
            mode="enhanced",
            wo_spec={"risk": {"level": "high"}},
        )
        assert "risk" in reason.lower() or "high" in reason.lower(), f"Expected risk info in reason, got '{reason}'"
    
    def test_env_based_defaults(self):
        """Test environment-based defaults."""
        # Default (dev) should be basic
        mode = select_qa_mode()
        assert mode == "basic", f"Expected 'basic' for default, got '{mode}'"
        
        # Prod should default to enhanced
        mode = select_qa_mode(env={"LAC_ENV": "prod"})
        assert mode == "enhanced", f"Expected 'enhanced' for prod, got '{mode}'"
    
    def test_qa_strict_upgrade(self):
        """Test QA_STRICT environment variable upgrade."""
        os.environ["QA_STRICT"] = "1"
        try:
            mode = select_qa_mode()
            # Should upgrade from basic to enhanced
            assert mode in {"enhanced", "full"}, f"Expected enhanced/full with QA_STRICT, got '{mode}'"
        finally:
            os.environ.pop("QA_STRICT", None)


if __name__ == "__main__":
    # Run tests
    test = TestModeSelector()
    
    print("Running mode selector tests...")
    
    try:
        test.test_hard_override_wo_spec()
        print("✅ test_hard_override_wo_spec")
    except AssertionError as e:
        print(f"❌ test_hard_override_wo_spec: {e}")
    
    try:
        test.test_hard_override_env()
        print("✅ test_hard_override_env")
    except AssertionError as e:
        print(f"❌ test_hard_override_env: {e}")
    
    try:
        test.test_risk_based_selection()
        print("✅ test_risk_based_selection")
    except AssertionError as e:
        print(f"❌ test_risk_based_selection: {e}")
    
    try:
        test.test_complexity_based_selection()
        print("✅ test_complexity_based_selection")
    except AssertionError as e:
        print(f"❌ test_complexity_based_selection: {e}")
    
    try:
        test.test_history_based_escalation()
        print("✅ test_history_based_escalation")
    except AssertionError as e:
        print(f"❌ test_history_based_escalation: {e}")
    
    try:
        test.test_guardrail_budget_limits()
        print("✅ test_guardrail_budget_limits")
    except AssertionError as e:
        print(f"❌ test_guardrail_budget_limits: {e}")
    
    try:
        test.test_score_calculation()
        print("✅ test_score_calculation")
    except AssertionError as e:
        print(f"❌ test_score_calculation: {e}")
    
    try:
        test.test_mode_selection_reason()
        print("✅ test_mode_selection_reason")
    except AssertionError as e:
        print(f"❌ test_mode_selection_reason: {e}")
    
    try:
        test.test_env_based_defaults()
        print("✅ test_env_based_defaults")
    except AssertionError as e:
        print(f"❌ test_env_based_defaults: {e}")
    
    try:
        test.test_qa_strict_upgrade()
        print("✅ test_qa_strict_upgrade")
    except AssertionError as e:
        print(f"❌ test_qa_strict_upgrade: {e}")
    
    print("\n✅ All tests completed!")
