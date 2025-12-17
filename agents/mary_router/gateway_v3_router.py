#!/usr/bin/env python3
"""
Mary Router Gateway v3 - Central Inbox Router

Phase 1 (v5 Integration): Routes WOs from bridge/inbox/main/ using WO Processor v5
- Uses Router v5 for lane-based routing
- STRICT lane → CLC inbox
- FAST/WARN lane → Local execution
- BLOCKED lane → Error inbox
- Falls back to legacy routing if v5 stack unavailable
"""

import json
import logging
import os
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, Any, Optional

import yaml

# Import v5 stack
try:
    from bridge.core.wo_processor_v5 import process_wo_with_lane_routing
    V5_STACK_AVAILABLE = True
except ImportError:
    V5_STACK_AVAILABLE = False
    logging.warning("v5 stack not available, using legacy routing")

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    datefmt='%Y-%m-%dT%H:%M:%S%z'
)
log = logging.getLogger(__name__)

# Base directory
ROOT = Path(os.getenv("LUKA_SOT", os.getenv("HOME", ".") + "/02luka"))
CONFIG_PATH = ROOT / "g/config/mary_router_gateway_v3.yaml"


class GatewayV3Router:
    """Gateway v3 Router - Routes WOs from MAIN inbox to agent inboxes."""
    
    def __init__(self, config_path: Optional[Path] = None):
        """Initialize router with configuration."""
        self.config_path = config_path or CONFIG_PATH
        self.config = self._load_config()
        
        # Setup paths
        self.inbox = ROOT / self.config["directories"]["inbox"]
        self.processed = ROOT / self.config["directories"]["processed"]
        self.error = ROOT / self.config["directories"]["error"]
        self.telemetry_file = ROOT / self.config["telemetry"]["log_file"]
        
        # Create directories
        for path in [self.inbox, self.processed, self.error, self.telemetry_file.parent]:
            path.mkdir(parents=True, exist_ok=True)
        
        # #region agent log
        import json as json_module
        try:
            with open("/Users/icmini/02luka/.cursor/debug.log", "a") as debug_f:
                debug_f.write(json_module.dumps({"sessionId":"debug-session","runId":"init","hypothesisId":"A","location":"gateway_v3_router.py:60","message":"Init telemetry_file path check","data":{"telemetry_file":str(self.telemetry_file),"telemetry_file_resolved":str(self.telemetry_file.resolve()),"parent_exists":self.telemetry_file.parent.exists(),"parent_is_dir":self.telemetry_file.parent.is_dir(),"can_write":self.telemetry_file.parent.exists() and self.telemetry_file.parent.is_dir()},"timestamp":int(datetime.now(timezone.utc).timestamp()*1000)})+"\n")
        except: pass
        # #endregion
        
        # Test write capability
        # #region agent log
        try:
            test_write_ok = False
            try:
                with self.telemetry_file.open("a", encoding="utf-8") as test_f:
                    test_f.write("")
                test_write_ok = True
            except Exception as test_e:
                test_write_ok = False
            with open("/Users/icmini/02luka/.cursor/debug.log", "a") as debug_f:
                debug_f.write(json_module.dumps({"sessionId":"debug-session","runId":"init","hypothesisId":"E","location":"gateway_v3_router.py:75","message":"Init write test","data":{"test_write_ok":test_write_ok,"telemetry_file":str(self.telemetry_file)},"timestamp":int(datetime.now(timezone.utc).timestamp()*1000)})+"\n")
        except: pass
        # #endregion
        
        # Worker settings
        self.sleep_interval = self.config["worker"]["sleep_interval_seconds"]
        self.supported_targets = set(self.config["routing"]["supported_targets"])
        self.routing_hint_mapping = self.config["routing"].get("routing_hint_mapping", {})
        self.default_target = self.config["routing"]["default_target"]
        
        log.info(f"Gateway v3 Router initialized (Phase {self.config['phase']})")
        log.info(f"Inbox: {self.inbox}")
        log.info(f"Telemetry file: {self.telemetry_file}")
        log.info(f"Supported targets: {self.supported_targets}")
        log.info(f"Config loaded from: {self.config_path} ({'YAML file' if self.config_path.exists() else 'defaults'})")
    
    def _load_config(self) -> Dict[str, Any]:
        """Load configuration from YAML file."""
        # #region agent log
        import json as json_module
        try:
            with open("/Users/icmini/02luka/.cursor/debug.log", "a") as debug_f:
                debug_f.write(json_module.dumps({"sessionId":"debug-session","runId":"init","hypothesisId":"D","location":"gateway_v3_router.py:96","message":"Loading config","data":{"config_path":str(self.config_path),"config_exists":self.config_path.exists()},"timestamp":int(datetime.now(timezone.utc).timestamp()*1000)})+"\n")
        except: pass
        # #endregion
        if not self.config_path.exists():
            log.warning(f"Config not found: {self.config_path}, using defaults")
            # #region agent log
            try:
                with open("/Users/icmini/02luka/.cursor/debug.log", "a") as debug_f:
                    debug_f.write(json_module.dumps({"sessionId":"debug-session","runId":"init","hypothesisId":"D","location":"gateway_v3_router.py:100","message":"Config not found, using defaults","data":{},"timestamp":int(datetime.now(timezone.utc).timestamp()*1000)})+"\n")
            except: pass
            # #endregion
            return self._default_config()
        
        try:
            with self.config_path.open("r", encoding="utf-8") as f:
                loaded = yaml.safe_load(f) or {}
            # #region agent log
            try:
                with open("/Users/icmini/02luka/.cursor/debug.log", "a") as debug_f:
                    debug_f.write(json_module.dumps({"sessionId":"debug-session","runId":"init","hypothesisId":"D","location":"gateway_v3_router.py:107","message":"Config loaded","data":{"telemetry_log_file":loaded.get("telemetry",{}).get("log_file","NOT_FOUND"),"use_v5_stack":loaded.get("use_v5_stack","NOT_FOUND")},"timestamp":int(datetime.now(timezone.utc).timestamp()*1000)})+"\n")
            except: pass
            # #endregion
            return loaded
        except Exception as e:
            # #region agent log
            try:
                with open("/Users/icmini/02luka/.cursor/debug.log", "a") as debug_f:
                    debug_f.write(json_module.dumps({"sessionId":"debug-session","runId":"init","hypothesisId":"D","location":"gateway_v3_router.py:113","message":"Config load exception","data":{"error":str(e)},"timestamp":int(datetime.now(timezone.utc).timestamp()*1000)})+"\n")
            except: pass
            # #endregion
            log.error(f"Failed to load config: {e}, using defaults")
            return self._default_config()
    
    def _default_config(self) -> Dict[str, Any]:
        """Return default configuration."""
        return {
            "version": "3.0",
            "phase": 0,
            "routing": {
                "default_target": "CLC",
                "supported_targets": ["CLC"],
                "routing_hint_mapping": {"dev_oss": "CLC"}
            },
            "telemetry": {
                "log_file": "g/telemetry/gateway_v3_router.jsonl",  # Updated to match config standard
                "log_level": "INFO"
            },
            "directories": {
                "inbox": "bridge/inbox/main",  # Default, but YAML config should override
                "processed": "bridge/processed/MAIN",
                "error": "bridge/error/MAIN"
            },
            "worker": {
                "sleep_interval_seconds": 1.0,
                "process_one_by_one": True
            },
            "use_v5_stack": True  # Default to v5 enabled
        }
    
    def load_wo(self, wo_path: Path) -> Optional[Dict[str, Any]]:
        """Load WO from YAML file with error handling."""
        try:
            with wo_path.open("r", encoding="utf-8") as f:
                data = yaml.safe_load(f) or {}
            
            # Ensure wo_id exists
            if "wo_id" not in data:
                data["wo_id"] = wo_path.stem
            
            return data
        except yaml.YAMLError as e:
            log.error(f"YAML parse error in {wo_path}: {e}")
            return None
        except Exception as e:
            log.error(f"Error loading WO from {wo_path}: {e}")
            return None
    
    def route_wo(self, wo_data: Dict[str, Any]) -> Optional[str]:
        """
        Route WO to target inbox.
        
        Priority:
        1. strict_target (if present and valid)
        2. routing_hint (if present, mapped via config)
        3. default_target (from config)
        4. None (error - no valid route)
        """
        # Priority 1: strict_target
        strict_target = wo_data.get("strict_target")
        if strict_target:
            target = str(strict_target).upper()
            if target in self.supported_targets:
                return target
            else:
                log.warning(f"strict_target '{target}' not supported in Phase {self.config['phase']}")
        
        # Priority 2: routing_hint
        routing_hint = wo_data.get("routing_hint")
        if routing_hint:
            hint_str = str(routing_hint).lower()
            mapped_target = self.routing_hint_mapping.get(hint_str)
            if mapped_target and mapped_target in self.supported_targets:
                return mapped_target
        
        # Priority 3: default_target
        if self.default_target in self.supported_targets:
            return self.default_target
        
        # No valid route
        return None
    
    def log_telemetry(self, event: Dict[str, Any]) -> None:
        """Log telemetry event as JSONL."""
        # #region agent log
        import json as json_module
        try:
            with open("/Users/icmini/02luka/.cursor/debug.log", "a") as debug_f:
                debug_f.write(json_module.dumps({"sessionId":"debug-session","runId":"runtime","hypothesisId":"B","location":"gateway_v3_router.py:163","message":"log_telemetry called","data":{"telemetry_file":str(self.telemetry_file),"event_action":event.get("action","unknown")},"timestamp":int(datetime.now(timezone.utc).timestamp()*1000)})+"\n")
        except: pass
        # #endregion
        event["ts"] = datetime.now(timezone.utc).isoformat()
        try:
            # #region agent log
            try:
                with open("/Users/icmini/02luka/.cursor/debug.log", "a") as debug_f:
                    debug_f.write(json_module.dumps({"sessionId":"debug-session","runId":"runtime","hypothesisId":"C","location":"gateway_v3_router.py:170","message":"Before telemetry write","data":{"telemetry_file":str(self.telemetry_file),"file_exists":self.telemetry_file.exists(),"parent_exists":self.telemetry_file.parent.exists()},"timestamp":int(datetime.now(timezone.utc).timestamp()*1000)})+"\n")
            except: pass
            # #endregion
            with self.telemetry_file.open("a", encoding="utf-8") as f:
                f.write(json.dumps(event) + "\n")
            # #region agent log
            try:
                with open("/Users/icmini/02luka/.cursor/debug.log", "a") as debug_f:
                    debug_f.write(json_module.dumps({"sessionId":"debug-session","runId":"runtime","hypothesisId":"C","location":"gateway_v3_router.py:175","message":"After telemetry write","data":{"telemetry_file":str(self.telemetry_file),"file_exists":self.telemetry_file.exists()},"timestamp":int(datetime.now(timezone.utc).timestamp()*1000)})+"\n")
            except: pass
            # #endregion
        except Exception as e:
            # #region agent log
            try:
                with open("/Users/icmini/02luka/.cursor/debug.log", "a") as debug_f:
                    debug_f.write(json_module.dumps({"sessionId":"debug-session","runId":"runtime","hypothesisId":"C","location":"gateway_v3_router.py:180","message":"Telemetry write exception","data":{"telemetry_file":str(self.telemetry_file),"error":str(e),"error_type":type(e).__name__},"timestamp":int(datetime.now(timezone.utc).timestamp()*1000)})+"\n")
            except: pass
            # #endregion
            log.error(f"Failed to write telemetry: {e}")
    
    def process_wo(self, wo_path: Path) -> bool:
        """
        Process a single WO file.
        
        Uses v5 stack if available, falls back to legacy routing.
        
        Returns:
            True if processed successfully, False on error
        """
        # #region agent log
        import json as json_module
        try:
            with open("/Users/icmini/02luka/.cursor/debug.log", "a") as debug_f:
                debug_f.write(json_module.dumps({"sessionId":"debug-session","runId":"runtime","hypothesisId":"B","location":"gateway_v3_router.py:172","message":"process_wo called","data":{"wo_path":str(wo_path),"wo_exists":wo_path.exists()},"timestamp":int(datetime.now(timezone.utc).timestamp()*1000)})+"\n")
        except: pass
        # #endregion
        wo_id = wo_path.stem
        
        # Try v5 stack first (if available and enabled)
        if V5_STACK_AVAILABLE and self.config.get("use_v5_stack", True):
            try:
                result = process_wo_with_lane_routing(str(wo_path))
                
                # Log v5 processing result (all statuses are valid v5 results)
                telemetry_data = {
                    "wo_id": result.wo_id,
                    "source_inbox": "MAIN",
                    "action": "process_v5",
                    "status": "ok" if result.status.value in ["COMPLETED", "EXECUTING"] else "error",
                    "strict_ops": len(result.strict_operations),
                    "local_ops": len(result.local_operations),
                    "rejected_ops": len(result.rejected_operations),
                }
                
                if result.clc_wo_path:
                    telemetry_data["clc_wo_path"] = result.clc_wo_path
                
                if result.errors:
                    telemetry_data["errors"] = result.errors
                
                # Handle file movement based on status
                if result.status.value in ["COMPLETED", "EXECUTING"]:
                    # Move to processed/
                    processed_path = self.processed / wo_path.name
                    try:
                        if wo_path.exists():
                            wo_path.rename(processed_path)
                        telemetry_data["moved_to"] = str(processed_path)
                        self.log_telemetry(telemetry_data)
                        log.info(f"Processed {result.wo_id} via v5 stack (status: {result.status.value})")
                        return True
                    except Exception as e:
                        log.error(f"Failed to move {result.wo_id} to processed/: {e}")
                        # Still log telemetry even if move failed
                        self.log_telemetry(telemetry_data)
                        return False
                elif result.status.value == "REJECTED":
                    # REJECTED is a valid v5 result (BLOCKED lane)
                    # File should already be moved by wo_processor_v5.move_wo_to_error()
                    # Just log the telemetry
                    if wo_path.exists():
                        # If not moved yet, move it
                        error_path = self.error / wo_path.name
                        try:
                            wo_path.rename(error_path)
                            telemetry_data["moved_to"] = str(error_path)
                        except Exception as e:
                            log.warning(f"WO already moved or move failed: {e}")
                    else:
                        telemetry_data["moved_to"] = "already_moved_by_v5"
                    
                    telemetry_data["status"] = "error"
                    self.log_telemetry(telemetry_data)
                    log.info(f"Rejected {result.wo_id} via v5 stack (BLOCKED lane)")
                    return True  # This is a successful v5 processing result
                else:
                    # FAILED status - move to error/
                    error_path = self.error / wo_path.name
                    try:
                        if wo_path.exists():
                            wo_path.rename(error_path)
                        telemetry_data["moved_to"] = str(error_path)
                        telemetry_data["status"] = "error"
                        self.log_telemetry(telemetry_data)
                        log.warning(f"v5 processing failed for {result.wo_id}, moved to error/")
                        return True  # Still a v5 processing result (not legacy)
                    except Exception as e:
                        log.error(f"Failed to move {result.wo_id} to error/: {e}")
                        # Still log telemetry
                        self.log_telemetry(telemetry_data)
                        return False
            except Exception as e:
                log.warning(f"v5 stack processing failed for {wo_id}: {e}, falling back to legacy routing")
                import traceback
                log.debug(f"v5 processing exception traceback: {traceback.format_exc()}")
                # Fall through to legacy routing
        
        # Legacy routing (fallback)
        wo_id = wo_path.stem
        
        # Load WO
        wo_data = self.load_wo(wo_path)
        if wo_data is None:
            # Move to error/
            error_path = self.error / wo_path.name
            try:
                wo_path.rename(error_path)
                self.log_telemetry({
                    "wo_id": wo_id,
                    "source_inbox": "MAIN",
                    "action": "parse",
                    "status": "error",
                    "error_type": "yaml_parse",
                    "moved_to": str(error_path)
                })
                log.warning(f"Moved {wo_id} to error/ (YAML parse failed)")
            except Exception as e:
                log.error(f"Failed to move {wo_id} to error/: {e}")
            return False
        
        wo_id = wo_data.get("wo_id", wo_id)
        strict_target = wo_data.get("strict_target")
        routing_hint = wo_data.get("routing_hint")
        
        # Route WO
        target = self.route_wo(wo_data)
        if target is None:
            # No valid route - move to error/
            error_path = self.error / wo_path.name
            try:
                wo_path.rename(error_path)
                self.log_telemetry({
                    "wo_id": wo_id,
                    "source_inbox": "MAIN",
                    "action": "route",
                    "status": "error",
                    "error_type": "no_valid_route",
                    "strict_target": strict_target,
                    "routing_hint": routing_hint,
                    "moved_to": str(error_path)
                })
                log.warning(f"Moved {wo_id} to error/ (no valid route)")
            except Exception as e:
                log.error(f"Failed to move {wo_id} to error/: {e}")
            return False
        
        # Move to target inbox
        target_inbox = ROOT / "bridge/inbox" / target
        # Handle symlink case: check if it exists and is accessible
        # Don't use resolve() to avoid symlink loops - just check if we can access it
        try:
            if target_inbox.is_symlink():
                # Symlink exists, check if target is accessible
                target_resolved = target_inbox.readlink()
                # If symlink is broken or points to itself, create directory instead
                if not target_inbox.exists() or target_resolved == target_inbox.name:
                    # Remove broken symlink and create directory
                    target_inbox.unlink(missing_ok=True)
                    target_inbox.mkdir(parents=True, exist_ok=True)
            elif not target_inbox.exists():
                # Doesn't exist, create it
                target_inbox.mkdir(parents=True, exist_ok=True)
            elif not target_inbox.is_dir():
                # Exists but not a directory - this shouldn't happen, but handle it
                log.warning(f"Target inbox {target_inbox} exists but is not a directory")
        except Exception as e:
            log.error(f"Error preparing target inbox {target_inbox}: {e}")
            # Fallback: try to create parent and target
            target_inbox.parent.mkdir(parents=True, exist_ok=True)
            if not target_inbox.exists():
                target_inbox.mkdir(exist_ok=True)
        target_path = target_inbox / wo_path.name
        
        try:
            # Move file
            wo_path.rename(target_path)
            
            # Log telemetry
            self.log_telemetry({
                "wo_id": wo_id,
                "source_inbox": "MAIN",
                "target_inbox": target,
                "strict_target": strict_target,
                "routing_hint": routing_hint,
                "action": "route",
                "status": "ok"
            })
            
            log.info(f"Routed {wo_id} from MAIN to {target}")
            return True
            
        except Exception as e:
            log.error(f"Failed to move {wo_id} to {target}: {e}")
            # Try to move to error/ as fallback
            # IMPORTANT: wo_path.rename() may have succeeded even if exception occurred later
            # Check both locations to ensure we can recover the file
            error_path = self.error / wo_path.name
            try:
                # Check original location first (rename may have failed)
                if wo_path.exists():
                    # File still at original location, rename failed - move to error/
                    wo_path.rename(error_path)
                    log.info(f"Moved {wo_id} from original location to error/")
                    # Log telemetry after successful move
                    self.log_telemetry({
                        "wo_id": wo_id,
                        "source_inbox": "MAIN",
                        "target_inbox": target,
                        "action": "move",
                        "status": "error",
                        "error": str(e),
                        "moved_to": str(error_path)
                    })
                # Check target location (rename succeeded but later operation failed)
                elif target_path.exists():
                    # File was successfully moved but error occurred later (e.g., telemetry)
                    # Move from target location to error/
                    target_path.rename(error_path)
                    log.info(f"Moved {wo_id} from target location to error/")
                    # Log telemetry after successful move
                    self.log_telemetry({
                        "wo_id": wo_id,
                        "source_inbox": "MAIN",
                        "target_inbox": target,
                        "action": "move",
                        "status": "error",
                        "error": str(e),
                        "moved_to": str(error_path)
                    })
                else:
                    # File doesn't exist at either location - this should not happen
                    # but handle gracefully to avoid secondary exceptions
                    log.warning(f"WO file {wo_id} not found at {wo_path} or {target_path}, cannot move to error/")
                    # Log telemetry even if file move failed (for tracking)
                    self.log_telemetry({
                        "wo_id": wo_id,
                        "source_inbox": "MAIN",
                        "target_inbox": target,
                        "action": "move",
                        "status": "error",
                        "error": str(e),
                        "moved_to": None,
                        "note": "File not found at either location"
                    })
                    return False
            except Exception as move_error:
                log.error(f"Failed to move {wo_id} to error/: {move_error}")
            return False
    
    def run(self):
        """Main loop: watch inbox and process WOs one-by-one."""
        log.info("Gateway v3 Router started. Watching bridge/inbox/main/...")
        
        while True:
            try:
                # Get all YAML files, sorted by modification time (oldest first)
                wo_files = sorted(
                    self.inbox.glob("*.yaml"),
                    key=lambda p: p.stat().st_mtime
                )
                
                if wo_files:
                    # Process oldest file first
                    wo_file = wo_files[0]
                    log.info(f"Processing {wo_file.name}...")
                    self.process_wo(wo_file)
                else:
                    # #region agent log
                    import json as json_module
                    try:
                        with open("/Users/icmini/02luka/.cursor/debug.log", "a") as debug_f:
                            debug_f.write(json_module.dumps({"sessionId":"debug-session","runId":"runtime","hypothesisId":"B","location":"gateway_v3_router.py:410","message":"No WOs in inbox","data":{"inbox":str(self.inbox),"inbox_exists":self.inbox.exists()},"timestamp":int(datetime.now(timezone.utc).timestamp()*1000)})+"\n")
                    except: pass
                    # #endregion
                    # No files, sleep longer
                    time.sleep(self.sleep_interval * 2)
                    continue
                
                # Sleep before next iteration
                time.sleep(self.sleep_interval)
                
            except KeyboardInterrupt:
                log.info("Received interrupt, shutting down...")
                break
            except Exception as e:
                log.error(f"Error in main loop: {e}", exc_info=True)
                time.sleep(self.sleep_interval * 2)  # Longer sleep on error


if __name__ == "__main__":
    router = GatewayV3Router()
    router.run()
