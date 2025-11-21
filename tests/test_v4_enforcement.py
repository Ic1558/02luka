#!/usr/bin/env python3
"""
V4 Enforcement Test Suite
Tests FDE validator, Memory Hub API, and persona contract compliance.
"""

import unittest
import sys
import os
import json
import tempfile
import shutil
from pathlib import Path

# Add repo root to path
REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT))

from agents.memory_hub.memory_hub import load_memory, save_memory, get_ledger_path
from g.core.fde.fde_validator import validate


class TestFDEValidator(unittest.TestCase):
    """Test FDE Validator enforcement rules."""
    
    def test_legacy_zone_blocked(self):
        """Test that writes to legacy zones are blocked."""
        result = validate("write", "g/g/test.txt", {})
        self.assertFalse(result["allowed"])
        self.assertEqual(result["rule_id"], "legacy_zone_protection")
        self.assertIn("g/g", result["reason"])
    
    def test_feature_dev_missing_directory(self):
        """Test that feature dev without directory is blocked."""
        result = validate("write", "g/reports/feature-dev/nonexistent-feat/code.py", {})
        self.assertFalse(result["allowed"])
        self.assertEqual(result["rule_id"], "feature_development")
        self.assertIn("does not exist", result["reason"])
    
    def test_feature_dev_missing_artifacts(self):
        """Test that feature dev without spec/plan is blocked."""
        # Create temp feature dir without artifacts
        test_dir = REPO_ROOT / "g" / "reports" / "feature-dev" / "test-fde-missing"
        test_dir.mkdir(parents=True, exist_ok=True)
        
        try:
            result = validate("write", str(test_dir / "code.py"), {})
            self.assertFalse(result["allowed"])
            self.assertEqual(result["rule_id"], "feature_development")
            self.assertIn("Missing required artifacts", result["reason"])
        finally:
            shutil.rmtree(test_dir, ignore_errors=True)
    
    def test_feature_dev_with_artifacts_allowed(self):
        """Test that feature dev with spec/plan is allowed."""
        # Create temp feature dir with artifacts
        test_dir = REPO_ROOT / "g" / "reports" / "feature-dev" / "test-fde-valid"
        test_dir.mkdir(parents=True, exist_ok=True)
        
        try:
            # Create spec and plan
            (test_dir / "251121_test_spec_v01.md").touch()
            (test_dir / "251121_test_plan_v01.md").touch()
            
            result = validate("write", str(test_dir / "code.py"), {})
            self.assertTrue(result["allowed"])
            self.assertIsNone(result["rule_id"])
        finally:
            shutil.rmtree(test_dir, ignore_errors=True)
    
    def test_spec_plan_write_allowed(self):
        """Test that writing spec/plan files themselves is allowed."""
        result = validate("write", "g/reports/feature-dev/new-feat/spec_v01.md", {})
        # Should not be blocked by feature_dev rule since we're writing the spec itself
        self.assertTrue(result["allowed"])


