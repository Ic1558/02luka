"""
AI Manager state machine for autonomous pipeline routing.
"""

from __future__ import annotations

from typing import Dict, List, Optional

from agents.ai_manager.actions.direct_merge import direct_merge


class AIManager:
    def __init__(self):
        self.state: str = "NEW"

    def transition(self, wo: Dict, current_state: str, event: Optional[str]) -> str:
        if current_state == "NEW" and event == "START":
            return "DEV_IN_PROGRESS"

        if current_state == "DEV_IN_PROGRESS" and event == "DEV_DONE":
            return "QA_IN_PROGRESS"

        if current_state == "QA_IN_PROGRESS":
            if event == "QA_PASSED":
                return "DOCS_IN_PROGRESS"
            if event == "QA_FAILED":
                return "QA_FAILED"

        if current_state == "QA_FAILED":
            wo["qa_fail_count"] = wo.get("qa_fail_count", 0) + 1
            if wo["qa_fail_count"] >= 3:
                return "ESCALATE"
            return "DEV_IN_PROGRESS"

        if current_state == "DOCS_IN_PROGRESS" and event == "DOCS_DONE":
            return self._docs_done_transition(wo)

        if current_state == "DOCS_DONE":
            return self._docs_done_transition(wo)

        return current_state

    def _docs_done_transition(self, wo: Dict) -> str:
        if wo.get("self_apply", True) and wo.get("complexity", "simple") == "simple":
            return "DIRECT_MERGE"
        return "ROUTE_TO_CLC"

    def handle_docs_completion(self, wo: Dict, files_touched: Optional[List[str]] = None) -> Dict:
        next_state = self.transition(wo, "DOCS_DONE", event=None)
        if next_state == "DIRECT_MERGE":
            merge_result = direct_merge(wo, files_touched or [])
            merge_result["next_state"] = next_state
            return merge_result

        return {"status": "routed", "next_state": next_state}


__all__ = ["AIManager"]
