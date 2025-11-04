#!/usr/bin/env python3
"""Agent Router - Orchestrates skill execution based on intent mapping"""
import sys
import json
import os
import time
try:
    import yaml  # type: ignore
except ImportError:  # pragma: no cover - optional dependency
    yaml = None
import subprocess
from pathlib import Path
from datetime import datetime

# Paths & constants
REPO_ROOT = Path(__file__).resolve().parent
ENV_LUKA_HOME = os.getenv("LUKA_HOME")
LUKA_HOME = Path(ENV_LUKA_HOME).expanduser() if ENV_LUKA_HOME else REPO_ROOT
SKILLS_DIR = Path(os.getenv("LUKA_SKILLS_DIR", LUKA_HOME / "skills"))

INTENT_MAP_CANDIDATES = [
    Path(os.getenv("LUKA_INTENT_MAP")) if os.getenv("LUKA_INTENT_MAP") else None,
    LUKA_HOME / "config" / "intent_map.json",
    LUKA_HOME / "config" / "intent_map.yaml",
    REPO_ROOT / "config" / "intent_map.json",
    REPO_ROOT / "config" / "intent_map.yaml",
    Path.home() / "02luka" / "core" / "nlp" / "nlp_command_map.yaml",
]

LOG_BASE = Path(os.getenv("LUKA_LOG_DIR", LUKA_HOME / "logs" / "agent"))
RECEIPTS_DIR = LOG_BASE / "receipts"
RESULTS_DIR = LOG_BASE / "results"
DEFAULT_TIMEOUT = 120  # seconds

def load_intent_map():
    """Load the intent mapping from the first available candidate."""
    for candidate in INTENT_MAP_CANDIDATES:
        if not candidate:
            continue
        candidate_path = Path(candidate).expanduser()
        if not candidate_path.exists():
            continue
        with open(candidate_path, 'r', encoding='utf-8') as handle:
            suffix = candidate_path.suffix.lower()
            if suffix in {'.yaml', '.yml'}:
                if not yaml:
                    continue
                data = yaml.safe_load(handle) or {}
            elif suffix == '.json':
                data = json.load(handle) or {}
            else:
                continue
            if isinstance(data, dict):
                normalised = {}
                for key, value in data.items():
                    if isinstance(value, dict):
                        normalised[key] = value
                    elif isinstance(value, list):
                        normalised[key] = {
                            "skills": [
                                item if isinstance(item, dict) else {"name": str(item)}
                                for item in value
                            ]
                        }
                if normalised:
                    return normalised
    return {}

def resolve_skill_path(skill_name):
    """Resolve a skill name to an executable path."""
    name_path = Path(skill_name)
    candidates = []

    if name_path.is_absolute():
        candidates.append(name_path)
    else:
        candidates.extend([
            SKILLS_DIR / name_path,
            REPO_ROOT / name_path,
            REPO_ROOT / "skills" / name_path,
        ])

    for candidate in candidates:
        if candidate.exists():
            return candidate
    return None

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
    skill_path = resolve_skill_path(skill_name)

    if not skill_path:
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
    intent_config = intent_map[intent]
    skill_chain = intent_config.get("skills", []) if isinstance(intent_config, dict) else []
    if not skill_chain:
        print(json.dumps({"ok": False, "error": f"no skills defined for intent: {intent}"}))
        sys.exit(1)

    # Execute skill chain
    results = []
    success = True

    for skill_def in skill_chain:
        if isinstance(skill_def, str):
            skill_name = skill_def
            skill_params = {}
            timeout = DEFAULT_TIMEOUT
        else:
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
