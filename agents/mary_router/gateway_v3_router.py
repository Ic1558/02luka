#!/usr/bin/env python3
"""
Mary Router Gateway v3 - Central Inbox Router

Phase 0: Routes WOs from bridge/inbox/MAIN/ to bridge/inbox/CLC/
- Supports strict_target (priority)
- Supports routing_hint (fallback)
- Phase 0: Only CLC destination supported
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
        
        # Worker settings
        self.sleep_interval = self.config["worker"]["sleep_interval_seconds"]
        self.supported_targets = set(self.config["routing"]["supported_targets"])
        self.routing_hint_mapping = self.config["routing"].get("routing_hint_mapping", {})
        self.default_target = self.config["routing"]["default_target"]
        
        log.info(f"Gateway v3 Router initialized (Phase {self.config['phase']})")
        log.info(f"Inbox: {self.inbox}")
        log.info(f"Supported targets: {self.supported_targets}")
    
    def _load_config(self) -> Dict[str, Any]:
        """Load configuration from YAML file."""
        if not self.config_path.exists():
            log.warning(f"Config not found: {self.config_path}, using defaults")
            return self._default_config()
        
        try:
            with self.config_path.open("r", encoding="utf-8") as f:
                return yaml.safe_load(f) or {}
        except Exception as e:
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
                "log_file": "g/telemetry/gateway_v3_router.log",
                "log_level": "INFO"
            },
            "directories": {
                "inbox": "bridge/inbox/MAIN",
                "processed": "bridge/processed/MAIN",
                "error": "bridge/error/MAIN"
            },
            "worker": {
                "sleep_interval_seconds": 1.0,
                "process_one_by_one": True
            }
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
        event["ts"] = datetime.now(timezone.utc).isoformat()
        try:
            with self.telemetry_file.open("a", encoding="utf-8") as f:
                f.write(json.dumps(event) + "\n")
        except Exception as e:
            log.error(f"Failed to write telemetry: {e}")
    
    def process_wo(self, wo_path: Path) -> bool:
        """
        Process a single WO file.
        
        Returns:
            True if processed successfully, False on error
        """
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
        target_inbox.mkdir(parents=True, exist_ok=True)
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
            try:
                wo_path.rename(self.error / wo_path.name)
                self.log_telemetry({
                    "wo_id": wo_id,
                    "source_inbox": "MAIN",
                    "target_inbox": target,
                    "action": "move",
                    "status": "error",
                    "error": str(e),
                    "moved_to": str(self.error / wo_path.name)
                })
            except Exception as move_error:
                log.error(f"Failed to move {wo_id} to error/: {move_error}")
            return False
    
    def run(self):
        """Main loop: watch inbox and process WOs one-by-one."""
        log.info("Gateway v3 Router started. Watching bridge/inbox/MAIN/...")
        
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
