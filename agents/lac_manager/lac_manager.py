import os
import yaml
import logging
import sys
import time
from pathlib import Path
from typing import Dict, Any

# Add project root to sys.path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "../../")))

from agents.ai_manager.ai_manager import AIManager
from agents.alter.helpers import polish_and_translate_if_needed, polish_if_needed

# Configuration
LAC_BASE_DIR = Path(os.environ.get("LAC_BASE_DIR", os.path.expanduser("~/02luka"))).resolve()
CONFIG_FILE = LAC_BASE_DIR / "g/config/lac_lanes.yaml"
LOG_FILE = LAC_BASE_DIR / "logs/lac_daemon.log"

# Setup Logging
LOG_FILE.parent.mkdir(parents=True, exist_ok=True)
logging.basicConfig(
    filename=LOG_FILE,
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%dT%H:%M:%S%z"
)

class LACManager:
    def __init__(self):
        self.config = self._load_config()
        self.lanes = self.config.get("lanes", {})
        self.rules = self.config.get("routing_rules", [])

    def _load_config(self) -> Dict[str, Any]:
        if not CONFIG_FILE.exists():
            raise FileNotFoundError(f"LAC Lanes config not found: {CONFIG_FILE}")
        with open(CONFIG_FILE, "r") as f:
            return yaml.safe_load(f)

    def route_request(self, intent: str) -> str:
        """Determines the target lane based on intent."""
        intent_lower = intent.lower()
        
        for rule in self.rules:
            # Simple eval for "if" condition (very basic for now)
            # "intent contains 'refactor'" -> "refactor" in intent_lower
            condition = rule.get("if", "")
            target = rule.get("target")
            
            if self._evaluate_condition(condition, intent_lower):
                return target
        
        return "dev_lac_manager" # Default to self if no match

    def _evaluate_condition(self, condition: str, intent: str) -> bool:
        # Basic parser for "intent contains 'x' or intent contains 'y'"
        # This is a placeholder for a real NLP classifier or richer logic
        parts = condition.split(" or ")
        for part in parts:
            if "intent contains" in part:
                keyword = part.split("'")[1]
                if keyword in intent:
                    return True
        return False

    def process_task(self, task: Dict[str, Any]):
        intent = task.get("intent", "")
        lane = self.route_request(intent)
        self._maybe_polish_report(task)
        
        logging.info(f"Routing task '{intent}' to lane: {lane}")
        
        # In a real implementation, this would dispatch to the specific lane handler.
        # For v4.2 skeleton, we just log the routing decision.
        print(f"Task routed to: {lane}")
        
        # v4.2 Implementation: Execute via AI Manager if it's a dev lane
        if "dev" in lane:
            logging.info(f"Executing task via AI Manager in lane {lane}...")
            ai_manager = AIManager()
            
            # Construct requirement content as Fenced YAML for reliable parsing
            requirement = f"""
```yaml
wo_id: "{task.get('wo_id', 'UNKNOWN')}"
objective: "{task.get('objective')}"
files: {task.get('files', [])}
lane: "{lane}"
source: "{task.get('source', 'LAC')}"
complexity: "{task.get('complexity', 'simple')}"
```
"""
            result = ai_manager.run_self_complete(requirement)
            logging.info(f"AI Manager execution result: {result.get('status')}")
            
            if result.get("status") in ["merged", "success"]:
                print(f"✅ Task executed and merged: {task.get('objective')}")
            else:
                print(f"❌ Task execution failed: {result.get('reason') or result}")

    def _maybe_polish_report(self, task: Dict[str, Any]) -> None:
        """
        Optionally polish/translate report content for client-facing tasks.
        """
        content = task.get("report_content") or task.get("content")
        if not content:
            return

        ctx: Dict[str, Any] = {
            "polish": task.get("polish"),
            "alter_polish_enabled": task.get("alter_polish_enabled"),
            "client_facing": task.get("client_facing"),
            "project": task.get("project"),
            "tone": task.get("tone", "formal"),
            "target_language": task.get("target_language"),
        }

        target_lang = ctx.get("target_language")
        if target_lang:
            polished = polish_and_translate_if_needed(content, context=ctx)
        else:
            polished = polish_if_needed(content, context=ctx)

        task["report_content"] = polished
        task["content"] = polished
        
    def run(self):
        """Main daemon loop - watches inbox continuously."""
        import json
        import signal

        # Use lowercase canonical paths
        inbox = LAC_BASE_DIR / "bridge/inbox/lac"
        processing = LAC_BASE_DIR / "bridge/processing/lac"
        processed = LAC_BASE_DIR / "bridge/processed/lac"
        quarantine = LAC_BASE_DIR / "bridge/quarantine/lac"

        # Ensure directories exist
        for d in [inbox, processing, processed, quarantine]:
            d.mkdir(parents=True, exist_ok=True)

        logging.info("=" * 60)
        logging.info("LAC Manager Daemon started")
        logging.info(f"Agent ID: codex")
        logging.info(f"Base directory: {LAC_BASE_DIR}")
        logging.info(f"Watching: {inbox}")
        logging.info(f"Heartbeat: 10 seconds")
        logging.info("=" * 60)

        # Signal handling for graceful shutdown
        shutdown_requested = False

        def signal_handler(signum, frame):
            nonlocal shutdown_requested
            logging.info(f"Received signal {signum}, shutting down...")
            shutdown_requested = True

        signal.signal(signal.SIGTERM, signal_handler)
        signal.signal(signal.SIGINT, signal_handler)

        # Main daemon loop
        while not shutdown_requested:
            try:
                # Find oldest work order (FIFO) - accept both YAML and JSON
                tasks = sorted(
                    list(inbox.glob("*.yaml")) +
                    list(inbox.glob("*.yml")) +
                    list(inbox.glob("*.json")),
                    key=lambda p: p.stat().st_mtime
                )

                # Skip recently written files (avoid partial writes)
                now = time.time()
                tasks = [t for t in tasks if (now - t.stat().st_mtime) > 2]

                if not tasks:
                    # Heartbeat - no work
                    time.sleep(10)
                    continue

                task_file = tasks[0]
                logging.info(f"[PICKUP] {task_file.name}")

                proc_path = None  # Initialize to avoid UnboundLocalError
                try:
                    # Move to processing
                    proc_path = processing / task_file.name
                    task_file.rename(proc_path)

                    # Load based on extension
                    with open(proc_path, "r") as f:
                        if proc_path.suffix in ['.yaml', '.yml']:
                            task = yaml.safe_load(f)
                        else:  # .json
                            task = json.load(f)

                    logging.info(f"[PROCESS] {task.get('objective', 'NO OBJECTIVE')}")
                    self.process_task(task)

                    # Move to processed
                    proc_path.rename(processed / task_file.name)
                    logging.info(f"[COMPLETE] {task_file.name}")

                except Exception as e:
                    logging.error(f"[ERROR] {task_file.name}: {e}", exc_info=True)
                    # Quarantine to prevent infinite retry
                    error_name = f"ERROR_{task_file.name if task_file.exists() else proc_path.name}"
                    error_file = quarantine / error_name

                    # Move from wherever it is now
                    if proc_path and proc_path.exists():
                        proc_path.rename(error_file)
                    elif task_file.exists():
                        task_file.rename(error_file)

                    logging.warning(f"[QUARANTINE] -> {error_file.name}")

                # Small delay between files
                time.sleep(1)

            except KeyboardInterrupt:
                logging.info("Keyboard interrupt, shutting down...")
                break
            except Exception as e:
                logging.error(f"[DAEMON ERROR] Unexpected: {e}", exc_info=True)
                time.sleep(5)  # Back off on errors

        logging.info("LAC Manager Daemon shutdown complete")

if __name__ == "__main__":
    manager = LACManager()
    manager.run()
