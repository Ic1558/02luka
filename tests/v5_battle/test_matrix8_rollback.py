#!/usr/bin/env python3
"""
Battle-Test Suite: Matrix 8 — Rollback Scenarios
Tests various rollback triggers and recovery strategies

Run: python3 -m pytest tests/v5_battle/test_matrix8_rollback.py -v
"""

import pytest
import sys
import os
import subprocess
import tempfile
import shutil
from pathlib import Path
from typing import List, Optional, Dict, Tuple
import json

sys.path.insert(0, str(Path(__file__).parent.parent.parent))

try:
    from agents.clc.executor_v5 import (
        apply_rollback, WorkOrder, ExecutionResult, WOStatus
    )
    HAS_ROLLBACK = True
except ImportError:
    HAS_ROLLBACK = False

from bridge.core.sandbox_guard_v5 import compute_file_checksum


class RollbackSimulator:
    """Simulates rollback scenarios"""
    
    def __init__(self, base_dir: Path):
        self.base_dir = base_dir
        self.snapshots: Dict[str, Dict[str, str]] = {}  # checkpoint -> {path: content}
        self.current_checkpoint = 0
    
    def snapshot(self, name: str = None) -> str:
        """Create a snapshot of current state"""
        if name is None:
            name = f"checkpoint_{self.current_checkpoint}"
            self.current_checkpoint += 1
        
        state = {}
        for path in self.base_dir.rglob("*"):
            if path.is_file() and not path.name.startswith("."):
                state[str(path.relative_to(self.base_dir))] = path.read_text()
        
        self.snapshots[name] = state
        return name
    
    def rollback_to(self, checkpoint: str) -> int:
        """Rollback to a checkpoint"""
        if checkpoint not in self.snapshots:
            raise ValueError(f"Checkpoint {checkpoint} not found")
        
        state = self.snapshots[checkpoint]
        restored = 0
        
        # Remove files not in snapshot
        current_files = set()
        for path in self.base_dir.rglob("*"):
            if path.is_file() and not path.name.startswith("."):
                rel_path = str(path.relative_to(self.base_dir))
                current_files.add(rel_path)
                if rel_path not in state:
                    path.unlink()
                    restored += 1
        
        # Restore content from snapshot
        for rel_path, content in state.items():
            full_path = self.base_dir / rel_path
            full_path.parent.mkdir(parents=True, exist_ok=True)
            
            if not full_path.exists() or full_path.read_text() != content:
                full_path.write_text(content)
                restored += 1
        
        return restored


