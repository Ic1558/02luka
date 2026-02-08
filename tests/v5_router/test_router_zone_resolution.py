#!/usr/bin/env python3
"""
Test Router v5 Zone Resolution

Tests for resolve_zone() function covering:
- DANGER zone patterns (highest priority)
- LOCKED zone patterns
- OPEN zone (default)
- Paths outside 02luka root
"""

import sys
from pathlib import Path

# Add project root to path
project_root = Path(__file__).parent.parent.parent
sys.path.insert(0, str(project_root))

from bridge.core.router_v5 import resolve_zone


def test_danger_zone_patterns():
    """Test that DANGER zone patterns are detected."""
    danger_paths = [
        "/System/Library/",
        "/usr/bin/",
        "/etc/passwd",
        "~/.ssh/id_rsa",
        "rm -rf /Users/icmini/02luka",
    ]
    
    for path in danger_paths:
        zone = resolve_zone(path)
        assert zone == "DANGER", f"Path '{path}' should resolve to DANGER, got {zone}"


def test_locked_zone_patterns():
    """Test that LOCKED zone patterns are detected."""
    locked_paths = [
        "core/config.yaml",
        "launchd/com.02luka.test.plist",
        "bridge/core/router_v5.py",
        "bridge/inbox/MAIN/test.yaml",
        "bridge/outbox/CLC/test.yaml",
        "bridge/handlers/test.py",
        "bridge/production/test.yaml",
        "g/docs/governance/test.md",
    ]
    
    for path in locked_paths:
        zone = resolve_zone(path)
        assert zone == "LOCKED", f"Path '{path}' should resolve to LOCKED, got {zone}"


def test_open_zone_patterns():
    """Test that OPEN zone patterns are detected (default)."""
    open_paths = [
        "apps/test.py",
        "tools/test.sh",
        "agents/test.py",
        "tests/test.py",
        "g/reports/test.md",
        "g/docs/test.md",  # Non-governance docs
    ]
    
    for path in open_paths:
        zone = resolve_zone(path)
        assert zone == "OPEN", f"Path '{path}' should resolve to OPEN, got {zone}"


def test_paths_outside_root():
    """Test that paths outside 02luka root resolve to DANGER."""
    outside_paths = [
        "/tmp/test.txt",
        "/Users/icmini/other/test.txt",
        "/System/Library/test.txt",
    ]
    
    for path in outside_paths:
        zone = resolve_zone(path)
        assert zone == "DANGER", f"Path outside root '{path}' should resolve to DANGER, got {zone}"


def test_danger_priority_over_locked():
    """Test that DANGER patterns take priority over LOCKED."""
    # Paths that might match both (should be DANGER)
    danger_priority_paths = [
        "/System/core/test.yaml",  # Matches /System/ (DANGER) and core/ (LOCKED)
    ]
    
    for path in danger_priority_paths:
        zone = resolve_zone(path)
        assert zone == "DANGER", f"Path '{path}' should be DANGER (priority), got {zone}"


if __name__ == "__main__":
    import unittest
    
    class TestZoneResolution(unittest.TestCase):
        def test_danger_patterns(self):
            test_danger_zone_patterns()
        
        def test_locked_patterns(self):
            test_locked_zone_patterns()
        
        def test_open_patterns(self):
            test_open_zone_patterns()
        
        def test_outside_root(self):
            test_paths_outside_root()
        
        def test_danger_priority(self):
            test_danger_priority_over_locked()
    
    unittest.main()

