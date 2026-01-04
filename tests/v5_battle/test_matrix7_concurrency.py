#!/usr/bin/env python3
"""
Battle-Test Suite: Matrix 7 — Concurrency & Race Conditions
Tests parallel operations, locking, and race condition handling

Run: python3 -m pytest tests/v5_battle/test_matrix7_concurrency.py -v
"""

import pytest
import sys
import os
import time
import threading
import tempfile
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import List, Dict, Any

sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from bridge.core.sandbox_guard_v5 import compute_file_checksum


class FileLock:
    """Simple file-based locking mechanism"""
    
    def __init__(self, path: Path):
        self.path = path
        self.lock_path = path.with_suffix('.lock')
        self.locked = False
    
    def acquire(self, timeout: float = 5.0) -> bool:
        """Try to acquire lock"""
        start = time.time()
        while time.time() - start < timeout:
            try:
                # Atomic create (fails if exists)
                fd = os.open(str(self.lock_path), os.O_CREAT | os.O_EXCL | os.O_WRONLY)
                os.close(fd)
                self.locked = True
                return True
            except FileExistsError:
                time.sleep(0.01)
        return False
    
    def release(self):
        """Release lock"""
        if self.locked and self.lock_path.exists():
            self.lock_path.unlink()
            self.locked = False


class TestMatrix7Concurrency:
    """Matrix 7: Concurrency & Race Conditions (R7-01 to R7-05)"""
    
    # =========================================================================
    # R7-01: Same File, Two Actors
    # =========================================================================
    
    def test_R7_01_same_file_two_actors(self, tmp_path):
        """R7-01: Two actors writing same file → Lock or queue"""
        target = tmp_path / "shared.txt"
        target.write_text("Initial")
        
        results = []
        lock = FileLock(target)
        
        def actor_write(actor_name: str, content: str, delay: float):
            time.sleep(delay)
            if lock.acquire(timeout=2.0):
                try:
                    target.write_text(f"{actor_name}: {content}")
                    results.append(("success", actor_name))
                finally:
                    lock.release()
            else:
                results.append(("blocked", actor_name))
        
        # Both try to write simultaneously
        t1 = threading.Thread(target=actor_write, args=("CLS", "CLS content", 0))
        t2 = threading.Thread(target=actor_write, args=("Liam", "Liam content", 0.01))
        
        t1.start()
        t2.start()
        t1.join()
        t2.join()
        
        # Both should succeed (one after another due to lock)
        assert len(results) == 2
        successes = [r for r in results if r[0] == "success"]
        assert len(successes) == 2
    
    # =========================================================================
    # R7-02: Same Directory, Different Files
    # =========================================================================
    
    def test_R7_02_same_dir_different_files(self, tmp_path):
        """R7-02: Two actors writing different files in same dir → Both succeed"""
        results = []
        
        def write_file(name: str):
            path = tmp_path / name
            path.write_text(f"Content of {name}")
            results.append(name)
        
        with ThreadPoolExecutor(max_workers=2) as executor:
            futures = [
                executor.submit(write_file, "file_a.txt"),
                executor.submit(write_file, "file_b.txt"),
            ]
            for f in as_completed(futures):
                f.result()
        
        assert len(results) == 2
        assert (tmp_path / "file_a.txt").exists()
        assert (tmp_path / "file_b.txt").exists()
    
    # =========================================================================
    # R7-03: Parent/Child Directory Creation
    # =========================================================================
    
    def test_R7_03_parent_child_creation_ordered(self, tmp_path):
        """R7-03: Create dir + write file must be ordered"""
        results = []
        
        def create_structure():
            # Create nested directory and file atomically
            nested = tmp_path / "parent" / "child"
            nested.mkdir(parents=True, exist_ok=True)
            results.append("dir_created")
            
            file_path = nested / "file.txt"
            file_path.write_text("Nested file")
            results.append("file_written")
        
        create_structure()
        
        assert results == ["dir_created", "file_written"]
        assert (tmp_path / "parent" / "child" / "file.txt").exists()
    
    # =========================================================================
    # R7-04: Delete While Writing (Conflict)
    # =========================================================================
    
    def test_R7_04_delete_while_writing_conflict(self, tmp_path):
        """R7-04: One actor deletes, another writes → Conflict resolved"""
        target = tmp_path / "conflict.txt"
        target.write_text("Original")
        
        results = {"write": None, "delete": None}
        lock = FileLock(target)
        
        def writer():
            time.sleep(0.05)  # Start slightly after delete attempt
            if lock.acquire(timeout=1.0):
                try:
                    if target.exists():
                        target.write_text("Written content")
                        results["write"] = "success"
                    else:
                        results["write"] = "file_gone"
                finally:
                    lock.release()
        
        def deleter():
            if lock.acquire(timeout=1.0):
                try:
                    if target.exists():
                        target.unlink()
                        results["delete"] = "success"
                finally:
                    lock.release()
        
        t1 = threading.Thread(target=deleter)
        t2 = threading.Thread(target=writer)
        
        t1.start()
        t2.start()
        t1.join()
        t2.join()
        
        # Conflict resolved - either delete wins or write wins
        assert results["delete"] == "success" or results["write"] == "success"
    
    # =========================================================================
    # R7-05: Read During Write (Atomicity)
    # =========================================================================
    
    def test_R7_05_read_during_write_atomicity(self, tmp_path):
        """R7-05: Read during write should see complete state (not partial)"""
        target = tmp_path / "atomic.txt"
        original = "A" * 1000
        new_content = "B" * 1000
        target.write_text(original)
        
        reads = []
        write_done = threading.Event()
        
        def writer():
            # Use temp file for atomic write
            temp = tmp_path / ".atomic.tmp"
            temp.write_text(new_content)
            temp.rename(target)  # Atomic on POSIX
            write_done.set()
        
        def reader():
            for _ in range(100):
                content = target.read_text()
                reads.append(content)
                time.sleep(0.001)
        
        t1 = threading.Thread(target=writer)
        t2 = threading.Thread(target=reader)
        
        t2.start()
        time.sleep(0.01)
        t1.start()
        
        t1.join()
        t2.join()
        
        # All reads should be complete (all A or all B, never mixed)
        for content in reads:
            assert content == original or content == new_content


