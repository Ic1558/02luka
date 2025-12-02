"""
Unit tests for QA guardrails.
"""

import os
import sys
import json
from pathlib import Path
from datetime import datetime, timezone

# Add project root to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent.parent))

from agents.qa_v4.guardrails import QAModeGuardrails, get_guardrails


class TestGuardrails:
    """Test guardrails functionality."""
    
    def setup_method(self):
        """Setup test environment."""
        self.guardrails = QAModeGuardrails()
        self.budget_file = self.guardrails.budget_file
        self.budget_file.parent.mkdir(parents=True, exist_ok=True)
    
    def teardown_method(self):
        """Cleanup test environment."""
        if self.budget_file.exists():
            self.budget_file.unlink()
    
    def test_budget_check_basic(self):
        """Test budget check for basic mode (unlimited)."""
        allowed, reason = self.guardrails.check_budget("basic")
        assert allowed is True, "Basic mode should always be allowed"
        assert reason is None, "Basic mode should have no reason"
    
    def test_budget_check_under_limit(self):
        """Test budget check when under limit."""
        # Reset budget
        budget = {}
        today = datetime.now(timezone.utc).date().isoformat()
        budget[today] = {"full": 5, "enhanced": 20}
        
        with open(self.budget_file, "w") as f:
            json.dump(budget, f, indent=2)
        
        allowed, reason = self.guardrails.check_budget("full")
        assert allowed is True, "Should be allowed when under limit"
        assert reason is None, "Should have no reason when allowed"
    
    def test_budget_check_at_limit(self):
        """Test budget check when at limit."""
        # Set budget to limit
        budget = {}
        today = datetime.now(timezone.utc).date().isoformat()
        budget[today] = {"full": 10, "enhanced": 50}
        
        with open(self.budget_file, "w") as f:
            json.dump(budget, f, indent=2)
        
        allowed, reason = self.guardrails.check_budget("full")
        assert allowed is False, "Should not be allowed when at limit"
        assert "budget exceeded" in reason.lower(), f"Reason should mention budget, got '{reason}'"
    
    def test_record_usage(self):
        """Test recording usage."""
        # Reset budget
        budget = {}
        today = datetime.now(timezone.utc).date().isoformat()
        budget[today] = {"full": 0, "enhanced": 0}
        
        with open(self.budget_file, "w") as f:
            json.dump(budget, f, indent=2)
        
        # Record usage
        self.guardrails.record_usage("full")
        
        # Check budget
        status = self.guardrails.get_budget_status()
        assert status["full"]["used"] == 1, f"Expected 1 usage, got {status['full']['used']}"
    
    def test_record_usage_basic(self):
        """Test that basic mode doesn't record usage."""
        # Record usage for basic (should not increment)
        initial_status = self.guardrails.get_budget_status()
        self.guardrails.record_usage("basic")
        final_status = self.guardrails.get_budget_status()
        
        # Budget should be unchanged
        assert initial_status == final_status, "Basic mode should not record usage"
    
    def test_check_cooldown(self):
        """Test cooldown check."""
        should_upgrade, reason = self.guardrails.check_cooldown("test_module", recent_failures=0)
        assert should_upgrade is False, "Should not upgrade with no failures"
        
        should_upgrade, reason = self.guardrails.check_cooldown("test_module", recent_failures=2)
        assert should_upgrade is True, "Should upgrade with 2+ failures"
        assert "failures" in reason.lower(), f"Reason should mention failures, got '{reason}'"
    
    def test_check_performance(self):
        """Test performance check."""
        # Within threshold
        acceptable, reason = self.guardrails.check_performance("full", 25.0)
        assert acceptable is True, "Should be acceptable within threshold"
        assert reason is None, "Should have no reason when acceptable"
        
        # Exceeds threshold
        acceptable, reason = self.guardrails.check_performance("full", 35.0)
        assert acceptable is False, "Should not be acceptable when exceeds threshold"
        assert "latency" in reason.lower() or "exceeds" in reason.lower(), f"Reason should mention latency, got '{reason}'"
    
    def test_get_degraded_mode(self):
        """Test getting degraded mode."""
        assert self.guardrails.get_degraded_mode("full") == "enhanced", "Full should degrade to enhanced"
        assert self.guardrails.get_degraded_mode("enhanced") == "basic", "Enhanced should degrade to basic"
        assert self.guardrails.get_degraded_mode("basic") == "basic", "Basic should stay basic"
    
    def test_get_budget_status(self):
        """Test getting budget status."""
        status = self.guardrails.get_budget_status()
        assert "date" in status, "Status should contain date"
        assert "full" in status, "Status should contain full"
        assert "enhanced" in status, "Status should contain enhanced"
        assert "basic" in status, "Status should contain basic"
        assert status["full"]["limit"] == 10, "Full limit should be 10"
        assert status["enhanced"]["limit"] == 50, "Enhanced limit should be 50"
    
    def test_singleton_pattern(self):
        """Test singleton pattern."""
        guardrails1 = get_guardrails()
        guardrails2 = get_guardrails()
        assert guardrails1 is guardrails2, "Should return same instance (singleton)"


if __name__ == "__main__":
    # Run tests
    test = TestGuardrails()
    
    print("Running guardrails tests...")
    
    tests = [
        ("test_budget_check_basic", test.test_budget_check_basic),
        ("test_budget_check_under_limit", test.test_budget_check_under_limit),
        ("test_budget_check_at_limit", test.test_budget_check_at_limit),
        ("test_record_usage", test.test_record_usage),
        ("test_record_usage_basic", test.test_record_usage_basic),
        ("test_check_cooldown", test.test_check_cooldown),
        ("test_check_performance", test.test_check_performance),
        ("test_get_degraded_mode", test.test_get_degraded_mode),
        ("test_get_budget_status", test.test_get_budget_status),
        ("test_singleton_pattern", test.test_singleton_pattern),
    ]
    
    passed = 0
    failed = 0
    
    for name, test_func in tests:
        try:
            test.setup_method()
            test_func()
            test.teardown_method()
            print(f"✅ {name}")
            passed += 1
        except AssertionError as e:
            print(f"❌ {name}: {e}")
            failed += 1
        except Exception as e:
            print(f"❌ {name}: {type(e).__name__}: {e}")
            failed += 1
    
    print(f"\n✅ Passed: {passed}, ❌ Failed: {failed}")
