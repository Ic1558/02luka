#!/usr/bin/env python3
"""
OPAL API v1 - Telemetry & Health Service
WO: WO-OPAL-API-IMPLEMENT-V1
Created: 2025-11-27
Port: 7001

Endpoints:
- GET /api/health          - Basic health check
- GET /api/telemetry/health - Full health check JSON
- GET /api/telemetry/summary - Slim summary for UI
- GET /api/budget          - Dev lane budget info
- GET /api/status          - Quick status (for other health checks)
"""

import json
import os
from datetime import datetime
from pathlib import Path
from typing import Any, Optional

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

# ═══════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════
PROJECT_ROOT = Path(os.environ.get("LUKA_SOT", "/Users/icmini/02luka"))
TELEMETRY_PATH = PROJECT_ROOT / "g" / "telemetry" / "health_check_latest.json"
BUDGET_PATH = PROJECT_ROOT / "g" / "ledger" / "dev_lane_budget.json"
HEALTH_LOG_PATH = PROJECT_ROOT / "g" / "telemetry" / "health_check.log"

# ═══════════════════════════════════════════
# FastAPI App
# ═══════════════════════════════════════════
app = FastAPI(
    title="OPAL API",
    description="Telemetry & Health Service for 02luka OPAL V4 Pipeline",
    version="1.0.0",
)

# CORS for local development
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["GET"],
    allow_headers=["*"],
)

# ═══════════════════════════════════════════
# Helpers
# ═══════════════════════════════════════════
def read_json_file(path: Path) -> Optional[dict]:
    """Safely read JSON file, return None if not found or invalid."""
    try:
        if path.exists():
            with open(path, "r") as f:
                return json.load(f)
    except (json.JSONDecodeError, IOError) as e:
        print(f"[OPAL API] Error reading {path}: {e}")
    return None


def get_last_log_line(path: Path) -> Optional[str]:
    """Get the last line from a log file."""
    try:
        if path.exists():
            with open(path, "r") as f:
                lines = f.readlines()
                return lines[-1].strip() if lines else None
    except IOError:
        pass
    return None


# ═══════════════════════════════════════════
# Models
# ═══════════════════════════════════════════
class HealthResponse(BaseModel):
    status: str
    timestamp: str
    service: str = "opal_api"
    version: str = "1.0.0"


class StatusResponse(BaseModel):
    status: str
    uptime: str = "running"
    port: int = 7001


# ═══════════════════════════════════════════
# Endpoints
# ═══════════════════════════════════════════
@app.get("/api/health", response_model=HealthResponse)
async def health_check():
    """Basic health check endpoint."""
    return HealthResponse(
        status="ok",
        timestamp=datetime.now().isoformat(),
    )


@app.get("/api/status", response_model=StatusResponse)
async def quick_status():
    """Quick status for other health checks (avoids recursion)."""
    return StatusResponse(status="ok")


@app.get("/api/telemetry/health")
async def telemetry_health():
    """Full health check JSON from health_check_latest.json."""
    data = read_json_file(TELEMETRY_PATH)
    
    if data is None:
        return {
            "status": "unknown",
            "error": "health_check_latest.json not found or invalid",
            "source": "file",
            "path": str(TELEMETRY_PATH),
        }
    
    # Add source metadata
    data["source"] = "file"
    data["api_timestamp"] = datetime.now().isoformat()
    return data


@app.get("/api/telemetry/summary")
async def telemetry_summary():
    """Slim summary view for UI dashboard."""
    data = read_json_file(TELEMETRY_PATH)
    
    if data is None:
        return {
            "overall_status": "unknown",
            "timestamp": datetime.now().isoformat(),
            "components": {},
            "error": "No telemetry data available",
        }
    
    # Extract key fields for summary
    return {
        "overall_status": data.get("overall_status", "unknown"),
        "timestamp": data.get("timestamp", datetime.now().isoformat()),
        "api_timestamp": datetime.now().isoformat(),
        "components": {
            "redis": "healthy" if "redis" in str(data.get("checks", [])) else "unknown",
            "opal_api": "healthy",  # We're responding, so we're healthy
            "launchagents": data.get("agents", {}),
        },
        "metrics": data.get("metrics", {}),
        "auto_restart_enabled": data.get("auto_restart_enabled", False),
    }


@app.get("/api/budget")
async def get_budget():
    """Dev lane budget information."""
    data = read_json_file(BUDGET_PATH)
    
    if data is None:
        # Return default budget structure if file doesn't exist
        return {
            "status": "default",
            "message": "Budget file not found, using defaults",
            "budget": {
                "daily_limit_usd": 5.0,
                "used_today_usd": 0.0,
                "remaining_usd": 5.0,
                "reset_time": "00:00 UTC",
            },
            "lanes": {
                "free": {"enabled": True, "priority": 1},
                "gemini": {"enabled": True, "priority": 2, "cost_per_call": 0.001},
                "gpt4": {"enabled": True, "priority": 3, "cost_per_call": 0.03},
            },
        }
    
    data["status"] = "loaded"
    data["api_timestamp"] = datetime.now().isoformat()
    return data


@app.get("/api/telemetry/log")
async def telemetry_log():
    """Get recent health check log entries."""
    log_path = HEALTH_LOG_PATH
    
    try:
        if log_path.exists():
            with open(log_path, "r") as f:
                lines = f.readlines()
                # Return last 20 lines
                recent = lines[-20:] if len(lines) > 20 else lines
                return {
                    "status": "ok",
                    "total_entries": len(lines),
                    "recent_entries": [line.strip() for line in recent],
                }
    except IOError as e:
        return {"status": "error", "error": str(e)}
    
    return {"status": "empty", "recent_entries": []}


# ═══════════════════════════════════════════
# Root
# ═══════════════════════════════════════════
@app.get("/")
async def root():
    """API root with available endpoints."""
    return {
        "service": "OPAL API",
        "version": "1.0.0",
        "status": "running",
        "endpoints": {
            "/api/health": "Basic health check",
            "/api/status": "Quick status",
            "/api/telemetry/health": "Full health telemetry",
            "/api/telemetry/summary": "Summary for UI",
            "/api/telemetry/log": "Recent log entries",
            "/api/budget": "Dev lane budget info",
        },
    }


# ═══════════════════════════════════════════
# Main
# ═══════════════════════════════════════════
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=7001)
