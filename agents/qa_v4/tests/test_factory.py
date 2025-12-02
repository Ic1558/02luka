"""
Unit tests for QA worker factory.
"""

import sys
from pathlib import Path

# Add project root to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent.parent))

from agents.qa_v4.factory import QAWorkerFactory, create_qa_worker, create_worker_for_task
from agents.qa_v4.workers import QAWorkerBasic, QAWorkerEnhanced, QAWorkerFull


class TestFactory:
    """Test factory functionality."""
    
    def test_create_basic(self):
        """Test creating basic worker."""
        worker = QAWorkerFactory.create("basic")
        assert isinstance(worker, QAWorkerBasic), f"Expected QAWorkerBasic, got {type(worker)}"
    
    def test_create_enhanced(self):
        """Test creating enhanced worker."""
        worker = QAWorkerFactory.create("enhanced")
        assert isinstance(worker, QAWorkerEnhanced), f"Expected QAWorkerEnhanced, got {type(worker)}"
    
    def test_create_full(self):
        """Test creating full worker."""
        worker = QAWorkerFactory.create("full")
        assert isinstance(worker, QAWorkerFull), f"Expected QAWorkerFull, got {type(worker)}"
    
    def test_create_invalid_mode(self):
        """Test creating worker with invalid mode (should fallback to basic)."""
        worker = QAWorkerFactory.create("invalid")
        assert isinstance(worker, QAWorkerBasic), f"Expected QAWorkerBasic for invalid mode, got {type(worker)}"
    
    def test_create_case_insensitive(self):
        """Test that mode is case-insensitive."""
        worker1 = QAWorkerFactory.create("FULL")
        worker2 = QAWorkerFactory.create("full")
        assert type(worker1) == type(worker2), "Case-insensitive mode should work"
    
    def test_create_for_task_basic(self):
        """Test create_for_task with basic mode selection."""
        result = QAWorkerFactory.create_for_task({
            "task_id": "WO-TEST",
            "files_touched": ["test.py"],
        })
        assert "worker" in result, "Result should contain 'worker'"
        assert "mode" in result, "Result should contain 'mode'"
        assert "reason" in result, "Result should contain 'reason'"
        assert isinstance(result["worker"], QAWorkerBasic), "Should create basic worker for default"
        assert result["mode"] == "basic", f"Expected 'basic', got '{result['mode']}'"
    
    def test_create_for_task_override(self):
        """Test create_for_task with mode override."""
        result = QAWorkerFactory.create_for_task({
            "task_id": "WO-TEST",
            "qa": {"mode": "full"},
        })
        assert result["mode"] == "full", f"Expected 'full', got '{result['mode']}'"
        assert isinstance(result["worker"], QAWorkerFull), "Should create full worker"
    
    def test_create_for_task_risk_based(self):
        """Test create_for_task with risk-based selection."""
        result = QAWorkerFactory.create_for_task({
            "task_id": "WO-TEST",
            "risk": {"level": "high", "domain": "security"},
            "files_touched": ["test.py"],
        })
        assert result["mode"] in {"full", "enhanced"}, f"Expected full/enhanced for high risk+security, got '{result['mode']}'"
    
    def test_helper_functions(self):
        """Test helper functions."""
        worker1 = create_qa_worker("basic")
        assert isinstance(worker1, QAWorkerBasic), "create_qa_worker should work"
        
        result = create_worker_for_task({
            "task_id": "WO-TEST",
            "files_touched": ["test.py"],
        })
        assert "worker" in result, "create_worker_for_task should work"


if __name__ == "__main__":
    # Run tests
    test = TestFactory()
    
    print("Running factory tests...")
    
    tests = [
        ("test_create_basic", test.test_create_basic),
        ("test_create_enhanced", test.test_create_enhanced),
        ("test_create_full", test.test_create_full),
        ("test_create_invalid_mode", test.test_create_invalid_mode),
        ("test_create_case_insensitive", test.test_create_case_insensitive),
        ("test_create_for_task_basic", test.test_create_for_task_basic),
        ("test_create_for_task_override", test.test_create_for_task_override),
        ("test_create_for_task_risk_based", test.test_create_for_task_risk_based),
        ("test_helper_functions", test.test_helper_functions),
    ]
    
    passed = 0
    failed = 0
    
    for name, test_func in tests:
        try:
            test_func()
            print(f"✅ {name}")
            passed += 1
        except AssertionError as e:
            print(f"❌ {name}: {e}")
            failed += 1
        except Exception as e:
            print(f"❌ {name}: {type(e).__name__}: {e}")
            failed += 1
    
    print(f"\n✅ Passed: {passed}, ❌ Failed: {failed}")
