"""Integration tests for Kim K2 dispatcher flow."""
from __future__ import annotations

from pathlib import Path
import sys
from datetime import datetime, timezone

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from core.nlp.nlp_command_dispatcher import (
    CommandDispatcher,
    DEFAULT_PROFILE,
    Profile,
    create_redis_publisher,
)
from core.nlp.profile_store import ProfileStore


def make_profiles():
    """Create test profiles."""
    return {
        DEFAULT_PROFILE.id: DEFAULT_PROFILE,
        "kim_k2_poc": Profile(
            id="kim_k2_poc",
            name="Kim K2",
            description="K2 Thinking model",
            provider="k2_thinking",
            channel="kim:requests",
            metadata={"request_mode": "k2"},
        ),
    }


def make_dispatcher(tmp_path, published):
    """Create dispatcher with test setup."""
    profiles = make_profiles()
    
    def publisher(channel, payload):
        published.append((channel, payload))
    
    store = ProfileStore(tmp_path / "profiles.json", ttl_days=30)
    dispatcher = CommandDispatcher(
        profile_store=store,
        profiles=profiles,
        publisher=publisher,
        events_channel="kim:dispatcher:events",
        k2_profile_id="kim_k2_poc",
    )
    return dispatcher, store


def test_end_to_end_profile_selection(tmp_path):
    """Test complete flow: select profile, send message."""
    published: list[tuple[str, dict]] = []
    dispatcher, store = make_dispatcher(tmp_path, published)
    
    # Step 1: Select profile
    result = dispatcher.handle_payload({
        "text": "/use kim_k2_poc",
        "chat": {"id": "123456"},
        "from": {"username": "test_user"},
    })
    assert result["ok"]
    assert result["action"] == "profile_update"
    assert result["profile"] == "kim_k2_poc"
    
    # Verify profile stored
    record = store.get_profile("123456")
    assert record.profile_id == "kim_k2_poc"
    
    # Verify event emitted
    assert len(published) == 1
    event_channel, event_payload = published[0]
    assert event_channel == "kim:dispatcher:events"
    assert event_payload["event"] == "kim.dispatch.profile_set"
    assert event_payload["chat_id"] == "123456"
    assert event_payload["profile"] == "kim_k2_poc"
    
    # Step 2: Send message (should use selected profile)
    published.clear()
    result = dispatcher.handle_payload({
        "text": "Explain quantum computing",
        "chat": {"id": "123456"},
        "from": {"username": "test_user"},
        "message_id": 789,
    })
    assert result["ok"]
    assert result["profile"] == "kim_k2_poc"
    assert result["one_off"] is False
    
    # Verify request published
    assert len(published) == 2  # Request + event
    request_channel, request_payload = published[0]
    assert request_channel == "kim:requests"
    assert request_payload["profile"] == "kim_k2_poc"
    assert request_payload["provider"] == "k2_thinking"
    assert request_payload["prompt"] == "Explain quantum computing"
    assert request_payload["one_off"] is False
    assert request_payload["chat"]["id"] == "123456"
    
    # Verify event
    event_channel, event_payload = published[1]
    assert event_channel == "kim:dispatcher:events"
    assert event_payload["event"] == "kim.dispatch.sent"
    assert event_payload["chat_id"] == "123456"
    assert event_payload["profile"] == "kim_k2_poc"


def test_k2_one_off_flow(tmp_path):
    """Test /k2 command flow (one-off, doesn't change persistence)."""
    published: list[tuple[str, dict]] = []
    dispatcher, store = make_dispatcher(tmp_path, published)
    
    # Set default profile first
    store.set_profile("123456", DEFAULT_PROFILE.id)
    
    # Send /k2 command
    result = dispatcher.handle_payload({
        "text": "/k2 What is machine learning?",
        "chat": {"id": "123456"},
        "from": {"username": "test_user"},
    })
    assert result["ok"]
    assert result["profile"] == "kim_k2_poc"
    assert result["one_off"] is True
    
    # Verify request uses K2
    request_channel, request_payload = published[0]
    assert request_channel == "kim:requests"
    assert request_payload["profile"] == "kim_k2_poc"
    assert request_payload["one_off"] is True
    assert request_payload["prompt"] == "What is machine learning?"
    
    # Verify profile NOT changed (still default)
    record = store.get_profile("123456")
    assert record.profile_id == DEFAULT_PROFILE.id


def test_profile_reset_flow(tmp_path):
    """Test resetting profile to default."""
    published: list[tuple[str, dict]] = []
    dispatcher, store = make_dispatcher(tmp_path, published)
    
    # Set K2 profile
    store.set_profile("123456", "kim_k2_poc")
    
    # Reset to default
    result = dispatcher.handle_payload({
        "text": "/use default",
        "chat": {"id": "123456"},
    })
    assert result["ok"]
    assert result["action"] == "profile_update"
    assert result["profile"] == DEFAULT_PROFILE.id
    
    # Verify profile cleared
    record = store.get_profile("123456")
    assert record.profile_id == DEFAULT_PROFILE.id
    
    # Verify event
    event_channel, event_payload = published[0]
    assert event_channel == "kim:dispatcher:events"
    assert event_payload["event"] == "kim.dispatch.profile_reset"
    assert event_payload["chat_id"] == "123456"


