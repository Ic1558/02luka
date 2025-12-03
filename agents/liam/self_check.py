import os
import sys
import json
import uuid

# Ensure we can import from tools
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "../../")))

from tools.ap_io_v31.writer import write_ledger_entry

def run_self_check():
    print("Starting Liam Integration Self-Check...")
    
    parent_id = "liam-selftest-001"
    
    # 1. Verify write_ledger_entry call
    # 2. Emit overseer_check
    print("Emitting overseer_check...")
    write_ledger_entry(
        agent="Liam",
        event="selftest_overseer_check",
        data={"note": "liam self-check", "status": "starting"},
        parent_id=parent_id
    )
    
    # 3. Emit task_start
    print("Emitting task_start...")
    write_ledger_entry(
        agent="Liam",
        event="selftest_task_start",
        data={"task": "selftest", "source": "GMX"},
        parent_id=parent_id
    )
    
    # 4. Generate task_spec
    task_spec = {
        "source": "liam",
        "intent": "smoke",
        "target_files": ["test.txt"],
        "context": {"note": "liam smoke test"}
    }
    
    # 5. Write to Bridge Inbox
    inbox_path = "/Users/icmini/02luka/bridge/inbox/LIAM"
    os.makedirs(inbox_path, exist_ok=True)
    file_path = os.path.join(inbox_path, "WO-LIAM-SMOKETEST.json")
    
    print(f"Writing task_spec to {file_path}...")
    with open(file_path, "w") as f:
        json.dump(task_spec, f, indent=2)
        
    # 6. Confirm results
    print("Emitting selftest_complete...")
    write_ledger_entry(
        agent="Liam",
        event="selftest_complete",
        data={"bridge_write": "ok", "ledger": "ok"},
        parent_id=parent_id
    )
    
    print("Self-check complete.")

if __name__ == "__main__":
    run_self_check()
