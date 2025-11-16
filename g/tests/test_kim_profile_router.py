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


def test_use_command_missing_profile_id(tmp_path):
    """Test /use command with missing profile ID."""
    published: list[tuple[str, dict]] = []
    dispatcher, _ = make_dispatcher(tmp_path, published)

    result = dispatcher.handle_payload({
        "text": "/use",
        "chat": {"id": "123456"},
    })
    assert not result["ok"]
    assert result["action"] == "profile_update"
    assert "profile id required" in result["error"].lower()
    assert "available_profiles" in result


def test_use_command_unknown_profile(tmp_path):
    """Test /use command with unknown profile."""
    published: list[tuple[str, dict]] = []
    dispatcher, _ = make_dispatcher(tmp_path, published)

    result = dispatcher.handle_payload({
        "text": "/use unknown_profile",
        "chat": {"id": "123456"},
    })
    assert not result["ok"]
    assert result["action"] == "profile_update"
    assert "unknown profile" in result["error"].lower()
    assert "available_profiles" in result


def test_k2_command_missing_question(tmp_path):
    """Test /k2 command with missing question."""
    published: list[tuple[str, dict]] = []
    dispatcher, _ = make_dispatcher(tmp_path, published)

    result = dispatcher.handle_payload({
        "text": "/k2",
        "chat": {"id": "123456"},
    })
    assert not result["ok"]
    assert result["action"] == "dispatch"
    assert "question required" in result["error"].lower()


def test_k2_command_empty_question(tmp_path):
    """Test /k2 command with empty question."""
    published: list[tuple[str, dict]] = []
    dispatcher, _ = make_dispatcher(tmp_path, published)

    result = dispatcher.handle_payload({
        "text": "/k2   ",
        "chat": {"id": "123456"},
    })
    assert not result["ok"]
    assert "question required" in result["error"].lower()


def test_missing_chat_id(tmp_path):
    """Test handling payload without chat ID."""
    published: list[tuple[str, dict]] = []
    dispatcher, _ = make_dispatcher(tmp_path, published)

    result = dispatcher.handle_payload({
        "text": "Hello",
    })
    assert not result["ok"]
    assert "chat id missing" in result["error"].lower()


def test_empty_message(tmp_path):
    """Test handling empty message."""
    published: list[tuple[str, dict]] = []
    dispatcher, _ = make_dispatcher(tmp_path, published)

    result = dispatcher.handle_payload({
        "text": "",
        "chat": {"id": "123456"},
    })
    assert not result["ok"]
    assert "empty message" in result["error"].lower()


def test_whitespace_only_message(tmp_path):
    """Test handling whitespace-only message."""
    published: list[tuple[str, dict]] = []
    dispatcher, _ = make_dispatcher(tmp_path, published)

    result = dispatcher.handle_payload({
        "text": "   \n\t  ",
        "chat": {"id": "123456"},
    })
    assert not result["ok"]
    assert "empty message" in result["error"].lower()


def test_unknown_profile_fallback(tmp_path):
    """Test fallback to default when stored profile doesn't exist."""
    published: list[tuple[str, dict]] = []
    dispatcher, store = make_dispatcher(tmp_path, published)
    
    # Manually set a profile that doesn't exist in dispatcher
    # (simulating profile removed from config)
    store.set_profile("123456", "nonexistent_profile")
    
    # Should fallback to default
    result = dispatcher.handle_payload({
        "text": "Hello",
        "chat": {"id": "123456"},
    })
    assert result["ok"]
    assert result["profile"] == DEFAULT_PROFILE.id


def test_profile_reset_clears_store(tmp_path):
    """Test that /use default clears the store."""
    published: list[tuple[str, dict]] = []
    dispatcher, store = make_dispatcher(tmp_path, published)
    
    # Set profile
    store.set_profile("123456", "kim_k2_poc")
    assert store.get_profile("123456").profile_id == "kim_k2_poc"
    
    # Reset
    result = dispatcher.handle_payload({
        "text": "/use default",
        "chat": {"id": "123456"},
    })
    assert result["ok"]
    
    # Verify cleared (returns default)
    record = store.get_profile("123456")
    assert record.profile_id == DEFAULT_PROFILE.id
