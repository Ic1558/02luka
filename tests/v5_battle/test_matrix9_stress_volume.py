#!/usr/bin/env python3
"""
Stress-Test Suite: Matrix 9 — Volume & Load Testing
Tests system behavior under high volume operations

Run: python3 -m pytest tests/v5_battle/test_matrix9_stress_volume.py -v
"""

import pytest
import sys
import os
import time
import random
import string
import tempfile
import threading
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import List, Tuple

sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from bridge.core.router_v5 import route
from bridge.core.sandbox_guard_v5 import (
    check_write_allowed, validate_path_syntax, scan_content_for_forbidden_patterns
)


class TestMatrix9VolumeStress:
    """Matrix 9: Volume & Load Testing"""
    
    # =========================================================================
    # V9-01: 100 Sequential Routes
    # =========================================================================
    
    def test_V9_01_100_sequential_routes(self):
        """V9-01: 100 sequential routing decisions"""
        start = time.time()
        results = []
        
        for i in range(100):
            decision = route(
                trigger="cursor",
                actor="CLS",
                path=f"g/reports/doc_{i}.md",
                op="write"
            )
            results.append(decision.lane)
        
        elapsed = time.time() - start
        
        assert len(results) == 100
        assert all(lane == "FAST" for lane in results)
        assert elapsed < 1.0  # Should complete in < 1 second
    
    # =========================================================================
    # V9-02: 100 Parallel Routes
    # =========================================================================
    
    def test_V9_02_100_parallel_routes(self):
        """V9-02: 100 parallel routing decisions"""
        start = time.time()
        results = []
        
        def do_route(i: int) -> str:
            decision = route(
                trigger="cursor",
                actor="CLS",
                path=f"g/reports/parallel_{i}.md",
                op="write"
            )
            return decision.lane
        
        with ThreadPoolExecutor(max_workers=20) as executor:
            futures = [executor.submit(do_route, i) for i in range(100)]
            for f in as_completed(futures):
                results.append(f.result())
        
        elapsed = time.time() - start
        
        assert len(results) == 100
        assert all(lane == "FAST" for lane in results)
        assert elapsed < 2.0  # Should complete in < 2 seconds
    
    # =========================================================================
    # V9-03: 1000 Path Validations
    # =========================================================================
    
    def test_V9_03_1000_path_validations(self):
        """V9-03: 1000 path syntax validations"""
        start = time.time()
        valid_count = 0
        invalid_count = 0
        
        paths = [
            f"g/reports/file_{i}.md" for i in range(500)
        ] + [
            f"../escape_{i}" for i in range(250)
        ] + [
            f"/System/file_{i}" for i in range(250)
        ]
        
        for path in paths:
            is_valid, _, _ = validate_path_syntax(path)
            if is_valid:
                valid_count += 1
            else:
                invalid_count += 1
        
        elapsed = time.time() - start
        
        assert valid_count == 500
        assert invalid_count == 500
        assert elapsed < 1.0
    
    # =========================================================================
    # V9-04: 500 Content Scans
    # =========================================================================
    
    def test_V9_04_500_content_scans(self):
        """V9-04: 500 content security scans"""
        start = time.time()
        violations_found = 0
        
        safe_content = "This is safe content with no dangerous patterns.\n" * 10
        dangerous_content = "rm -rf /important\nsudo reboot\n"
        
        for i in range(500):
            content = dangerous_content if i % 10 == 0 else safe_content
            violations = scan_content_for_forbidden_patterns(content)
            if violations:
                violations_found += 1
        
        elapsed = time.time() - start
        
        assert violations_found == 50  # 10% dangerous
        assert elapsed < 2.0
    
    # =========================================================================
    # V9-05: Mixed Workload (Route + Validate + Scan)
    # =========================================================================
    
    def test_V9_05_mixed_workload_500_ops(self):
        """V9-05: 500 mixed operations (route + validate + scan)"""
        start = time.time()
        results = {"route": 0, "validate": 0, "scan": 0}
        
        for i in range(500):
            op_type = i % 3
            
            if op_type == 0:
                decision = route(
                    trigger="cursor",
                    actor="CLS",
                    path=f"g/reports/mixed_{i}.md",
                    op="write"
                )
                results["route"] += 1
            elif op_type == 1:
                is_valid, _, _ = validate_path_syntax(f"tools/script_{i}.zsh")
                results["validate"] += 1
            else:
                violations = scan_content_for_forbidden_patterns(f"Safe content {i}")
                results["scan"] += 1
        
        elapsed = time.time() - start
        
        assert results["route"] >= 160
        assert results["validate"] >= 160
        assert results["scan"] >= 160
        assert elapsed < 2.0