class TestMemoryHub(unittest.TestCase):
    """Test Memory Hub API."""
    
    def setUp(self):
        """Set up test agent."""
        self.test_agent = "test_v4_agent"
        self.ledger_path = get_ledger_path(self.test_agent)
        # Clean up any existing test ledger
        if self.ledger_path.exists():
            self.ledger_path.unlink()
    
    def tearDown(self):
        """Clean up test ledger."""
        if self.ledger_path.exists():
            self.ledger_path.unlink()
    
    def test_save_and_load_memory(self):
        """Test saving and loading memory."""
        learning = "Test learning for V4 suite"
        
        # Save
        success = save_memory(self.test_agent, "success", learning)
        self.assertTrue(success)
        
        # Load
        learnings = load_memory(self.test_agent, limit=1)
        self.assertEqual(len(learnings), 1)
        self.assertEqual(learnings[0], learning)
    
    def test_load_empty_memory(self):
        """Test loading from non-existent ledger."""
        learnings = load_memory("nonexistent_agent", limit=5)
        self.assertEqual(learnings, [])
    
    def test_save_empty_learning_rejected(self):
        """Test that empty learnings are rejected."""
        success = save_memory(self.test_agent, "success", "")
        self.assertFalse(success)
        
        success = save_memory(self.test_agent, "success", "   ")
        self.assertFalse(success)
    
    def test_multiple_learnings_order(self):
        """Test that multiple learnings are returned in correct order."""
        learnings_to_save = [
            "First learning",
            "Second learning",
            "Third learning"
        ]
        
        for learning in learnings_to_save:
            save_memory(self.test_agent, "success", learning)
        
        loaded = load_memory(self.test_agent, limit=3)
        self.assertEqual(loaded, learnings_to_save)
    
    def test_limit_respected(self):
        """Test that limit parameter is respected."""
        for i in range(10):
            save_memory(self.test_agent, "success", f"Learning {i}")
        
        loaded = load_memory(self.test_agent, limit=5)
        self.assertEqual(len(loaded), 5)
        # Should get the last 5
        self.assertEqual(loaded[0], "Learning 5")
        self.assertEqual(loaded[4], "Learning 9")


class TestPersonaCompliance(unittest.TestCase):
    """Test persona contract compliance."""
    
    def test_liam_persona_has_v4_contract(self):
        """Test that Liam's persona has V4 Universal Contract."""
        liam_persona = REPO_ROOT / "agents" / "liam" / "PERSONA_PROMPT.md"
        self.assertTrue(liam_persona.exists())
        
        content = liam_persona.read_text()
        self.assertIn("V4 Universal Contract", content)
        self.assertIn("memory_hub.memory_hub", content)
        self.assertIn("load_memory", content)
        self.assertIn("save_memory", content)
    
    def test_gmx_persona_has_v4_contract(self):
        """Test that GMX's persona has V4 Universal Contract."""
        gmx_persona = REPO_ROOT / "agents" / "gmx" / "PERSONA_PROMPT.md"
        self.assertTrue(gmx_persona.exists())
        
        content = gmx_persona.read_text()
        self.assertIn("V4 Universal Contract", content)
        self.assertIn("memory_hub.memory_hub", content)


class TestV4Events(unittest.TestCase):
    """Test V4 AP/IO event definitions."""
    
    def test_event_module_imports(self):
        """Test that V4 event module can be imported."""
        try:
            from g.tools.ap_io_events import V4Events, log_fde_validation, log_memory_loaded
            self.assertTrue(True)
        except ImportError as e:
            self.fail(f"Failed to import V4 events: {e}")
    
    def test_event_names_defined(self):
        """Test that all V4 event names are defined."""
        from g.tools.ap_io_events import V4Events
        
        # FDE events
        self.assertTrue(hasattr(V4Events, 'FDE_VALIDATION_PASSED'))
        self.assertTrue(hasattr(V4Events, 'FDE_VALIDATION_FAILED'))
        
        # Memory events
        self.assertTrue(hasattr(V4Events, 'MEMORY_LOADED'))
        self.assertTrue(hasattr(V4Events, 'MEMORY_SAVED'))
        
        # Persona events
        self.assertTrue(hasattr(V4Events, 'PERSONA_MIGRATED'))


def run_tests():
    """Run all tests and return results."""
    loader = unittest.TestLoader()
    suite = unittest.TestSuite()
    
    # Add all test classes
    suite.addTests(loader.loadTestsFromTestCase(TestFDEValidator))
    suite.addTests(loader.loadTestsFromTestCase(TestMemoryHub))
    suite.addTests(loader.loadTestsFromTestCase(TestPersonaCompliance))
    suite.addTests(loader.loadTestsFromTestCase(TestV4Events))
    
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    
    return result.wasSuccessful()


if __name__ == "__main__":
    success = run_tests()
    sys.exit(0 if success else 1)
