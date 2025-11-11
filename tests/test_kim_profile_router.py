from __future__ import annotations

from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from datetime import datetime, timedelta, timezone

from core.nlp.nlp_command_dispatcher import DEFAULT_PROFILE, CommandDispatcher, Profile
from core.nlp.profile_store import ProfileStore


def make_store(tmp_path):
    return ProfileStore(tmp_path / "profiles.json", ttl_days=30)


def make_dispatcher(tmp_path, published):
    profiles = {
        DEFAULT_PROFILE.id: DEFAULT_PROFILE,
        "kim_k2_poc": Profile(
            id="kim_k2_poc",
            name="Kim K2",
            description="K2",
            provider="k2_thinking",
            channel="kim:requests",
            metadata={"request_mode": "k2"},
        ),
    }

    def publisher(channel, payload):
        published.append((channel, payload))

    store = make_store(tmp_path)
    dispatcher = CommandDispatcher(
        profile_store=store,
        profiles=profiles,
        publisher=publisher,
        events_channel="kim:dispatcher:events",
        k2_profile_id="kim_k2_poc",
    )
    return dispatcher, store


def test_profile_store_ttl(tmp_path):
    store = make_store(tmp_path)
    now = datetime(2024, 1, 1, tzinfo=timezone.utc)
    store.set_profile("chat-1", "kim_k2_poc", now=now)
    record = store.get_profile("chat-1", now=now + timedelta(days=5))
    assert record.profile_id == "kim_k2_poc"

    # Expired after 31 days -> fallback to default
    record = store.get_profile("chat-1", now=now + timedelta(days=31))
    assert record.profile_id == DEFAULT_PROFILE.id


def test_use_command_sets_profile(tmp_path):
    published: list[tuple[str, dict]] = []
    dispatcher, store = make_dispatcher(tmp_path, published)

    result = dispatcher.handle_payload({"text": "/use kim_k2_poc", "chat": {"id": 123}})
    assert result["ok"]
    assert store.get_profile(123).profile_id == "kim_k2_poc"
    assert published[0][0] == "kim:dispatcher:events"
    assert published[0][1]["event"] == "kim.dispatch.profile_set"


def test_dispatch_uses_selected_profile(tmp_path):
    published: list[tuple[str, dict]] = []
    dispatcher, store = make_dispatcher(tmp_path, published)
    dispatcher.profile_store.set_profile("chat-5", "kim_k2_poc")

    result = dispatcher.handle_payload(
        {
            "text": "Explain quantum",
            "chat": {"id": "chat-5"},
            "from": {"username": "tester"},
        }
    )
    assert result["profile"] == "kim_k2_poc"

    request_channel, request_payload = published[0]
    assert request_channel == "kim:requests"
    assert request_payload["profile"] == "kim_k2_poc"
    assert request_payload["one_off"] is False

    event_channel, event_payload = published[1]
    assert event_channel == "kim:dispatcher:events"
    assert event_payload["event"] == "kim.dispatch.sent"


def test_k2_command_is_one_off(tmp_path):
    published: list[tuple[str, dict]] = []
    dispatcher, store = make_dispatcher(tmp_path, published)
    store.set_profile("chat-7", "kim_k2_poc")

    result = dispatcher.handle_payload(
        {
            "text": "/k2 What is intelligence?",
            "chat": {"id": "chat-7"},
        }
    )
    assert result["one_off"] is True

    # Ensure request uses K2 profile
    request_channel, request_payload = published[0]
    assert request_channel == "kim:requests"
    assert request_payload["profile"] == "kim_k2_poc"
    assert request_payload["one_off"] is True

    # Profile should remain persisted
    assert store.get_profile("chat-7").profile_id == "kim_k2_poc"


def test_force_profile_override(tmp_path):
    published: list[tuple[str, dict]] = []
    dispatcher, _ = make_dispatcher(tmp_path, published)

    result = dispatcher.handle_payload(
        {
            "text": "Hello from CLI",
            "chat": {"id": "cli-1"},
            "force_profile": "kim_k2_poc",
        }
    )
    assert result["one_off"] is True
    request_channel, payload = published[0]
    assert request_channel == "kim:requests"
    assert payload["profile"] == "kim_k2_poc"

    event_channel, event_payload = published[1]
    assert event_channel == "kim:dispatcher:events"
    assert event_payload["event"] == "kim.dispatch.sent"