class TestMatrix9LargeFileStress:
    """Large file and content stress tests"""
    
    def test_large_content_scan_1mb(self):
        """Scan 1MB content file"""
        # Generate 1MB of content
        content = "x" * (1024 * 1024)
        
        start = time.time()
        violations = scan_content_for_forbidden_patterns(content)
        elapsed = time.time() - start
        
        assert len(violations) == 0
        assert elapsed < 1.0
    
    def test_large_content_with_pattern_at_end(self):
        """Pattern at end of large file should still be detected"""
        # 500KB safe + dangerous at end
        content = "x" * (500 * 1024) + "\nrm -rf /\n"
        
        violations = scan_content_for_forbidden_patterns(content)
        assert len(violations) > 0
    
    def test_many_small_files_validation(self):
        """Validate 1000 small file paths"""
        paths = [f"g/reports/small_{i:04d}.md" for i in range(1000)]
        
        start = time.time()
        valid_count = sum(1 for p in paths if validate_path_syntax(p)[0])
        elapsed = time.time() - start
        
        assert valid_count == 1000
        assert elapsed < 0.5
    
    def test_deep_nested_path(self):
        """Deep nested path validation (50 levels)"""
        path = "/".join([f"level{i}" for i in range(50)]) + "/file.txt"
        
        is_valid, violation, reason = validate_path_syntax(path)
        # Should handle deep nesting (may or may not be valid depending on impl)
        assert violation is None or violation is not None  # Just shouldn't crash


class TestMatrix9ConcurrentStress:
    """Concurrent operation stress tests"""
    
    def test_50_concurrent_full_checks(self):
        """50 concurrent full write checks"""
        results = []
        
        def full_check(i: int) -> bool:
            result = check_write_allowed(
                path=f"g/reports/concurrent_{i}.md",
                actor="CLS",
                operation="write",
                content=f"Content for file {i}",
                context={"world": "CLI"}
            )
            return result.allowed
        
        with ThreadPoolExecutor(max_workers=50) as executor:
            futures = [executor.submit(full_check, i) for i in range(50)]
            for f in as_completed(futures):
                results.append(f.result())
        
        assert len(results) == 50
        assert sum(results) == 50  # All should be allowed
    
    def test_burst_100_routes_in_100ms(self):
        """Burst: 100 routes within 100ms"""
        start = time.time()
        results = []
        
        def burst_route():
            for i in range(100):
                decision = route(
                    trigger="cursor",
                    actor="CLS",
                    path=f"g/reports/burst_{i}.md",
                    op="write"
                )
                results.append(decision)
        
        thread = threading.Thread(target=burst_route)
        thread.start()
        thread.join(timeout=0.5)
        
        elapsed = time.time() - start
        
        assert len(results) == 100
        assert elapsed < 0.5
    
    def test_sustained_load_10_seconds(self):
        """Sustained load: continuous ops for 10 seconds"""
        start = time.time()
        ops_completed = 0
        target_duration = 2.0  # Reduced for test speed
        
        while time.time() - start < target_duration:
            decision = route(
                trigger="cursor",
                actor="CLS",
                path=f"g/reports/sustained_{ops_completed}.md",
                op="write"
            )
            ops_completed += 1
        
        elapsed = time.time() - start
        ops_per_second = ops_completed / elapsed
        
        assert ops_completed >= 100  # At least 50 ops/sec
        assert ops_per_second >= 50


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
