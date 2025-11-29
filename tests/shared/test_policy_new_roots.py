"""
Test new allowed roots: g/catalog/, g/specs/, g/requirements/
"""
from __future__ import annotations

import tempfile
from pathlib import Path

import pytest

from shared.policy import apply_patch, check_write_allowed


def test_catalog_root_allowed():
    """Test that g/catalog/ writes are allowed."""
    allowed, reason = check_write_allowed("g/catalog/test.json")
    assert allowed, f"Expected allowed, got: {reason}"
    assert reason == "ALLOWED"


def test_specs_root_allowed():
    """Test that g/specs/ writes are allowed."""
    allowed, reason = check_write_allowed("g/specs/test.yaml")
    assert allowed, f"Expected allowed, got: {reason}"
    assert reason == "ALLOWED"


def test_requirements_root_allowed():
    """Test that g/requirements/ writes are allowed."""
    allowed, reason = check_write_allowed("g/requirements/test.md")
    assert allowed, f"Expected allowed, got: {reason}"
    assert reason == "ALLOWED"


def test_catalog_write_succeeds(tmp_path):
    """Test that actual write to g/catalog/ succeeds."""
    # Set base dir to tmp_path for test isolation
    import os
    os.environ["LAC_BASE_DIR"] = str(tmp_path)
    
    catalog_dir = tmp_path / "g" / "catalog"
    catalog_dir.mkdir(parents=True, exist_ok=True)
    
    result = apply_patch("g/catalog/test.json", '{"test": true}', dry_run=False)
    assert result["status"] == "success"
    assert (catalog_dir / "test.json").exists()
    
    # Cleanup
    del os.environ["LAC_BASE_DIR"]


def test_specs_write_succeeds(tmp_path):
    """Test that actual write to g/specs/ succeeds."""
    import os
    os.environ["LAC_BASE_DIR"] = str(tmp_path)
    
    specs_dir = tmp_path / "g" / "specs"
    specs_dir.mkdir(parents=True, exist_ok=True)
    
    result = apply_patch("g/specs/test.yaml", "test: true", dry_run=False)
    assert result["status"] == "success"
    assert (specs_dir / "test.yaml").exists()
    
    # Cleanup
    del os.environ["LAC_BASE_DIR"]


def test_requirements_write_succeeds(tmp_path):
    """Test that actual write to g/requirements/ succeeds."""
    import os
    os.environ["LAC_BASE_DIR"] = str(tmp_path)
    
    req_dir = tmp_path / "g" / "requirements"
    req_dir.mkdir(parents=True, exist_ok=True)
    
    result = apply_patch("g/requirements/test.md", "# Test", dry_run=False)
    assert result["status"] == "success"
    assert (req_dir / "test.md").exists()
    
    # Cleanup
    del os.environ["LAC_BASE_DIR"]