def test_force_profile_override(tmp_path):
    """Test force_profile payload override."""
    published: list[tuple[str, dict]] = []
    dispatcher, store = make_dispatcher(tmp_path, published)
    
    # Set different profile
    store.set_profile("123456", DEFAULT_PROFILE.id)
    
    # Force K2 via payload
    result = dispatcher.handle_payload({
        "text": "Hello from CLI",
        "chat": {"id": "123456"},
        "force_profile": "kim_k2_poc",
    })
    assert result["ok"]
    assert result["profile"] == "kim_k2_poc"
    assert result["one_off"] is True
    
    # Verify request uses forced profile
    request_channel, request_payload = published[0]
    assert request_channel == "kim:requests"
    assert request_payload["profile"] == "kim_k2_poc"
    assert request_payload["one_off"] is True
    
    # Verify stored profile NOT changed
    record = store.get_profile("123456")
    assert record.profile_id == DEFAULT_PROFILE.id


def test_multiple_chats_independent(tmp_path):
    """Test multiple chats with independent profiles."""
    published: list[tuple[str, dict]] = []
    dispatcher, store = make_dispatcher(tmp_path, published)
    
    # Set different profiles for different chats
    dispatcher.handle_payload({
        "text": "/use kim_k2_poc",
        "chat": {"id": "chat-1"},
    })
    dispatcher.handle_payload({
        "text": "/use default",
        "chat": {"id": "chat-2"},
    })
    
    # Verify independent storage
    record1 = store.get_profile("chat-1")
    assert record1.profile_id == "kim_k2_poc"
    
    record2 = store.get_profile("chat-2")
    assert record2.profile_id == DEFAULT_PROFILE.id
    
    # Send messages - should use respective profiles
    published.clear()
    dispatcher.handle_payload({
        "text": "Question 1",
        "chat": {"id": "chat-1"},
    })
    dispatcher.handle_payload({
        "text": "Question 2",
        "chat": {"id": "chat-2"},
    })
    
    # Verify correct profiles used
    assert len(published) == 4  # 2 requests + 2 events
    request1 = published[0][1]
    request2 = published[2][1]
    assert request1["profile"] == "kim_k2_poc"
    assert request2["profile"] == DEFAULT_PROFILE.id


def test_chat_id_normalization(tmp_path):
    """Test chat ID extraction from various payload formats."""
    published: list[tuple[str, dict]] = []
    dispatcher, _ = make_dispatcher(tmp_path, published)
    
    # Test chat.id format
    result1 = dispatcher.handle_payload({
        "text": "/use kim_k2_poc",
        "chat": {"id": "123456"},
    })
    assert result1["ok"]
    
    # Test chat_id format
    result2 = dispatcher.handle_payload({
        "text": "/use kim_k2_poc",
        "chat_id": "789012",
    })
    assert result2["ok"]
    
    # Test conversation_id format
    result3 = dispatcher.handle_payload({
        "text": "/use kim_k2_poc",
        "conversation_id": "345678",
    })
    assert result3["ok"]
    
    # Test missing chat ID
    result4 = dispatcher.handle_payload({
        "text": "/use kim_k2_poc",
    })
    assert not result4["ok"]
    assert "chat id missing" in result4["error"].lower()


def test_empty_message_handling(tmp_path):
    """Test handling of empty messages."""
    published: list[tuple[str, dict]] = []
    dispatcher, _ = make_dispatcher(tmp_path, published)
    
    # Empty text
    result = dispatcher.handle_payload({
        "text": "",
        "chat": {"id": "123456"},
    })
    assert not result["ok"]
    assert "empty message" in result["error"].lower()
    
    # Missing text
    result = dispatcher.handle_payload({
        "chat": {"id": "123456"},
    })
    assert not result["ok"]
    assert "empty message" in result["error"].lower()
    
    # Whitespace only
    result = dispatcher.handle_payload({
        "text": "   ",
        "chat": {"id": "123456"},
    })
    assert not result["ok"]
    assert "empty message" in result["error"].lower()


def test_event_timestamp_format(tmp_path):
    """Test event timestamp format."""
    published: list[tuple[str, dict]] = []
    dispatcher, _ = make_dispatcher(tmp_path, published)
    
    dispatcher.handle_payload({
        "text": "/use kim_k2_poc",
        "chat": {"id": "123456"},
    })
    
    # Verify timestamp in event
    event_channel, event_payload = published[0]
    assert "ts" in event_payload
    ts_str = event_payload["ts"]
    
    # Should be ISO format
    ts = datetime.fromisoformat(ts_str.replace("Z", "+00:00"))
    assert ts.tzinfo == timezone.utc
