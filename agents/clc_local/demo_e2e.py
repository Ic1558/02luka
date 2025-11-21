#!/usr/bin/env python3
"""
CLC Local E2E Demo
Simulates GMX -> Liam -> CLC Local flow.
"""
import sys
import os
import json
from pathlib import Path

# Add project root to path
PROJECT_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(PROJECT_ROOT))

from agents.clc_local import executor

def run_demo():
    print("--- CLC Local E2E Demo ---")
    
    sandbox_dir = PROJECT_ROOT / "agents/clc_local/sandbox"
    sandbox_dir.mkdir(parents=True, exist_ok=True)
    
    target_file = sandbox_dir / "demo_e2e.txt"
    
    # Clean up previous run
    if target_file.exists():
        target_file.unlink()
    
    # 1. Simulate Task Spec (from Liam)
    print("[1] Simulating Task Spec...")
    task_spec = {
        "task_id": "demo-task-001",
        "intent": "generate-file",
        "operations": [
            {
                "op": "write_file",
                "file": str(target_file),
                "content": "Hello from CLC Local E2E Demo!"
            }
        ]
    }
    print(json.dumps(task_spec, indent=2))
    
    # 2. Execute Task
    print("\n[2] Executing Task...")
    try:
        result = executor.execute_task(task_spec)
        print(json.dumps(result, indent=2))
    except Exception as e:
        print(f"❌ Execution failed: {e}")
        return False
        
    # 3. Verify Result
    print("\n[3] Verifying Result...")
    if target_file.exists():
        content = target_file.read_text()
        print(f"    File created: {target_file}")
        print(f"    Content: {content}")
        if content == "Hello from CLC Local E2E Demo!":
            print("    ✅ Content matches")
        else:
            print("    ❌ Content mismatch")
            return False
    else:
        print("    ❌ File not created")
        return False

    print("\n✅ E2E Demo PASSED")
    return True

if __name__ == "__main__":
    success = run_demo()
    sys.exit(0 if success else 1)