class TestMatrix7HighContention:
    """High contention scenarios"""
    
    def test_10_concurrent_writers(self, tmp_path):
        """10 actors try to write same file simultaneously"""
        target = tmp_path / "contention.txt"
        target.write_text("Initial")
        
        lock = FileLock(target)
        results = []
        
        def writer(actor_id: int):
            acquired = lock.acquire(timeout=5.0)
            if acquired:
                try:
                    current = target.read_text()
                    target.write_text(f"{current}\nActor-{actor_id}")
                    results.append(("success", actor_id))
                finally:
                    lock.release()
            else:
                results.append(("timeout", actor_id))
        
        threads = [threading.Thread(target=writer, args=(i,)) for i in range(10)]
        
        for t in threads:
            t.start()
        for t in threads:
            t.join()
        
        # All should eventually succeed
        successes = [r for r in results if r[0] == "success"]
        assert len(successes) == 10
        
        # Final file should have all 10 actor entries
        content = target.read_text()
        for i in range(10):
            assert f"Actor-{i}" in content
    
    def test_read_write_mixed_workload(self, tmp_path):
        """Mixed read/write workload"""
        target = tmp_path / "mixed.txt"
        target.write_text("Counter: 0")
        
        lock = FileLock(target)
        read_results = []
        write_count = [0]
        
        def reader(reader_id: int):
            for _ in range(5):
                content = target.read_text()
                read_results.append((reader_id, content))
                time.sleep(0.01)
        
        def writer():
            for i in range(5):
                if lock.acquire(timeout=1.0):
                    try:
                        write_count[0] += 1
                        target.write_text(f"Counter: {write_count[0]}")
                    finally:
                        lock.release()
                time.sleep(0.02)
        
        # 3 readers, 1 writer
        threads = [
            threading.Thread(target=reader, args=(0,)),
            threading.Thread(target=reader, args=(1,)),
            threading.Thread(target=reader, args=(2,)),
            threading.Thread(target=writer),
        ]
        
        for t in threads:
            t.start()
        for t in threads:
            t.join()
        
        # Writer made 5 writes
        assert write_count[0] == 5
        
        # Readers got valid counters
        for reader_id, content in read_results:
            assert "Counter:" in content


class TestMatrix7DeadlockPrevention:
    """Deadlock and livelock prevention"""
    
    def test_lock_timeout_prevents_deadlock(self, tmp_path):
        """Lock timeout prevents deadlock"""
        file_a = tmp_path / "a.txt"
        file_b = tmp_path / "b.txt"
        file_a.write_text("A")
        file_b.write_text("B")
        
        lock_a = FileLock(file_a)
        lock_b = FileLock(file_b)
        
        results = []
        
        def actor_1():
            if lock_a.acquire(timeout=1.0):
                time.sleep(0.1)  # Hold lock A
                if lock_b.acquire(timeout=0.5):  # Try to get B
                    results.append("actor1_got_both")
                    lock_b.release()
                else:
                    results.append("actor1_timeout_b")
                lock_a.release()
        
        def actor_2():
            if lock_b.acquire(timeout=1.0):
                time.sleep(0.1)  # Hold lock B
                if lock_a.acquire(timeout=0.5):  # Try to get A
                    results.append("actor2_got_both")
                    lock_a.release()
                else:
                    results.append("actor2_timeout_a")
                lock_b.release()
        
        t1 = threading.Thread(target=actor_1)
        t2 = threading.Thread(target=actor_2)
        
        t1.start()
        t2.start()
        t1.join(timeout=3.0)
        t2.join(timeout=3.0)
        
        # At least one actor should timeout (preventing deadlock)
        assert len(results) == 2
        timeouts = [r for r in results if "timeout" in r]
        assert len(timeouts) >= 1  # Timeout prevents deadlock
    
    def test_stale_lock_cleanup(self, tmp_path):
        """Stale locks should be cleanable"""
        target = tmp_path / "stale.txt"
        target.write_text("Content")
        
        lock = FileLock(target)
        
        # Simulate stale lock (process crashed)
        lock.lock_path.write_text("stale")
        
        # New process should detect and handle
        # In real impl, check lock age and force cleanup
        assert lock.lock_path.exists()
        
        # Force cleanup (simulating recovery)
        lock.lock_path.unlink()
        
        # Now lock can be acquired
        assert lock.acquire(timeout=0.1) == True
        lock.release()


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
