#!/usr/bin/env python3
"""
02luka Secure Gateway v1.1
==========================
HTTP Bridge between Opal App and 02luka Work Order System

Security Features:
- CloudStorage path blocking (assert_local_blob)
- Environment-based secrets (no hardcoded passwords)
- Atomic file writes to bridge inbox
- Separation from agent_listener (no channel overlap)

Architecture:
    Opal App (Cloud) 
        ↓ HTTPS POST
    Cloudflare Tunnel 
        ↓ localhost:5001
    This Gateway (Flask)
        ↓ Atomic Write
    bridge/inbox/LIAM/*.json
        ↓ File Watcher
    agent_listener.py / Liam Executor
"""

import os
import json
import uuid
import re
import logging
from datetime import datetime, timezone
from pathlib import Path
from flask import Flask, request, jsonify

# --- ⚙️ CONFIGURATION & CONSTANTS ---
# [FIX] Load secure paths from Environment (fallback to standard location)
LUKA_HOME = Path(os.getenv("LUKA_HOME", os.path.expanduser("~/02luka")))
BRIDGE_INBOX = LUKA_HOME / "bridge" / "inbox" / "LIAM"
NOTIFY_INBOX = LUKA_HOME / "bridge" / "inbox" / "NOTIFY"
STATE_DIR = LUKA_HOME / "followup" / "state"
ENV_FILE = LUKA_HOME / ".env.local"

# [FIX] Load RELAY_KEY securely from environment
RELAY_KEY = None
if ENV_FILE.exists():
    with open(ENV_FILE) as f:
        for line in f:
            if line.startswith("RELAY_KEY="):
                RELAY_KEY = line.split("=", 1)[1].strip().strip('"')
                break

# Logging Setup (UTC timestamps for consistency)
logging.basicConfig(
    format="%(asctime)s UTC [%(levelname)s] %(message)s",
    level=logging.INFO,
    datefmt="%Y-%m-%d %H:%M:%S"
)
logging.Formatter.converter = lambda *args: datetime.now(timezone.utc).timetuple()
logger = logging.getLogger("OpalGateway")

# Initialize Flask
app = Flask(__name__)

# Ensure directories exist
BRIDGE_INBOX.mkdir(parents=True, exist_ok=True)
NOTIFY_INBOX.mkdir(parents=True, exist_ok=True)
STATE_DIR.mkdir(parents=True, exist_ok=True)

# --- 📊 STATUS ENUM & HELPERS ---
# Status Enum (strict - no variants)
WO_STATUS_QUEUED = "QUEUED"
WO_STATUS_RUNNING = "RUNNING"
WO_STATUS_DONE = "DONE"
WO_STATUS_ERROR = "ERROR"
WO_STATUS_STALE = "STALE"

def is_wo_stale(state_data):
    """
    Check if WO is stale (running > 24h).
    
    Returns True if:
    - Status is running/pending
    - updated_at > 24 hours ago
    """
    updated_at_str = state_data.get("updated_at")
    if not updated_at_str:
        return False
    
    try:
        updated_at = datetime.fromisoformat(updated_at_str.replace("Z", "+00:00"))
        now = datetime.now(timezone.utc)
        age_hours = (now - updated_at).total_seconds() / 3600
        return age_hours > 24 and state_data.get("status", "").lower() in ["running", "pending"]
    except Exception as e:
        logger.error(f"❌ Error parsing updated_at: {e}")
        return False

def determine_wo_status(state_data):
    """
    Determine WO status from state file data.
    
    Returns strict enum: QUEUED | RUNNING | DONE | ERROR | STALE
    Maps from state file status values to standardized enum.
    
    Source of Truth: state_data from followup/state/*.json
    """
    status = state_data.get("status", "").lower()
    last_error = state_data.get("last_error")
    updated_at = state_data.get("updated_at")
    
    # Map to strict enum (no variants)
    if status in ["done", "completed"]:
        return WO_STATUS_DONE
    elif status in ["failed"] or last_error:
        return WO_STATUS_ERROR
    elif status in ["running", "pending"]:
        # Check if stale (>24h)
        if is_wo_stale(state_data):
            return WO_STATUS_STALE
        return WO_STATUS_RUNNING
    else:
        # Default to RUNNING if unknown (assume in progress)
        return WO_STATUS_RUNNING

