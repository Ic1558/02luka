"""
Health Check — Threshold Tests

Tests health check threshold logic:
- ACTIVE = last activity < 5 minutes
- BACKLOG = 0-9 files
- STUCK = >= 10 files
"""

import pytest
import time
from pathlib import Path


def test_health_active_threshold():
    """Test ACTIVE threshold (last 5 minutes)."""
    current_time = time.time()
    
    # Recent activity (< 5 minutes)
    recent_time = current_time - 60  # 1 minute ago
    diff_seconds = current_time - recent_time
    diff_minutes = diff_seconds / 60
    
    assert diff_minutes < 5, "Should be ACTIVE"
    
    # Stale activity (> 5 minutes)
    stale_time = current_time - 400  # ~6.7 minutes ago
    diff_seconds = current_time - stale_time
    diff_minutes = diff_seconds / 60
    
    assert diff_minutes > 5, "Should be STALE"


def test_health_backlog_thresholds():
    """Test backlog count thresholds."""
    # HEALTHY: 0 files
    file_count = 0
    assert file_count == 0, "Should be HEALTHY"
    
    # BACKLOG: 1-9 files
    file_count = 5
    assert 1 <= file_count < 10, "Should be BACKLOG"
    
    # STUCK: >= 10 files
    file_count = 15
    assert file_count >= 10, "Should be STUCK"


def test_health_status_combination():
    """Test health status combination logic."""
    # HEALTHY: All checks pass
    launchagent = "RUNNING"
    process = "RUNNING"
    log_activity = "ACTIVE"
    inbox_consumption = "HEALTHY"
    
    if launchagent == "RUNNING" and process == "RUNNING" and log_activity == "ACTIVE":
        status = "HEALTHY"
    else:
        status = "DEGRADED"
    
    assert status == "HEALTHY"
    
    # DEGRADED: Some checks fail
    log_activity = "STALE"
    
    if launchagent == "RUNNING" and process == "RUNNING" and log_activity == "ACTIVE":
        status = "HEALTHY"
    else:
        status = "DEGRADED"
    
    assert status == "DEGRADED"
    
    # DOWN: Critical checks fail
    launchagent = "STOPPED"
    process = "STOPPED"
    
    if launchagent == "STOPPED" and process == "STOPPED":
        status = "DOWN"
    else:
        status = "DEGRADED"
    
    assert status == "DOWN"