class TestMatrix8RollbackScenarios:
    """Matrix 8: Rollback Scenarios (B8-01 to B8-05)"""
    
    # =========================================================================
    # B8-01: Manual Rollback Request
    # =========================================================================
    
    def test_B8_01_manual_rollback_single_file(self, tmp_path):
        """B8-01: Manual rollback of single file → Restored"""
        sim = RollbackSimulator(tmp_path)
        
        # Initial state
        (tmp_path / "config.yaml").write_text("version: 1.0")
        initial = sim.snapshot("initial")
        
        # Modify file
        (tmp_path / "config.yaml").write_text("version: 2.0")
        assert (tmp_path / "config.yaml").read_text() == "version: 2.0"
        
        # Rollback
        restored = sim.rollback_to("initial")
        
        assert restored >= 1
        assert (tmp_path / "config.yaml").read_text() == "version: 1.0"
    
    # =========================================================================
    # B8-02: Checksum Mismatch Triggers Rollback
    # =========================================================================
    
    def test_B8_02_checksum_mismatch_rollback(self, tmp_path):
        """B8-02: Checksum mismatch → Rollback triggered"""
        sim = RollbackSimulator(tmp_path)
        
        # Setup
        target = tmp_path / "data.txt"
        target.write_text("Original data")
        original_checksum = compute_file_checksum(str(target))
        sim.snapshot("before_write")
        
        # Write new content
        expected_content = "New data"
        target.write_text(expected_content)
        expected_checksum = compute_file_checksum(str(target))
        
        # Simulate corruption (checksum mismatch)
        target.write_text("Corrupted data!")
        actual_checksum = compute_file_checksum(str(target))
        
        if actual_checksum != expected_checksum:
            # Mismatch detected → rollback
            restored = sim.rollback_to("before_write")
            assert restored >= 1
            assert target.read_text() == "Original data"
    
    # =========================================================================
    # B8-03: WO Validation Failure Rollback
    # =========================================================================
    
    def test_B8_03_wo_validation_failure_all_restored(self, tmp_path):
        """B8-03: WO validation fails → All 3 files restored"""
        sim = RollbackSimulator(tmp_path)
        
        # Initial state with 3 files
        for i in range(1, 4):
            (tmp_path / f"file_{i}.txt").write_text(f"Original {i}")
        sim.snapshot("initial")
        
        # Attempt to modify all 3
        for i in range(1, 4):
            (tmp_path / f"file_{i}.txt").write_text(f"Modified {i}")
        
        # WO validation fails (simulated)
        wo_valid = False
        
        if not wo_valid:
            restored = sim.rollback_to("initial")
            assert restored == 3
            
            for i in range(1, 4):
                assert (tmp_path / f"file_{i}.txt").read_text() == f"Original {i}"
    
    # =========================================================================
    # B8-04: Partial Rollback (Sandbox Block Mid-Operation)
    # =========================================================================
    
    def test_B8_04_sandbox_block_partial_rollback(self, tmp_path):
        """B8-04: Sandbox blocks at file 3 of 5 → Rollback files 1-2"""
        sim = RollbackSimulator(tmp_path)
        
        # Initial empty state
        sim.snapshot("initial")
        
        # Write files 1-2 successfully
        (tmp_path / "file_1.txt").write_text("Content 1")
        (tmp_path / "file_2.txt").write_text("Content 2")
        
        # File 3 blocked by sandbox
        sandbox_blocked = True
        
        if sandbox_blocked:
            # Partial rollback - restore initial (no files)
            restored = sim.rollback_to("initial")
            
            # Files 1-2 should be removed
            assert not (tmp_path / "file_1.txt").exists()
            assert not (tmp_path / "file_2.txt").exists()
    
    # =========================================================================
    # B8-05: System Crash Recovery
    # =========================================================================
    
    def test_B8_05_crash_recovery_with_temp(self, tmp_path):
        """B8-05: System crash mid-write → Recovery depends on SIP stage"""
        target = tmp_path / "critical.txt"
        temp = tmp_path / ".critical.tmp"
        
        # Case 1: Crash before atomic move - original safe
        target.write_text("Original safe content")
        original_checksum = compute_file_checksum(str(target))
        
        # Simulate crash during temp write
        temp.write_text("Partial new content")  # Temp exists but not complete
        
        # Recovery: temp file indicates incomplete operation
        if temp.exists():
            # Check if temp is complete (in real impl, check checksum)
            temp_valid = False  # Simulated incomplete
            
            if not temp_valid:
                # Discard temp, keep original
                temp.unlink()
                assert target.read_text() == "Original safe content"
        
        # Case 2: Crash after atomic move - new content committed
        target.write_text("New committed content")
        # No temp file = operation completed
        assert not temp.exists()


