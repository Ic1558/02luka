import os
import sys
from typing import Dict, Any, Optional

# Ensure we can import from tools and agents
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "../../")))

from agents.liam.mary_router import enforce_overseer, apply_decision_gate, init_task_state
from tools.ap_io_v31.writer import write_ledger_entry

class LiamAgent:
    """
    Liam - Local Orchestrator
    Stateful agent that manages the task.md lifecycle and orchestrates local execution.
    """
    
    def __init__(self, task_path: str = "task.md"):
        self.task_path = task_path
        self.current_task_spec: Optional[Dict[str, Any]] = None
        
    def wake(self, task_spec: Dict[str, Any]) -> Dict[str, Any]:
        """
        Wake up Liam with a new task specification.
        1. Validate intent via Mary Router.
        2. Initialize task state.
        3. Log start event.
        """
        self.current_task_spec = task_spec
        parent_id = task_spec.get("parent_id")
        
        # 1. Validate Intent
        decision = enforce_overseer(task_spec, payload={}) # Payload empty for initial check
        gate = apply_decision_gate(decision)
        
        if gate["status"] != "APPROVED":
            write_ledger_entry(
                agent="Liam",
                event="task_rejected",
                data={"reason": gate["reason"]},
                parent_id=parent_id
            )
            return gate
            
        # 2. Initialize State
        task_file = init_task_state(task_spec)
        self.task_path = task_file
        
        # 3. Log Start
        ledger_id = write_ledger_entry(
            agent="Liam",
            event="task_start",
            data={"task_spec": task_spec, "task_file": task_file},
            parent_id=parent_id
        )
        
        return {
            "status": "STARTED",
            "ledger_id": ledger_id,
            "task_file": task_file,
            "gate_result": gate
        }

    def update_progress(self, step_id: str, status: str) -> None:
        """
        Update the progress of a specific step in task.md.
        """
        if not os.path.exists(self.task_path):
            return
            
        with open(self.task_path, "r") as f:
            lines = f.readlines()
            
        new_lines = []
        for line in lines:
            if f"<!-- id: {step_id} -->" in line:
                if status == "COMPLETED":
                    line = line.replace("- [ ]", "- [x]").replace("- [/]", "- [x]")
                elif status == "IN_PROGRESS":
                    line = line.replace("- [ ]", "- [/]")
            new_lines.append(line)
            
        with open(self.task_path, "w") as f:
            f.writelines(new_lines)

if __name__ == "__main__":
    # Simple test
    agent = LiamAgent()
    spec = {
        "intent": "refactor",
        "target_files": ["test.py"],
        "parent_id": "test-parent-123"
    }
    result = agent.wake(spec)
    print(f"Wake Result: {result}")
