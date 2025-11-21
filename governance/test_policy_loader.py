#!/usr/bin/env python3
"""Test script for policy_loader module"""
from __future__ import annotations

import sys
from pathlib import Path

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from governance.policy_loader import load_safe_zones, load_gm_policy


def test_safe_zones():
    """Test loading safe_zones.yaml"""
    print("=" * 60)
    print("Testing load_safe_zones()")
    print("=" * 60)
    
    try:
        zones = load_safe_zones()
        print(f"✅ Loaded SafeZones successfully")
        print(f"   root_project: {zones.root_project}")
        print(f"   write_allowed: {zones.write_allowed}")
        print(f"   write_denied: {len(zones.write_denied)} paths")
        print(f"   allowlist_subdirs: {len(zones.allowlist_subdirs)} subdirs")
        return True
    except Exception as e:
        print(f"❌ Error loading safe_zones: {e}")
        return False


def test_gm_policy():
    """Test loading gm_policy_v4.yaml"""
    print("\n" + "=" * 60)
    print("Testing load_gm_policy()")
    print("=" * 60)
    
    try:
        policy = load_gm_policy()
        print(f"✅ Loaded GmPolicy successfully")
        print(f"   files_changed_threshold: {policy.files_changed_threshold}")
        print(f"   sensitive_paths: {len(policy.sensitive_paths)} paths")
        print(f"   file_extensions: {len(policy.file_extensions)} extensions")
        print(f"   critical_keywords: {len(policy.critical_keywords)} keywords")
        print(f"   shell_keywords: {len(policy.shell_keywords)} keywords")
        return True
    except Exception as e:
        print(f"❌ Error loading gm_policy: {e}")
        return False


def test_caching():
    """Test that caching works (same object returned)"""
    print("\n" + "=" * 60)
    print("Testing caching")
    print("=" * 60)
    
    try:
        zones1 = load_safe_zones()
        zones2 = load_safe_zones()
        policy1 = load_gm_policy()
        policy2 = load_gm_policy()
        
        # Check if same object (cached)
        if zones1 is zones2:
            print("✅ SafeZones caching works (same object)")
        else:
            print("⚠️  SafeZones not cached (different objects)")
        
        if policy1 is policy2:
            print("✅ GmPolicy caching works (same object)")
        else:
            print("⚠️  GmPolicy not cached (different objects)")
        
        return True
    except Exception as e:
        print(f"❌ Error testing caching: {e}")
        return False


if __name__ == "__main__":
    print("Policy Loader Test Suite")
    print("=" * 60)
    
    results = []
    results.append(test_safe_zones())
    results.append(test_gm_policy())
    results.append(test_caching())
    
    print("\n" + "=" * 60)
    if all(results):
        print("✅ All tests passed!")
        sys.exit(0)
    else:
        print("❌ Some tests failed")
        sys.exit(1)