class TestMatrix8ComplexRollback:
    """Complex rollback scenarios"""
    
    def test_cascading_rollback(self, tmp_path):
        """Rollback triggers cascading rollbacks in dependent files"""
        sim = RollbackSimulator(tmp_path)
        
        # Setup dependency chain
        (tmp_path / "config.yaml").write_text("db: localhost")
        (tmp_path / "service.yaml").write_text("config: config.yaml")
        (tmp_path / "app.yaml").write_text("service: service.yaml")
        sim.snapshot("stable")
        
        # Modify config (root of chain)
        (tmp_path / "config.yaml").write_text("db: production-db")
        
        # This breaks service dependency check
        config_valid = False
        
        if not config_valid:
            # Must rollback config and all dependents
            restored = sim.rollback_to("stable")
            assert restored >= 1
            assert (tmp_path / "config.yaml").read_text() == "db: localhost"
    
    def test_git_revert_strategy(self, tmp_path):
        """Test git revert rollback strategy"""
        # Initialize git repo
        subprocess.run(["git", "init"], cwd=tmp_path, capture_output=True)
        subprocess.run(["git", "config", "user.email", "test@test.com"], cwd=tmp_path, capture_output=True)
        subprocess.run(["git", "config", "user.name", "Test"], cwd=tmp_path, capture_output=True)
        
        # Initial commit
        (tmp_path / "file.txt").write_text("Version 1")
        subprocess.run(["git", "add", "."], cwd=tmp_path, capture_output=True)
        subprocess.run(["git", "commit", "-m", "v1"], cwd=tmp_path, capture_output=True)
        
        # Second commit
        (tmp_path / "file.txt").write_text("Version 2")
        subprocess.run(["git", "add", "."], cwd=tmp_path, capture_output=True)
        subprocess.run(["git", "commit", "-m", "v2"], cwd=tmp_path, capture_output=True)
        
        # Git restore to previous version
        result = subprocess.run(
            ["git", "restore", "file.txt"],
            cwd=tmp_path,
            capture_output=True
        )
        
        # Without staging, restore just restores working tree
        # Use git checkout HEAD~1 -- file.txt for previous version
        subprocess.run(
            ["git", "checkout", "HEAD~1", "--", "file.txt"],
            cwd=tmp_path,
            capture_output=True
        )
        
        assert (tmp_path / "file.txt").read_text() == "Version 1"
    
    def test_backup_restore_strategy(self, tmp_path):
        """Test backup-based rollback strategy"""
        # Create backup directory structure
        backup_dir = tmp_path / "_backup"
        backup_dir.mkdir()
        
        work_dir = tmp_path / "work"
        work_dir.mkdir()
        
        # Original file
        original = work_dir / "data.json"
        original.write_text('{"version": 1}')
        
        # Create backup before modification
        backup_file = backup_dir / "data.json.bak"
        shutil.copy(original, backup_file)
        
        # Modify file
        original.write_text('{"version": 2, "invalid": true}')
        
        # Validation fails
        valid = False
        
        if not valid:
            # Restore from backup
            shutil.copy(backup_file, original)
            assert json.loads(original.read_text())["version"] == 1


class TestMatrix8RollbackEdgeCases:
    """Edge cases for rollback"""
    
    def test_rollback_deleted_file(self, tmp_path):
        """Rollback should recreate deleted file"""
        sim = RollbackSimulator(tmp_path)
        
        # File exists
        (tmp_path / "important.txt").write_text("Critical data")
        sim.snapshot("with_file")
        
        # Delete file
        (tmp_path / "important.txt").unlink()
        assert not (tmp_path / "important.txt").exists()
        
        # Rollback should recreate
        restored = sim.rollback_to("with_file")
        assert restored == 1
        assert (tmp_path / "important.txt").read_text() == "Critical data"
    
    def test_rollback_new_file_removal(self, tmp_path):
        """Rollback should remove newly created files"""
        sim = RollbackSimulator(tmp_path)
        
        # Empty state
        sim.snapshot("empty")
        
        # Create new file
        (tmp_path / "unwanted.txt").write_text("Should not exist")
        
        # Rollback should remove
        restored = sim.rollback_to("empty")
        assert not (tmp_path / "unwanted.txt").exists()
    
    def test_rollback_nested_directory(self, tmp_path):
        """Rollback handles nested directory structures"""
        sim = RollbackSimulator(tmp_path)
        
        # Create nested structure
        nested = tmp_path / "level1" / "level2" / "level3"
        nested.mkdir(parents=True)
        (nested / "deep.txt").write_text("Deep content")
        sim.snapshot("nested")
        
        # Modify deep file
        (nested / "deep.txt").write_text("Modified deep")
        
        # Rollback
        restored = sim.rollback_to("nested")
        assert (nested / "deep.txt").read_text() == "Deep content"
    
    def test_rollback_with_no_changes(self, tmp_path):
        """Rollback with no changes should be no-op"""
        sim = RollbackSimulator(tmp_path)
        
        (tmp_path / "stable.txt").write_text("Unchanged")
        sim.snapshot("stable")
        
        # No modifications
        
        # Rollback should be no-op
        restored = sim.rollback_to("stable")
        assert restored == 0
        assert (tmp_path / "stable.txt").read_text() == "Unchanged"


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
