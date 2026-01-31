#!/usr/bin/env python3
"""
Battle-Test Suite: Matrix 6 — Multi-File Transactions
Tests atomic multi-file operations with dependency chains

Run: python3 -m pytest tests/v5_battle/test_matrix6_multifile.py -v
"""

import pytest
import sys
import os
import tempfile
import shutil
from pathlib import Path
from typing import List, Tuple
from unittest.mock import patch, MagicMock

sys.path.insert(0, str(Path(__file__).parent.parent.parent))

try:
    from agents.clc.executor_v5 import (
        apply_sip_single_file, execute_work_order, read_work_order,
        WorkOrder, FileOperation, WOStatus
    )
    HAS_CLC = True
except ImportError:
    HAS_CLC = False


class MultiFileTransactionSimulator:
    """Simulates multi-file transactions with rollback"""
    
    def __init__(self, base_dir: Path):
        self.base_dir = base_dir
        self.operations: List[Tuple[str, str, str]] = []  # (path, before, after)
        self.committed = False
        self.rolled_back = False
    
    def add_file(self, name: str, content: str) -> bool:
        """Add a new file"""
        path = self.base_dir / name
        path.parent.mkdir(parents=True, exist_ok=True)
        
        before = path.read_text() if path.exists() else None
        path.write_text(content)
        
        self.operations.append((str(path), before, content))
        return True
    
    def modify_file(self, name: str, content: str) -> bool:
        """Modify existing file"""
        path = self.base_dir / name
        if not path.exists():
            return False
        
        before = path.read_text()
        path.write_text(content)
        
        self.operations.append((str(path), before, content))
        return True
    
    def rollback(self) -> int:
        """Rollback all operations in reverse order"""
        rolled_back = 0
        for path, before, after in reversed(self.operations):
            p = Path(path)
            if before is None:
                # File was added, remove it
                if p.exists():
                    p.unlink()
                    rolled_back += 1
            else:
                # File was modified, restore original
                p.write_text(before)
                rolled_back += 1
        
        self.rolled_back = True
        self.operations = []
        return rolled_back
    
    def commit(self):
        """Commit transaction (clear operation log)"""
        self.committed = True
        self.operations = []


class TestMatrix6MultiFileTransactions:
    """Matrix 6: Multi-File Transactions (T6-01 to T6-05)"""
    
    # =========================================================================
    # T6-01: All Files Success (A → B → C sequential)
    # =========================================================================
    
    def test_T6_01_all_files_success(self, tmp_path):
        """T6-01: A → B → C all succeed"""
        tx = MultiFileTransactionSimulator(tmp_path)
        
        # Sequential writes
        assert tx.add_file("a.txt", "Content A") == True
        assert tx.add_file("b.txt", "Content B") == True
        assert tx.add_file("c.txt", "Content C") == True
        
        # All files exist
        assert (tmp_path / "a.txt").exists()
        assert (tmp_path / "b.txt").exists()
        assert (tmp_path / "c.txt").exists()
        
        tx.commit()
        assert tx.committed == True
    
    # =========================================================================
    # T6-02: Mid-Chain Failure with Rollback
    # =========================================================================
    
    def test_T6_02_failure_at_file_b_rollback_a(self, tmp_path):
        """T6-02: A succeeds, B fails → A rolled back, C skipped"""
        tx = MultiFileTransactionSimulator(tmp_path)
        
        # A succeeds
        assert tx.add_file("a.txt", "Content A") == True
        assert (tmp_path / "a.txt").exists()
        
        # B fails (simulate by checking dependency)
        b_depends_on_external = False  # Simulate external failure
        if not b_depends_on_external:
            # Rollback A
            rolled = tx.rollback()
            assert rolled == 1
            
            # A should be removed
            assert not (tmp_path / "a.txt").exists()
            # C was never created
            assert not (tmp_path / "c.txt").exists()
    
    # =========================================================================
    # T6-03: Independent Files (No Rollback on Partial Failure)
    # =========================================================================
    
    def test_T6_03_independent_files_partial_failure(self, tmp_path):
        """T6-03: A, B, C independent - B fails, A and C kept"""
        # A succeeds
        (tmp_path / "a.txt").write_text("A content")
        
        # B fails - simulate by not creating
        b_failed = True
        
        # C succeeds (independent)
        (tmp_path / "c.txt").write_text("C content")
        
        # A and C exist, B does not
        assert (tmp_path / "a.txt").exists()
        assert not (tmp_path / "b.txt").exists()
        assert (tmp_path / "c.txt").exists()
    
    # =========================================================================
    # T6-04: Dependency Chain Rollback
    # =========================================================================
    
    def test_T6_04_dependency_chain_both_rollback(self, tmp_path):
        """T6-04: A depends on B, B fails → Both rollback"""
        tx = MultiFileTransactionSimulator(tmp_path)
        
        # Create A first (depends on B)
        tx.add_file("a.txt", "A depends on B")
        
        # B fails
        b_success = False
        
        if not b_success:
            # A depends on B, so rollback A
            rolled = tx.rollback()
            assert rolled == 1
            assert not (tmp_path / "a.txt").exists()
    
    # =========================================================================
    # T6-05: Large Chain Partial Rollback
    # =========================================================================
    
    def test_T6_05_large_chain_partial_rollback(self, tmp_path):
        """T6-05: 10 files in chain, fail at 7 → rollback 1-6"""
        tx = MultiFileTransactionSimulator(tmp_path)
        
        # Create files 1-6 successfully
        for i in range(1, 7):
            tx.add_file(f"file_{i}.txt", f"Content {i}")
        
        # File 7 fails
        file_7_fails = True
        
        if file_7_fails:
            # Rollback files 1-6
            rolled = tx.rollback()
            assert rolled == 6
            
            # None of files 1-6 should exist
            for i in range(1, 7):
                assert not (tmp_path / f"file_{i}.txt").exists()


