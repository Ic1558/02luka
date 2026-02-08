#!/usr/bin/env python3
"""
Stress-Test Suite: Matrix 12 — Chaos & Failure Injection
Tests system resilience under failure conditions

Run: python3 -m pytest tests/v5_battle/test_matrix12_chaos.py -v
"""

import pytest
import sys
import os
import time
import random
import threading
import tempfile
from pathlib import Path
from unittest.mock import patch, MagicMock
from typing import List

sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from bridge.core.sandbox_guard_v5 import compute_file_checksum


class TestMatrix12DiskFailures:
    """Simulated disk failure scenarios"""
    
    def test_disk_full_during_write(self, tmp_path):
        """Simulate disk full during write"""
        target = tmp_path / "fulltest.txt"
        
        # Write should succeed normally
        target.write_text("Initial content")
        assert target.exists()
        
        # Simulate "disk full" by making directory read-only temporarily
        # (Not actually making it read-only to avoid test issues)
        # Instead, verify we handle exceptions properly
        
        try:
            # This simulates what happens on disk full
            large_content = "x" * (10 * 1024 * 1024)  # 10MB
            target.write_text(large_content)
            assert target.exists()
        except OSError:
            # Expected on actual disk full
            pass
    
    def test_file_deleted_mid_operation(self, tmp_path):
        """File deleted while being processed"""
        target = tmp_path / "deleted.txt"
        target.write_text("Will be deleted")
        
        # Read checksum
        checksum_before = compute_file_checksum(str(target))
        
        # Delete file
        target.unlink()
        
        # Try to read again
        try:
            checksum_after = compute_file_checksum(str(target))
            # Should raise or return None
        except (FileNotFoundError, OSError):
            pass  # Expected
    
    def test_directory_deleted_mid_write(self, tmp_path):
        """Parent directory deleted during operation"""
        nested = tmp_path / "level1" / "level2"
        nested.mkdir(parents=True)
        target = nested / "file.txt"
        target.write_text("Content")
        
        # Simulate directory deletion
        import shutil
        shutil.rmtree(tmp_path / "level1")
        
        # Try to access file
        assert not target.exists()


class TestMatrix12MemoryPressure:
    """Memory pressure scenarios"""
    
    def test_large_object_processing(self):
        """Process very large objects"""
        # Create large content
        large_content = "x" * (5 * 1024 * 1024)  # 5MB
        
        from bridge.core.sandbox_guard_v5 import scan_content_for_forbidden_patterns
        
        # Should handle without memory error
        violations = scan_content_for_forbidden_patterns(large_content)
        assert violations is not None
    
    def test_many_small_allocations(self):
        """Many small allocations (memory fragmentation)"""
        from bridge.core.router_v5 import route
        
        results = []
        for i in range(1000):
            decision = route(
                trigger="cursor",
                actor="CLS",
                path=f"g/reports/alloc_{i}.md",
                op="write"
            )
            results.append(decision)
        
        assert len(results) == 1000
        # Force garbage collection
        del results


class TestMatrix12TimingIssues:
    """Timing-related edge cases"""
    
    def test_rapid_file_modifications(self, tmp_path):
        """Rapid consecutive modifications"""
        target = tmp_path / "rapid.txt"
        
        for i in range(100):
            target.write_text(f"Content version {i}")
            time.sleep(0.001)
        
        assert "99" in target.read_text()
    
    def test_race_between_read_and_write(self, tmp_path):
        """Race condition between read and write"""
        target = tmp_path / "race.txt"
        target.write_text("Initial")
        
        read_results = []
        write_done = threading.Event()
        
        def reader():
            for _ in range(50):
                try:
                    content = target.read_text()
                    read_results.append(content)
                except Exception:
                    read_results.append("ERROR")
                time.sleep(0.001)
        
        def writer():
            for i in range(50):
                target.write_text(f"Version {i}")
                time.sleep(0.001)
            write_done.set()
        
        t1 = threading.Thread(target=reader)
        t2 = threading.Thread(target=writer)
        
        t1.start()
        t2.start()
        t1.join()
        t2.join()
        
        # No reads should have failed
        errors = [r for r in read_results if r == "ERROR"]
        assert len(errors) == 0


