import os

import pytest

from agents.dev_oss.dev_worker import DevOSSWorker
from agents.dev_gmxcli.dev_worker import DevGMXCLIWorker
from agents.docs_v4.docs_worker import DocsWorkerV4
from agents.qa_v4.qa_worker import QAWorkerV4


@pytest.fixture(autouse=True)
def set_base_dir(tmp_path, monkeypatch):
    """
    Ensure all policy writes stay within a temporary sandbox.
    """
    monkeypatch.setenv("LAC_BASE_DIR", str(tmp_path))
    return tmp_path


def test_dev_oss_can_write_allowed_path():
    worker = DevOSSWorker()
    result = worker.self_write("g/src/sample.py", "print('hello')\n")
    assert result["status"] == "success"
    assert os.path.exists(result["file"])


def test_dev_oss_blocked_from_git():
    worker = DevOSSWorker()
    result = worker.self_write(".git/config", "block me")
    assert result["status"] == "blocked"
    assert "FORBIDDEN" in result["reason"]


def test_qa_can_write_tests_dir():
    worker = QAWorkerV4()
    result = worker.write_test_file("tests/test_sample.py", "assert True\n")
    assert result["status"] == "success"
    assert os.path.exists(result["file"])


def test_docs_can_write_docs_dir():
    worker = DocsWorkerV4()
    result = worker.write_doc_file("g/docs/readme.md", "# docs\n")
    assert result["status"] == "success"
    assert os.path.exists(result["file"])


def test_dev_gmxcli_execute_task_pipeline():
    worker = DevGMXCLIWorker()
    task = {
        "patches": [
            {"file": "g/src/a.py", "content": "print('a')\n"},
            {"file": "g/src/b.py", "content": "print('b')\n"},
        ]
    }
    result = worker.execute_task(task)
    assert result["status"] == "success"
    assert result["self_applied"] is True
    assert len(result["files_touched"]) == 2