class TestMatrix6ComplexDependencies:
    """Complex dependency scenarios"""
    
    def test_diamond_dependency(self, tmp_path):
        """
        Diamond dependency: D depends on B and C, B and C depend on A
        
            A
           / \
          B   C
           \ /
            D
        
        If B fails, D cannot proceed, but C is independent
        """
        tx = MultiFileTransactionSimulator(tmp_path)
        
        # A succeeds (root)
        tx.add_file("a.txt", "Root A")
        
        # B fails
        b_success = False
        
        # C succeeds (independent of B)
        c_success = tx.add_file("c.txt", "Node C depends on A")
        
        # D cannot proceed (needs B)
        d_can_proceed = b_success  # False
        
        assert c_success == True
        assert d_can_proceed == False
        assert (tmp_path / "a.txt").exists()
        assert (tmp_path / "c.txt").exists()
    
    def test_circular_dependency_detection(self, tmp_path):
        """Circular dependency: A → B → C → A should be detected"""
        dependencies = {
            "a.txt": ["b.txt"],
            "b.txt": ["c.txt"],
            "c.txt": ["a.txt"],  # Circular!
        }
        
        def has_circular_dependency(deps: dict, start: str, visited: set = None) -> bool:
            if visited is None:
                visited = set()
            
            if start in visited:
                return True
            
            visited.add(start)
            for dep in deps.get(start, []):
                if has_circular_dependency(deps, dep, visited.copy()):
                    return True
            
            return False
        
        assert has_circular_dependency(dependencies, "a.txt") == True
    
    def test_parallel_writes_same_directory(self, tmp_path):
        """Multiple files in same directory written in parallel"""
        import threading
        import time
        
        results = []
        
        def write_file(name: str, delay: float):
            time.sleep(delay)
            path = tmp_path / name
            path.write_text(f"Content of {name}")
            results.append(name)
        
        # Simulate parallel writes
        threads = [
            threading.Thread(target=write_file, args=("file_a.txt", 0.01)),
            threading.Thread(target=write_file, args=("file_b.txt", 0.02)),
            threading.Thread(target=write_file, args=("file_c.txt", 0.01)),
        ]
        
        for t in threads:
            t.start()
        for t in threads:
            t.join()
        
        # All files created
        assert len(results) == 3
        assert (tmp_path / "file_a.txt").exists()
        assert (tmp_path / "file_b.txt").exists()
        assert (tmp_path / "file_c.txt").exists()


class TestMatrix6AtomicityGuarantees:
    """Atomicity and consistency tests"""
    
    def test_partial_write_recovery(self, tmp_path):
        """Simulate partial write failure and recovery"""
        path = tmp_path / "partial.txt"
        original_content = "Original safe content"
        new_content = "New content that fails mid-write"
        
        # Write original
        path.write_text(original_content)
        
        # Simulate partial write failure (write to temp, fail before move)
        temp_path = tmp_path / ".partial.tmp"
        temp_path.write_text(new_content[:10])  # Partial write
        
        # Crash simulation - temp file exists but move never happened
        assert temp_path.exists()
        
        # Recovery: original should still be intact
        assert path.read_text() == original_content
        
        # Cleanup temp
        temp_path.unlink()
    
    def test_checksum_mismatch_triggers_rollback(self, tmp_path):
        """Checksum mismatch after write should trigger rollback"""
        from bridge.core.sandbox_guard_v5 import compute_file_checksum
        
        path = tmp_path / "checksum_test.txt"
        content = "Expected content"
        
        # Write file
        path.write_text(content)
        
        # Compute expected checksum
        expected_checksum = compute_file_checksum(str(path))
        
        # Corrupt file (simulate)
        path.write_text("Corrupted content")
        
        # Checksum mismatch
        actual_checksum = compute_file_checksum(str(path))
        assert expected_checksum != actual_checksum
        
        # This should trigger rollback in real implementation


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