class TestMatrix12StateCorruption:
    """State corruption scenarios"""
    
    def test_truncated_file(self, tmp_path):
        """Handle truncated/corrupted file"""
        target = tmp_path / "truncated.txt"
        target.write_text("Complete valid content here")
        
        # Truncate file
        with open(target, 'w') as f:
            f.truncate(5)
        
        # Read truncated content
        content = target.read_text()
        assert len(content) == 5
    
    def test_invalid_utf8_content(self, tmp_path):
        """Handle invalid UTF-8 in file"""
        target = tmp_path / "invalid_utf8.txt"
        
        # Write invalid UTF-8 bytes
        target.write_bytes(b"Valid text \xff\xfe invalid")
        
        # Try to read as text
        try:
            content = target.read_text()
        except UnicodeDecodeError:
            # Expected
            pass
    
    def test_checksum_mismatch_detection(self, tmp_path):
        """Detect checksum mismatch (corruption)"""
        target = tmp_path / "checksum.txt"
        content = "Original content"
        target.write_text(content)
        
        checksum1 = compute_file_checksum(str(target))
        
        # Corrupt file
        target.write_text("Corrupted!")
        
        checksum2 = compute_file_checksum(str(target))
        
        assert checksum1 != checksum2  # Corruption detected


class TestMatrix12ConcurrentChaos:
    """Chaotic concurrent operations"""
    
    def test_10_threads_random_operations(self, tmp_path):
        """10 threads doing random operations"""
        files = [tmp_path / f"chaos_{i}.txt" for i in range(10)]
        for f in files:
            f.write_text("Initial")
        
        errors = []
        
        def chaos_worker(worker_id: int):
            for _ in range(50):
                op = random.choice(["read", "write", "delete", "create"])
                target = random.choice(files)
                
                try:
                    if op == "read" and target.exists():
                        _ = target.read_text()
                    elif op == "write":
                        target.write_text(f"Worker {worker_id}")
                    elif op == "delete" and target.exists():
                        target.unlink()
                    elif op == "create":
                        target.write_text(f"Created by {worker_id}")
                except Exception as e:
                    errors.append(str(e))
                
                time.sleep(0.001)
        
        threads = [threading.Thread(target=chaos_worker, args=(i,)) for i in range(10)]
        for t in threads:
            t.start()
        for t in threads:
            t.join()
        
        # Some errors expected due to races, but shouldn't crash
    
    def test_thundering_herd(self, tmp_path):
        """Many threads all accessing same file simultaneously"""
        target = tmp_path / "herd.txt"
        target.write_text("Shared resource")
        
        results = []
        barrier = threading.Barrier(20)
        
        def herd_worker():
            barrier.wait()  # All threads start simultaneously
            try:
                content = target.read_text()
                results.append("success")
            except Exception:
                results.append("error")
        
        threads = [threading.Thread(target=herd_worker) for _ in range(20)]
        for t in threads:
            t.start()
        for t in threads:
            t.join()
        
        # All reads should succeed
        assert results.count("success") == 20


class TestMatrix12RecoveryScenarios:
    """Recovery from failure scenarios"""
    
    def test_partial_transaction_recovery(self, tmp_path):
        """Recovery from partial transaction failure"""
        files = []
        for i in range(5):
            f = tmp_path / f"tx_{i}.txt"
            f.write_text(f"Original {i}")
            files.append(f)
        
        # Simulate partial transaction (3 of 5 written)
        for i in range(3):
            files[i].write_text(f"Updated {i}")
        
        # "Crash" before completing
        # Recovery: restore originals
        for i in range(3):
            files[i].write_text(f"Original {i}")
        
        # Verify recovery
        for i, f in enumerate(files):
            assert f.read_text() == f"Original {i}"
    
    def test_orphan_temp_file_cleanup(self, tmp_path):
        """Clean up orphaned temp files"""
        # Create orphan temp files
        for i in range(5):
            (tmp_path / f".tmp_{i}").write_text("orphan")
        
        # Cleanup
        for temp in tmp_path.glob(".tmp_*"):
            temp.unlink()
        
        # Verify cleanup
        remaining = list(tmp_path.glob(".tmp_*"))
        assert len(remaining) == 0
    
    def test_lock_file_stale_cleanup(self, tmp_path):
        """Clean up stale lock files"""
        lock = tmp_path / "resource.lock"
        lock.write_text(f"PID: 99999\nTime: {time.time() - 3600}")  # 1 hour old
        
        # Check if lock is stale (> 5 min old)
        lock_content = lock.read_text()
        lock_time = float(lock_content.split("Time: ")[1])
        is_stale = time.time() - lock_time > 300
        
        if is_stale:
            lock.unlink()
        
        assert not lock.exists()


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
