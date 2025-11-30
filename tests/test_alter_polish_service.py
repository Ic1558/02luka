import time
from pathlib import Path

import pytest

from agents.alter.polish_service import AlterPolishService
from agents.alter.usage_tracker import UsageTracker


class FakeTracker:
    def __init__(self, allow=True):
        self.allow = allow
        self.recorded = 0
        self.daily_limit = 10
        self.lifetime_limit = 20
        self.daily_alert_ratio = 0.9
        self.lifetime_alert_ratio = 0.8

    def check_quota(self, count: int = 0):
        return {"daily": self.allow, "lifetime": self.allow}

    def record_usage(self, count: int = 1):
        self.recorded += count

    def get_daily_count(self):
        return self.recorded

    def get_lifetime_count(self):
        return self.recorded

    def get_remaining(self):
        return {"daily": self.daily_limit - self.recorded, "lifetime": self.lifetime_limit - self.recorded}

    def should_alert(self):
        return {"daily": False, "lifetime": False}


class FakeResponse:
    def __init__(self, content: str):
        self.choices = [type("Choice", (), {"message": type("Msg", (), {"content": content})()})()]


class FakeClient:
    def __init__(self, content: str = "polished"):
        self._content = content
        self.calls = 0

        class Chat:
            def __init__(self, outer):
                self.outer = outer

            class completions:
                @staticmethod
                def create(*args, **kwargs):
                    raise NotImplementedError("placeholder")  # pragma: no cover

        # Override create dynamically
        def create(*args, **kwargs):
            self.calls += 1
            return FakeResponse(self._content)

        self.chat = type("ChatWrapper", (), {"completions": type("Completions", (), {"create": create})()})()


class FlakyClient(FakeClient):
    def __init__(self, fail_times: int, succeed_content: str = "ok"):
        super().__init__(content=succeed_content)
        self.fail_times = fail_times

        def create(*args, **kwargs):
            if self.fail_times > 0:
                self.fail_times -= 1
                raise RuntimeError("transient")
            self.calls += 1
            return FakeResponse(self._content)

        self.chat = type("ChatWrapper", (), {"completions": type("Completions", (), {"create": create})()})()


def _write_config(tmp_path: Path):
    config_dir = tmp_path / "g" / "config"
    config_dir.mkdir(parents=True, exist_ok=True)
    (config_dir / "ai_providers.yaml").write_text(
        """
providers:
  ALTER_LIGHT:
    base_url: "https://alterhq.com/api/v1"
    api_key_env: "ALTER_API_KEY"
    model: "Claude#claude-3-haiku-20240307"
""",
        encoding="utf-8",
    )


def test_polish_returns_original_when_quota_denied(tmp_path):
    _write_config(tmp_path)
    tracker = FakeTracker(allow=False)
    client = FakeClient()
    service = AlterPolishService(base_dir=tmp_path, tracker=tracker, client=client)

    original = "hello"
    assert service.polish_text(original) == original
    assert tracker.recorded == 0
    assert client.calls == 0


def test_polish_records_usage_and_returns_result(tmp_path):
    _write_config(tmp_path)
    tracker = FakeTracker(allow=True)
    client = FakeClient(content="improved")
    service = AlterPolishService(base_dir=tmp_path, tracker=tracker, client=client)

    result = service.polish_text("hello", tone="formal")
    assert result == "improved"
    assert tracker.recorded == 1
    assert client.calls == 1


def test_translate_and_polish_and_translate(tmp_path):
    _write_config(tmp_path)
    tracker = FakeTracker(allow=True)
    client = FakeClient(content="translated")
    service = AlterPolishService(base_dir=tmp_path, tracker=tracker, client=client)

    assert service.translate("hi", target_lang="th") == "translated"
    assert service.polish_and_translate("hi", target_lang="th") == "translated"
    assert tracker.recorded == 3  # polish + translate + translate


def test_retry_logic_on_transient_error(monkeypatch, tmp_path):
    _write_config(tmp_path)
    tracker = FakeTracker(allow=True)
    client = FlakyClient(fail_times=1, succeed_content="ok-after-retry")
    service = AlterPolishService(base_dir=tmp_path, tracker=tracker, client=client, max_retries=2, backoff_base=1.0)

    slept = {"count": 0}

    def fake_sleep(seconds):
        slept["count"] += 1

    monkeypatch.setattr(time, "sleep", fake_sleep)

    result = service.polish_text("retry me")
    assert result == "ok-after-retry"
    assert slept["count"] == 1
    assert tracker.recorded == 1
    assert client.calls == 1  # success call only counted after failures consumed


def test_returns_original_when_client_missing(tmp_path, monkeypatch):
    _write_config(tmp_path)
    tracker = FakeTracker(allow=True)
    # Force client to None and no ALTER_API_KEY
    monkeypatch.delenv("ALTER_API_KEY", raising=False)
    service = AlterPolishService(base_dir=tmp_path, tracker=tracker, client=None)

    text = "fallback"
    assert service.polish_text(text) == text
    assert tracker.recorded == 0
