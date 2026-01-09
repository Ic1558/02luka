#!/usr/bin/env python3
import os
import sys
import json
import shutil
import pathlib
import unittest
import tempfile
from unittest.mock import patch

# Add repo root to path to import the engine
REPO_ROOT = pathlib.Path(__file__).parent.parent.resolve()
sys.path.insert(0, str(REPO_ROOT / "tools"))

import build_core_history_engine as engine

class TestCoreHistory(unittest.TestCase):
    def setUp(self):
        self.test_dir = pathlib.Path(tempfile.mkdtemp())
        self.env_patcher = patch.dict(os.environ, {
            "REPO_ROOT": str(self.test_dir),
            "CORE_HISTORY_NOW": "2025-01-01T12:00:00Z"
        })
        self.env_patcher.start()
        
        # Setup directories
        (self.test_dir / "g" / "telemetry").mkdir(parents=True)
        (self.test_dir / "g" / "core_history").mkdir(parents=True)
        
        # Mock rule source
        (self.test_dir / "decision_summarizer.py").write_text("R5_DEFAULT")

    def tearDown(self):
        self.env_patcher.stop()
        shutil.rmtree(self.test_dir)

    def test_build_success_and_schema(self):
        # Create dummy decision log
        log_path = self.test_dir / "g" / "telemetry" / "decision_log.jsonl"
        log_path.write_text('{"ts": "2025-01-01T10:00:00Z", "matched_rules": ["R5_DEFAULT"], "risk": "low"}\n')
        
        exit_code = engine.build()
        self.assertEqual(exit_code, 0)
        
        latest_path = self.test_dir / "g" / "core_history" / "latest.json"
        self.assertTrue(latest_path.exists())
        
        data = json.loads(latest_path.read_text())
        # P0 Requirement: Schema version
        self.assertEqual(data["metadata"]["schema_version"], "core_history.v1")
        # P0 Requirement: Deterministic generated_at_utc (frozen)
        self.assertEqual(data["metadata"]["generated_at_utc"], "2025-01-01T12:00:00Z")

    def test_missing_input_exit_code(self):
        # No decision log present
        exit_code = engine.build()
        # P0 Requirement: Exit code 2 for missing inputs
        self.assertEqual(exit_code, 2)
        
        # Should still generate artifacts (minimal mode)
        self.assertTrue((self.test_dir / "g" / "core_history" / "latest.json").exists())

if __name__ == "__main__":
    unittest.main()