# --- 🛡️ SECURITY FUNCTIONS ---

def assert_local_blob(payload: str):
    """
    [CRITICAL FIX] Block CloudStorage paths to prevent accidental data leaks 
    or syncing conflicts with iCloud/Google Drive.
    
    Raises RuntimeError if dangerous path detected.
    """
    if not payload:
        return
    
    # Regex to catch common synced cloud paths
    dangerous_patterns = [
        r"Library/CloudStorage",
        r"My Drive.*02luka",
        r"iCloud Drive",
        r"Google Drive"
    ]
    
    for pattern in dangerous_patterns:
        if re.search(pattern, payload, re.IGNORECASE):
            logger.warning(f"🚨 BLOCKED payload containing cloud storage path: {pattern}")
            raise RuntimeError(
                "SECURITY ALERT: Blocked non-local CloudStorage path in payload"
            )

def require_relay_key():
    """
    Helper function to validate X-Relay-Key header.
    Returns True if authorized, False otherwise.
    """
    if not RELAY_KEY:
        # No RELAY_KEY configured, allow access
        return True
    
    header_key = request.headers.get("X-Relay-Key")
    return header_key == RELAY_KEY

def error_response(error_code, message, status_code=400):
    """
    Standardized error response format.
    
    Returns consistent error format across all endpoints:
    {
        "ok": false,
        "error": "error_code",
        "message": "human readable message",
        "timestamp": "ISO8601"
    }
    """
    return jsonify({
        "ok": False,
        "error": error_code,
        "message": message,
        "timestamp": datetime.now(timezone.utc).isoformat()
    }), status_code

# --- 🔗 API ENDPOINTS ---

@app.route("/")
def health_check():
    """Simple heartbeat to verify Cloudflare Tunnel is connected."""
    return jsonify({
        "status": "online",
        "service": "02luka_gateway",
        "version": "1.1.0",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "inbox": str(BRIDGE_INBOX)
    })

@app.route("/ping")
def ping():
    """Quick ping for monitoring"""
    return jsonify({
        "status": "ok",
        "timestamp": datetime.now(timezone.utc).isoformat()
    })

