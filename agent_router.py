#!/usr/bin/env python3
"""Agent Router - Orchestrates skill execution based on intent mapping"""
import sys
import json
import os
import time
import yaml
import subprocess
from pathlib import Path
from datetime import datetime

# Constants
LUKA_HOME = Path(os.getenv("LUKA_HOME", os.path.expanduser("~/LocalProjects/02luka_local_g/g")))
SKILLS_DIR = LUKA_HOME / "skills"
MAP_FILE = Path.home() / "02luka" / "core" / "nlp" / "nlp_command_map.yaml"
RECEIPTS_DIR = Path.home() / "02luka" / "logs" / "agent" / "receipts"
RESULTS_DIR = Path.home() / "02luka" / "logs" / "agent" / "results"
DEFAULT_TIMEOUT = 120  # seconds

def load_intent_map():
    """Load nlp_command_map.yaml"""
    if not MAP_FILE.exists():
        return {}
    with open(MAP_FILE, 'r') as f:
        return yaml.safe_load(f) or {}

def validate_params(params):
    """Block CloudStorage paths and validate params"""
    if not params:
        return True, None

    # Check all string values for CloudStorage paths
    for key, value in params.items():
        if isinstance(value, str):
            if "Library/CloudStorage" in value or "My Drive/02luka" in value:
                return False, f"CloudStorage path not allowed in param '{key}': {value}"
    return True, None

def execute_skill(skill_name, params, timeout=DEFAULT_TIMEOUT):
    """Execute a skill with JSON input/output contract"""
    skill_path = SKILLS_DIR / skill_name

    if not skill_path.exists():
        return {"ok": False, "error": f"skill not found: {skill_name}"}

    # Build skill input
    skill_input = {
        "skill": skill_name.replace('.py', '').replace('.zsh', ''),
        "params": params or {}
    }

    try:
        # Execute skill
        result = subprocess.run(
            [str(skill_path)],
            input=json.dumps(skill_input),
            capture_output=True,
            text=True,
            timeout=timeout,
            cwd=str(LUKA_HOME)
        )

        # Parse JSON output
        try:
            return json.loads(result.stdout)
        except json.JSONDecodeError:
            return {
                "ok": False,
                "error": "skill output not valid JSON",
                "stdout": result.stdout,
                "stderr": result.stderr
            }

    except subprocess.TimeoutExpired:
        return {"ok": False, "error": f"skill timed out after {timeout}s"}
    except Exception as e:
        return {"ok": False, "error": str(e)}

def write_receipt(task_id, intent, skills, start_time):
    """Write receipt to receipts dir"""
    RECEIPTS_DIR.mkdir(parents=True, exist_ok=True)
    receipt = {
        "task_id": task_id,
        "intent": intent,
        "skills": skills,
        "timestamp": datetime.now().isoformat(),
        "duration_ms": int((time.time() - start_time) * 1000)
    }

    receipt_path = RECEIPTS_DIR / f"{task_id}.json"
    with open(receipt_path, 'w') as f:
        json.dump(receipt, f, indent=2)

    return receipt_path

def write_result(task_id, results, success):
    """Write results to results dir"""
    RESULTS_DIR.mkdir(parents=True, exist_ok=True)
    result = {
        "task_id": task_id,
        "success": success,
        "results": results,
        "timestamp": datetime.now().isoformat()
    }

    result_path = RESULTS_DIR / f"{task_id}.json"
    with open(result_path, 'w') as f:
        json.dump(result, f, indent=2)

    return result_path

def publish_to_redis(message):
    """Publish result to Redis gg:nlp channel"""
    redis_pub = SKILLS_DIR / "redis_pub.py"
    if not redis_pub.exists():
        return {"ok": False, "error": "redis_pub.py not found"}

    redis_input = {
        "skill": "redis_pub",
        "params": {
            "channel": "gg:nlp",
            "message": json.dumps(message)
        }
    }

    try:
        result = subprocess.run(
            [str(redis_pub)],
            input=json.dumps(redis_input),
            capture_output=True,
            text=True,
            timeout=10
        )
        return json.loads(result.stdout)
    except Exception as e:
        return {"ok": False, "error": str(e)}

def main():
    start_time = time.time()

    # Parse input
    try:
        data = json.load(sys.stdin)
    except json.JSONDecodeError as e:
        print(json.dumps({"ok": False, "error": f"invalid JSON input: {e}"}))
        sys.exit(1)

    intent = data.get("intent", "")
    params = data.get("params", {})
    emit_redis = data.get("emit_redis", False)
    task_id = data.get("task_id", f"task_{int(time.time() * 1000)}")

    if not intent:
        print(json.dumps({"ok": False, "error": "intent is required"}))
        sys.exit(1)

    # Validate params
    valid, error = validate_params(params)
    if not valid:
        print(json.dumps({"ok": False, "error": error}))
        sys.exit(1)

    # Load intent map
    intent_map = load_intent_map()

    if intent not in intent_map:
        print(json.dumps({"ok": False, "error": f"unknown intent: {intent}"}))
        sys.exit(1)

    # Get skill chain
    skill_chain = intent_map[intent].get("skills", [])
    if not skill_chain:
        print(json.dumps({"ok": False, "error": f"no skills defined for intent: {intent}"}))
        sys.exit(1)

    # Execute skill chain
    results = []
    success = True

    for skill_def in skill_chain:
        skill_name = skill_def.get("name", "")
        skill_params = skill_def.get("params", {})
        timeout = skill_def.get("timeout", DEFAULT_TIMEOUT)

        # Merge global params with skill-specific params
        merged_params = {**params, **skill_params}

        result = execute_skill(skill_name, merged_params, timeout)
        results.append({
            "skill": skill_name,
            "result": result
        })

        if not result.get("ok", False):
            success = False
            break  # Stop on first failure

    # Write receipt
    receipt_path = write_receipt(task_id, intent, skill_chain, start_time)

    # Write result
    result_path = write_result(task_id, results, success)

    # Build output
    output = {
        "ok": success,
        "task_id": task_id,
        "intent": intent,
        "results": results,
        "receipt": str(receipt_path),
        "result_file": str(result_path),
        "duration_ms": int((time.time() - start_time) * 1000)
    }

    # Publish to Redis if requested
    if emit_redis:
        redis_result = publish_to_redis(output)
        output["redis_publish"] = redis_result

    print(json.dumps(output, indent=2))
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()
