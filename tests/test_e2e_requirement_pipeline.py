from __future__ import annotations

import os
from pathlib import Path

from agents.ai_manager.ai_manager import AIManager
from agents.dev_oss.dev_worker import DevOSSWorker
from agents.qa_v4.qa_worker import QAWorkerV4
from agents.docs_v4.docs_worker import DocsWorkerV4


def test_requirement_to_dev_qa_docs(tmp_path, monkeypatch):
    # Run in isolated workspace
    base_dir = tmp_path
    monkeypatch.setenv("LAC_BASE_DIR", str(base_dir))

    # Prepare Requirement.md
    requirement = base_dir / "Requirement.md"
    requirement.write_text(
        """
# Requirement: End-to-end demo
**ID:** REQ-20251129-20
**Priority:** P1
**Complexity:** Simple

## Objective
Run full flow from Requirement to Dev, QA, and Docs.
""",
        encoding="utf-8",
    )

    # Build work order + architect spec
    manager = AIManager()
    wo_result = manager.build_work_order_from_requirement(str(requirement), file_count=1)
    assert wo_result["status"] == "ready"
    wo = wo_result["work_order"]
    assert wo.get("architect_spec")

    # Dev task with plan to write a source file
    wo["plan"] = {
        "patches": [
            {"file": "g/src/demo/output.txt", "content": "hello from dev"}
        ]
    }
    dev_task = manager.build_dev_task(wo)

    dev_worker = DevOSSWorker(backend=None)
    dev_result = dev_worker.execute_task(dev_task)
    assert dev_result["status"] == "success"
    src_file = Path(base_dir / "g/src/demo/output.txt")
    assert src_file.read_text(encoding="utf-8") == "hello from dev"

    # QA step (no lint/tests needed for demo)
    qa_worker = QAWorkerV4(actions=None)
    qa_result = qa_worker.execute_task({"run_tests": False})
    assert qa_result["status"] == "success"

    # Docs step
    docs_worker = DocsWorkerV4()
    docs_result = docs_worker.execute_task(
        {
            "plan": {
                "patches": [
                    {"file": "g/docs/demo_doc.md", "content": "Completed end-to-end flow."}
                ]
            }
        }
    )
    assert docs_result["status"] == "success"
    doc_file = Path(base_dir / "g/docs/demo_doc.md")
    assert doc_file.read_text(encoding="utf-8") == "Completed end-to-end flow."