@app.route("/api/wo", methods=["POST"])
def receive_work_order():
    """
    Receives JSON Work Order from Opal, validates safety, 
    and saves to Bridge Inbox for processing.
    
    Security:
    - Validates X-Relay-Key header if RELAY_KEY is configured
    - Blocks CloudStorage paths via assert_local_blob()
    - Uses atomic file writes
    """
    try:
        # 1. [FIX] Security check - Validate relay key
        relay_key_header = request.headers.get("X-Relay-Key")
        if RELAY_KEY and relay_key_header != RELAY_KEY:
            logger.warning(f"❌ Unauthorized access attempt from {request.remote_addr}")
            return error_response("unauthorized", "Invalid relay key", 401)
        
        # 2. Parse Payload
        payload = request.get_json()
        if not payload:
            return error_response("no_payload", "No JSON payload provided", 400)
            
        payload_str = json.dumps(payload, ensure_ascii=False)

        # 3. [FIX] Security Assertion - Block cloud storage paths
        try:
            assert_local_blob(payload_str)
        except RuntimeError as e:
            logger.error(f"❌ [SECURITY] {str(e)}")
            return error_response("security_blocked", str(e), 403)

        # 4. Extract or Generate Metadata
        wo_id = payload.get("wo_id", f"WO-GATEWAY-{uuid.uuid4().hex[:8].upper()}")
        app_mode = payload.get("app_mode", "Unknown")
        objective = payload.get("objective", "No objective specified")

        # 5. Add Gateway Metadata
        payload["gateway_metadata"] = {
            "received_at": datetime.now(timezone.utc).isoformat(),
            "source_ip": request.remote_addr,
            "gateway_version": "1.1.0",
            "security_validated": True
        }

        # 6. [FIX] Atomic Write to Bridge Inbox
        # Write to temp file first, then rename (prevents partial reads)
        filename = BRIDGE_INBOX / f"{wo_id}.json"
        temp_filename = filename.with_suffix(".tmp")
        
        with open(temp_filename, "w", encoding='utf-8') as f:
            json.dump(payload, f, indent=2, ensure_ascii=False)
        
        # Atomic rename
        temp_filename.rename(filename)
            
        logger.info(f"✅ [RECEIVED] {wo_id} | Mode: {app_mode} | Saved to Inbox")
        logger.info(f"   Objective: {objective[:80]}{'...' if len(objective) > 80 else ''}")

        # 7. Log notification requests (actual sending handled by agent_listener)
        notify_cfg = payload.get("notify", {})
        if notify_cfg.get("telegram"):
            logger.info(f"🔔 [NOTIFY] Telegram alert requested for {wo_id}")
        if notify_cfg.get("line"):
            logger.info(f"🔔 [NOTIFY] LINE alert requested for {wo_id}")

        # 8. Return success
        return jsonify({
            "status": "success",
            "wo_id": wo_id,
            "message": f"Work Order bridged securely (Mode: {app_mode})",
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "inbox_path": str(filename)
        })

    except json.JSONDecodeError as e:
        logger.error(f"❌ [PARSE ERROR] Invalid JSON: {str(e)}")
        return error_response("invalid_json", f"Invalid JSON payload: {str(e)}", 400)
        
    except Exception as e:
        # General error
        logger.error(f"❌ [ERROR] {str(e)}", exc_info=True)
        return error_response("internal_error", "Internal Gateway Error", 500)

@app.route("/api/wo_status", methods=["GET", "POST"])
def api_wo_status():
    """
    Work Order status endpoint - supports both single query (POST) and list (GET).
    
    GET: List all Work Orders with optional status filtering
    POST: Query single Work Order by wo_id
    """
    if not require_relay_key():
        logger.warning(f"❌ Unauthorized wo_status request from {request.remote_addr}")
        return error_response("unauthorized", "Invalid relay key", 401)
    
    # GET: List all WOs
    if request.method == "GET":
        return api_wo_status_list()
    
    # POST: Query single WO
    data = request.get_json(force=True, silent=True) or {}
    wo_id = data.get("wo_id")
    
    if not wo_id:
        return error_response("wo_id_required", "wo_id parameter is required", 400)

    state_file = STATE_DIR / f"{wo_id}.json"
    if not state_file.exists():
        logger.info(f"📋 [WO_STATUS] State not found: {wo_id}")
        return error_response("wo_state_not_found", f"State file not found for wo_id: {wo_id}", 404)

    try:
        state = json.loads(state_file.read_text())
        logger.info(f"📋 [WO_STATUS] {wo_id} | Status: {state.get('status', 'UNKNOWN')}")
    except Exception as e:
        logger.error(f"❌ [WO_STATUS] Invalid state JSON for {wo_id}: {str(e)}")
        return error_response("invalid_state_json", f"Invalid state file format: {str(e)}", 500)

    # Return standardized state fields
    resp = {
        "ok": True,
        "wo_id": wo_id,
        "status": state.get("status", "UNKNOWN"),
        "lane": state.get("lane", "UNKNOWN"),
        "app_mode": state.get("app_mode", "UNKNOWN"),
        "priority": state.get("priority", "UNKNOWN"),
        "objective": state.get("objective", "UNKNOWN"),
        "last_update": state.get("last_update"),
        "notify": state.get("notify", {}),
        "state_path": str(state_file.relative_to(LUKA_HOME))
    }
    return jsonify(resp), 200

