import os

import pytest

from agents.dev_gmxcli.dev_worker import DevGMXCLIWorker
from agents.dev_oss.dev_worker import DevOSSWorker
from agents.dev_common.reasoner_backend import OssLLMBackend


@pytest.fixture(autouse=True)
def set_base_dir(tmp_path, monkeypatch):
    """
    Use an isolated base directory to keep writes sandboxed.
    """
    monkeypatch.setenv("LAC_BASE_DIR", str(tmp_path))
    return tmp_path


class FakeBackend:
    def __init__(self, patches):
        self.patches = patches
        self.calls = 0

    def run(self, prompt: str, context=None):
        self.calls += 1
        return {"patches": self.patches, "answer": "ok"}


def test_dev_oss_with_fake_backend_writes(tmp_path):
    backend = FakeBackend(
        patches=[{"file": "g/src/oss_backend.py", "content": "print('oss')\n"}]
    )
    worker = DevOSSWorker(backend=backend)
    result = worker.execute_task({"objective": "test oss backend"})

    assert result["status"] == "success"
    assert backend.calls == 1
    file_path = os.path.join(os.getenv("LAC_BASE_DIR"), "g/src/oss_backend.py")
    assert os.path.exists(file_path)


def test_dev_gmxcli_with_fake_backend_writes(tmp_path):
    backend = FakeBackend(
        patches=[{"file": "g/src/gmx_backend.py", "content": "print('gmx')\n"}]
    )
    worker = DevGMXCLIWorker(backend=backend)
    result = worker.execute_task({"objective": "test gmx backend"})

    assert result["status"] == "success"
    assert backend.calls == 1
    file_path = os.path.join(os.getenv("LAC_BASE_DIR"), "g/src/gmx_backend.py")
    assert os.path.exists(file_path)


def test_oss_backend_health_check_runs():
    backend = OssLLMBackend()
    result = backend.health_check()
    assert result["status"] in {"ok", "error"}
    # ensure keys exist
    assert "returncode" in result or "reason" in result


class FakeAnswerBackend:
    def __init__(self, answer: str):
        self.answer = answer
        self.calls = 0

    def run(self, prompt: str, context=None):
        self.calls += 1
        return {"answer": self.answer}


def test_dev_oss_parses_json_answer_to_patches(tmp_path):
    answer = '{"patches": [{"file": "g/src/from_answer.py", "content": "print(\\"ok\\")\\n"}]}'
    backend = FakeAnswerBackend(answer)
    worker = DevOSSWorker(backend=backend)
    result = worker.execute_task({"objective": "parse answer"})

    assert result["status"] == "success"
    assert backend.calls == 1
    file_path = os.path.join(os.getenv("LAC_BASE_DIR"), "g/src/from_answer.py")
    assert os.path.exists(file_path)
