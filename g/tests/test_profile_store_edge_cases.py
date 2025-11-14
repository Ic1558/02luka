"""Edge case tests for ProfileStore."""
from __future__ import annotations

from pathlib import Path
import sys
from datetime import datetime, timedelta, timezone

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from core.nlp.nlp_command_dispatcher import DEFAULT_PROFILE
from core.nlp.profile_store import ProfileStore, ProfileRecord


def make_store(tmp_path, ttl_days=30):
    return ProfileStore(tmp_path / "profiles.json", ttl_days=ttl_days)


def test_ttl_expiration_exact_boundary(tmp_path):
    """Test TTL expiration at exact boundary."""
    store = make_store(tmp_path, ttl_days=30)
    now = datetime(2024, 1, 1, tzinfo=timezone.utc)
    
    # Set profile
    store.set_profile("chat-1", "kim_k2_poc", now=now)
    
    # At 29 days, should still be valid
    record = store.get_profile("chat-1", now=now + timedelta(days=29))
    assert record.profile_id == "kim_k2_poc"
    
    # At exactly 30 days, should expire
    record = store.get_profile("chat-1", now=now + timedelta(days=30))
    assert record.profile_id == DEFAULT_PROFILE.id
    
    # At 31 days, definitely expired
    record = store.get_profile("chat-1", now=now + timedelta(days=31))
    assert record.profile_id == DEFAULT_PROFILE.id


def test_ttl_expiration_with_hours(tmp_path):
    """Test TTL expiration with hour precision."""
    store = make_store(tmp_path, ttl_days=30)
    now = datetime(2024, 1, 1, 12, 0, 0, tzinfo=timezone.utc)
    
    store.set_profile("chat-2", "kim_k2_poc", now=now)
    
    # 30 days minus 1 hour should still be valid
    record = store.get_profile("chat-2", now=now + timedelta(days=30, hours=-1))
    assert record.profile_id == "kim_k2_poc"
    
    # 30 days plus 1 hour should expire
    record = store.get_profile("chat-2", now=now + timedelta(days=30, hours=1))
    assert record.profile_id == DEFAULT_PROFILE.id


def test_concurrent_access_safety(tmp_path):
    """Test thread safety with concurrent access."""
    import threading
    
    store = make_store(tmp_path)
    results = []
    errors = []
    
    def set_profile(chat_id, profile_id):
        try:
            store.set_profile(chat_id, profile_id)
            results.append((chat_id, profile_id))
        except Exception as e:
            errors.append(e)
    
    # Create multiple threads
    threads = []
    for i in range(10):
        t = threading.Thread(target=set_profile, args=(f"chat-{i}", f"profile-{i}"))
        threads.append(t)
        t.start()
    
    # Wait for all threads
    for t in threads:
        t.join()
    
    # Verify no errors
    assert len(errors) == 0, f"Errors occurred: {errors}"
    
    # Verify all profiles set
    assert len(results) == 10
    
    # Verify all profiles retrievable
    for i in range(10):
        record = store.get_profile(f"chat-{i}")
        assert record.profile_id == f"profile-{i}"


def test_invalid_data_handling(tmp_path):
    """Test handling of invalid/corrupted data."""
    store_path = tmp_path / "profiles.json"
    
    # Write invalid JSON
    store_path.write_text("{ invalid json }")
    
    # Store should handle gracefully
    store = ProfileStore(store_path)
    record = store.get_profile("chat-1")
    assert record.profile_id == DEFAULT_PROFILE.id


def test_missing_file_handling(tmp_path):
    """Test behavior when store file doesn't exist."""
    store_path = tmp_path / "nonexistent.json"
    
    # Should create file on first write
    store = ProfileStore(store_path)
    assert not store_path.exists()
    
    store.set_profile("chat-1", "kim_k2_poc")
    assert store_path.exists()
    
    record = store.get_profile("chat-1")
    assert record.profile_id == "kim_k2_poc"


def test_file_corruption_recovery(tmp_path):
    """Test recovery from corrupted file."""
    store_path = tmp_path / "profiles.json"
    
    # Create store and set profile
    store = ProfileStore(store_path)
    store.set_profile("chat-1", "kim_k2_poc")
    
    # Corrupt the file
    store_path.write_text("corrupted data")
    
    # Reload should handle gracefully
    store2 = ProfileStore(store_path)
    record = store2.get_profile("chat-1")
    assert record.profile_id == DEFAULT_PROFILE.id  # Falls back to default