def api_wo_status_list():
    """
    List all Work Orders with optional status filtering.
    
    Query params:
    - limit: Number of items (default: 50, max: 200)
    - status: Filter by status (all|queued|running|done|error|stale)
    - offset: Pagination offset (default: 0)
    
    Returns: { "items": [...], "total": N, "limit": N, "offset": N }
    
    Source of Truth: followup/state/*.json (primary)
    """
    # Parse query parameters with validation
    try:
        limit = min(max(int(request.args.get("limit", 50)), 1), 200)
    except (ValueError, TypeError):
        limit = 50
        logger.warning(f"⚠️ [WO_STATUS] Invalid limit parameter, using default: 50")
    
    try:
        offset = max(int(request.args.get("offset", 0)), 0)
    except (ValueError, TypeError):
        offset = 0
        logger.warning(f"⚠️ [WO_STATUS] Invalid offset parameter, using default: 0")
    
    status_filter = request.args.get("status", "all").upper()
    valid_statuses = ["ALL", "QUEUED", "RUNNING", "DONE", "ERROR", "STALE"]
    if status_filter not in valid_statuses:
        logger.warning(f"⚠️ [WO_STATUS] Invalid status filter '{status_filter}', using 'ALL'")
        status_filter = "ALL"
    
    items = []
    
    # 1. Read state files (SOURCE OF TRUTH)
    if STATE_DIR.exists():
        for state_file in STATE_DIR.glob("*.json"):
            try:
                state_data = json.loads(state_file.read_text())
                # NOTE: State schema must have "id" field (or fallback to filename)
                # If schema changes in future, update this line
                wo_id = state_data.get("id") or state_file.stem
                
                # Determine status (strict enum)
                wo_status = determine_wo_status(state_data)
                
                # Skip if filtered
                if status_filter != "ALL" and wo_status != status_filter:
                    continue
                
                items.append({
                    "wo_id": wo_id,
                    "status": wo_status,  # Strict enum
                    "lane": state_data.get("lane", "unknown"),
                    "app_mode": state_data.get("app_mode", "unknown"),
                    "priority": state_data.get("priority", "medium"),
                    "objective": (state_data.get("objective") or 
                                 state_data.get("title") or 
                                 state_data.get("summary") or "")[:80],
                    "created_at": state_data.get("created_at"),
                    "started_at": state_data.get("meta", {}).get("started_at"),
                    "finished_at": state_data.get("meta", {}).get("finished_at"),
                    "last_update": state_data.get("updated_at") or state_data.get("created_at"),
                    "error_message": state_data.get("last_error"),
                    "source": state_data.get("meta", {}).get("source", "unknown")
                })
            except Exception as e:
                logger.error(f"❌ Error reading state file {state_file}: {e}")
                continue
    
    # 2. Read queued files (not yet processed)
    if BRIDGE_INBOX.exists():
        for inbox_file in BRIDGE_INBOX.glob("*.json"):
            wo_id = inbox_file.stem
            # Skip if already in items (has state file)
            if any(item["wo_id"] == wo_id for item in items):
                continue
            
            # Apply filter
            if status_filter != "ALL" and status_filter != WO_STATUS_QUEUED:
                continue
            
            try:
                wo_data = json.loads(inbox_file.read_text())
                items.append({
                    "wo_id": wo_id,
                    "status": WO_STATUS_QUEUED,  # Strict enum
                    "lane": wo_data.get("lane", "unknown"),
                    "app_mode": wo_data.get("app_mode", "unknown"),
                    "priority": wo_data.get("priority", "medium"),
                    "objective": wo_data.get("objective", "")[:80],
                    "created_at": wo_data.get("apio_log", {}).get("timestamp"),
                    "started_at": None,
                    "finished_at": None,
                    "last_update": wo_data.get("apio_log", {}).get("timestamp"),
                    "error_message": None,
                    "source": "opal"
                })
            except Exception as e:
                logger.error(f"❌ Error reading inbox file {inbox_file}: {e}")
                continue
    
    # 3. Sort by last_update desc (most recent first)
    # NOTE: Uses ISO8601 string comparison (assumes all timestamps are valid ISO8601)
    # If dashboard shows wrong order, check timestamp format and consider robust parsing
    items.sort(key=lambda x: (
        x["last_update"] or x["created_at"] or "1970-01-01T00:00:00Z"
    ), reverse=True)
    
    # 4. Apply pagination
    total = len(items)
    items = items[offset:offset+limit]
    
    return jsonify({
        "items": items,
        "total": total,
        "limit": limit,
        "offset": offset,
        "timestamp": datetime.now(timezone.utc).isoformat()
    }), 200