def test_clear_expired_multiple(tmp_path):
    """Test clearing multiple expired profiles."""
    store = make_store(tmp_path, ttl_days=30)
    now = datetime(2024, 1, 1, tzinfo=timezone.utc)
    
    # Set multiple profiles
    for i in range(5):
        store.set_profile(f"chat-{i}", f"profile-{i}", now=now)
    
    # Expire all
    expired_time = now + timedelta(days=31)
    
    # Clear expired
    cleared = store.clear_expired(now=expired_time)
    assert cleared == 5
    
    # Verify all cleared
    for i in range(5):
        record = store.get_profile(f"chat-{i}", now=expired_time)
        assert record.profile_id == DEFAULT_PROFILE.id


def test_clear_expired_partial(tmp_path):
    """Test clearing only expired profiles."""
    store = make_store(tmp_path, ttl_days=30)
    now = datetime(2024, 1, 1, tzinfo=timezone.utc)
    
    # Set profiles at different times
    store.set_profile("chat-1", "profile-1", now=now)
    store.set_profile("chat-2", "profile-2", now=now + timedelta(days=15))
    
    # Check at 31 days (first expired, second not)
    check_time = now + timedelta(days=31)
    
    cleared = store.clear_expired(now=check_time)
    assert cleared == 1
    
    # Verify first expired, second still valid
    record1 = store.get_profile("chat-1", now=check_time)
    assert record1.profile_id == DEFAULT_PROFILE.id
    
    record2 = store.get_profile("chat-2", now=check_time)
    assert record2.profile_id == "profile-2"


def test_empty_profile_id_error(tmp_path):
    """Test error handling for empty profile ID."""
    store = make_store(tmp_path)
    
    # Should raise ValueError
    try:
        store.set_profile("chat-1", "")
        assert False, "Should have raised ValueError"
    except ValueError:
        pass  # Expected


def test_none_profile_id_error(tmp_path):
    """Test error handling for None profile ID."""
    store = make_store(tmp_path)
    
    # Should raise ValueError (via truthiness check)
    try:
        store.set_profile("chat-1", None)
        assert False, "Should have raised ValueError"
    except (ValueError, TypeError):
        pass  # Expected


def test_profile_record_serialization(tmp_path):
    """Test ProfileRecord serialization/deserialization."""
    now = datetime(2024, 1, 1, 12, 34, 56, tzinfo=timezone.utc)
    record = ProfileRecord(profile_id="kim_k2_poc", updated_at=now)
    
    # Serialize
    payload = record.to_payload()
    assert payload["profile"] == "kim_k2_poc"
    assert "updated_at" in payload
    
    # Deserialize
    restored = ProfileRecord.from_payload(payload)
    assert restored.profile_id == "kim_k2_poc"
    assert restored.updated_at == now


def test_profile_record_invalid_payload(tmp_path):
    """Test ProfileRecord with invalid payload."""
    # Missing fields
    assert ProfileRecord.from_payload({}) is None
    assert ProfileRecord.from_payload({"profile": "test"}) is None
    assert ProfileRecord.from_payload({"updated_at": "2024-01-01T00:00:00.000000Z"}) is None
    
    # Invalid timestamp format
    assert ProfileRecord.from_payload({
        "profile": "test",
        "updated_at": "invalid"
    }) is None
    
    # Invalid types
    assert ProfileRecord.from_payload({
        "profile": 123,  # Not a string
        "updated_at": "2024-01-01T00:00:00.000000Z"
    }) is None


def test_export_cache(tmp_path):
    """Test cache export functionality."""
    store = make_store(tmp_path)
    
    store.set_profile("chat-1", "profile-1")
    store.set_profile("chat-2", "profile-2")
    
    cache = store.export_cache()
    assert len(cache) == 2
    assert "chat-1" in cache
    assert "chat-2" in cache
    assert cache["chat-1"]["profile"] == "profile-1"
    assert cache["chat-2"]["profile"] == "profile-2"