@app.route("/api/notify", methods=["POST"])
def api_notify():
    """
    Queue notification for delivery by notification worker.
    
    Accepts telegram and/or line notification payloads and writes them
    to bridge/inbox/NOTIFY/ for processing by the notification worker.
    """
    if not require_relay_key():
        logger.warning(f"❌ Unauthorized notify request from {request.remote_addr}")
        return error_response("unauthorized", "Invalid relay key", 401)

    payload = request.get_json(force=True, silent=True) or {}
    wo_id = payload.get("wo_id", "UNKNOWN")

    # Minimal validation - at least one channel must be configured
    if payload.get("telegram") is None and payload.get("line") is None:
        return error_response("no_channels_enabled", "At least one notification channel (telegram or line) must be configured", 400)

    # Write to notify inbox with atomic rename
    filename = NOTIFY_INBOX / f"{wo_id}_notify.json"
    tmp = filename.with_suffix(".tmp")

    try:
        tmp.write_text(json.dumps(payload, ensure_ascii=False, indent=2))
        tmp.rename(filename)
        
        logger.info(f"🔔 [NOTIFY] Queued notification for {wo_id}")
        if payload.get("telegram"):
            logger.info(f"   → Telegram: {payload['telegram'].get('chat', 'default')}")
        if payload.get("line"):
            logger.info(f"   → LINE: {payload['line'].get('room', 'default')}")
        
    except Exception as e:
        logger.error(f"❌ [NOTIFY] Failed to queue notification: {str(e)}")
        return error_response("write_failed", f"Failed to write notification file: {str(e)}", 500)

    return jsonify({
        "ok": True,
        "wo_id": wo_id,
        "queued_file": str(filename.relative_to(LUKA_HOME))
    }), 200


@app.route("/stats")
def get_stats():
    """Get gateway statistics and health info"""
    try:
        # Count pending work orders in inbox
        pending_wos = list(BRIDGE_INBOX.glob("*.json"))
        
        return jsonify({
            "status": "operational",
            "version": "1.1.0",
            "inbox_path": str(BRIDGE_INBOX),
            "pending_work_orders": len(pending_wos),
            "security": {
                "relay_key_configured": RELAY_KEY is not None,
                "cloud_path_blocking": True
            },
            "timestamp": datetime.now(timezone.utc).isoformat()
        })
    except Exception as e:
        logger.error(f"❌ [STATS] Error getting stats: {str(e)}", exc_info=True)
        return error_response("stats_error", f"Failed to retrieve gateway statistics: {str(e)}", 500)

# --- 🚀 RUNNER ---
if __name__ == "__main__":
    logger.info("=" * 60)
    logger.info("🚀 Starting 02luka Secure Gateway v1.1")
    logger.info(f"   LUKA_HOME: {LUKA_HOME}")
    logger.info(f"   Bridge Inbox: {BRIDGE_INBOX}")
    logger.info(f"   Security: {'✅ RELAY_KEY configured' if RELAY_KEY else '⚠️  No RELAY_KEY (open access)'}")
    logger.info(f"   CloudStorage Blocking: ✅ ENABLED")
    logger.info("=" * 60)
    
    # Listen on port 5001 (port 5000 is used by macOS Control Center)
    app.run(
        host="0.0.0.0",
        port=5001,
        debug=False
    )
