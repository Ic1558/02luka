# Kim K2 NLP Command Dispatcher

**Version:** 1.0  
**Status:** Production  
**Last Updated:** 2025-11-12

---

## Overview

The Kim K2 NLP Command Dispatcher is a Redis-backed message router that enables selectable runtime profiles for the Kim Telegram bot. It listens on `gg:nlp`, parses chat commands (`/use`, `/k2`), and publishes enriched requests to `kim:requests` for downstream processing.

### Key Features

- **Profile Selection:** Per-chat profile persistence with 30-day TTL
- **Command Parsing:** `/use` and `/k2` command support
- **Event Emission:** Telemetry events on `kim:dispatcher:events`
- **Redis Integration:** Pub/sub messaging via Redis
- **Thread-Safe:** Profile store with locking for concurrent access

---

## Architecture

```
Telegram Bot → Redis (gg:nlp) → Dispatcher → Redis (kim:requests) → Kim Agent
                                      ↓
                              Profile Store (JSON)
                                      ↓
                              Events (kim:dispatcher:events)
```

### Components

1. **CommandDispatcher** (`nlp_command_dispatcher.py`)
   - Main dispatcher class
   - Handles message routing and profile selection
   - Emits telemetry events

2. **ProfileStore** (`profile_store.py`)
   - Persistent chat profile preferences
   - 30-day TTL for automatic expiration
   - Thread-safe with RLock

3. **Profile Loading** (`load_profiles()`)
   - Loads profiles from YAML files
   - Supports multiple profile definitions
   - Default profile fallback

---

## Setup

### Prerequisites

- Python 3.8+
- Redis server running
- Telegram bot configured
- Profile YAML files in `config/kim_agent_profiles/`

### Installation

1. **Ensure dependencies:**
   ```bash
   pip install redis pyyaml
   ```

2. **Configure Redis:**
   ```bash
   export REDIS_HOST=127.0.0.1
   export REDIS_PORT=6379
   export REDIS_PASSWORD=your_password  # if required
   ```

3. **Set profile directory:**
   ```bash
   export KIM_PROFILE_DIR=~/02luka/config/kim_agent_profiles
   ```

4. **Set profile store path:**
   ```bash
   export KIM_PROFILE_STORE=~/02luka/core/nlp/kim_session_profiles.json
   ```

### LaunchAgent Setup

1. **Copy LaunchAgent:**
   ```bash
   cp LaunchAgents/com.02luka.nlp-dispatcher.plist ~/Library/LaunchAgents/
   ```

2. **Load LaunchAgent:**
   ```bash
   launchctl load ~/Library/LaunchAgents/com.02luka.nlp-dispatcher.plist
   ```

3. **Verify:**
   ```bash
   launchctl list | grep nlp-dispatcher
   tail -f ~/02luka/logs/nlp_dispatcher.log
   ```

---

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `REDIS_HOST` | `127.0.0.1` | Redis server host |
| `REDIS_PORT` | `6379` | Redis server port |
| `REDIS_PASSWORD` | `None` | Redis password (if required) |
| `REDIS_CHANNEL_IN` | `gg:nlp` | Input channel to subscribe |
| `KIM_PROFILE_DIR` | `~/02luka/config/kim_agent_profiles` | Profile YAML directory |
| `KIM_PROFILE_STORE` | `~/02luka/core/nlp/kim_session_profiles.json` | Profile store file |
| `KIM_DISPATCH_EVENTS_CHANNEL` | `kim:dispatcher:events` | Events channel |
| `KIM_K2_PROFILE_ID` | `kim_k2_poc` | K2 profile identifier |
| `KIM_DISPATCH_LOG_LEVEL` | `INFO` | Logging level |

### Profile YAML Format

Create profile files in `config/kim_agent_profiles/*.yaml`:

```yaml
id: kim_k2_poc
name: Kim K2 POC
description: K2 Thinking model via OpenRouter
provider: k2_thinking
channel: kim:requests
metadata:
  request_mode: k2
  model: openrouter/kimi-k2-thinking
```

---

## API Reference

### CommandDispatcher

#### `CommandDispatcher.__init__()`

```python
CommandDispatcher(
    profile_store: ProfileStore,
    profiles: Optional[Dict[str, Profile]] = None,
    *,
    publisher: Optional[Callable[[str, Dict[str, object]], None]] = None,
    events_channel: str = "kim:dispatcher:events",
    default_profile_id: str = "default",
    k2_profile_id: str = "kim_k2_poc",
)
```

**Parameters:**
- `profile_store`: ProfileStore instance for persistence
- `profiles`: Dictionary of profile_id → Profile
- `publisher`: Function to publish messages (default: no-op)
- `events_channel`: Redis channel for telemetry events
- `default_profile_id`: Default profile when none selected
- `k2_profile_id`: Profile ID for `/k2` command

#### `CommandDispatcher.handle_payload(payload: Dict[str, object]) -> Dict[str, object]`

Processes a message payload and returns dispatch result.

**Input Payload:**
```python
{
    "text": "/use kim_k2_poc",  # or "/k2 question" or regular message
    "chat": {"id": "123456"},
    "from": {"username": "user"},
    "message_id": 789,
    "source": "telegram"
}
```

**Return Value:**
```python
{
    "ok": True,
    "action": "profile_update",  # or "dispatch"
    "profile": "kim_k2_poc",
    "message": "Profile set to Kim K2"
}
```

#### `CommandDispatcher.run(redis_client: Redis, channel: Optional[str] = None) -> None`

Starts the dispatcher loop, subscribing to Redis channel and processing messages.

---

### ProfileStore

#### `ProfileStore.__init__()`

```python
ProfileStore(
    store_path: Path | str,
    *,
    default_profile: str = "default",
    ttl_days: int = 30,
)
```

**Parameters:**
- `store_path`: Path to JSON store file
- `default_profile`: Default profile ID
- `ttl_days`: Time-to-live in days (default: 30)

#### `ProfileStore.set_profile(chat_id: str | int, profile_id: str) -> None`

Persists profile selection for a chat.

#### `ProfileStore.get_profile(chat_id: str | int) -> ProfileRecord`

Returns profile record for chat (default if missing/expired).

#### `ProfileStore.clear_profile(chat_id: str | int) -> None`

Removes profile selection for a chat.

#### `ProfileStore.clear_expired() -> int`

Removes all expired profiles, returns count cleared.

---

## Commands

### `/use <profile_id>`

Sets persistent profile for current chat (30-day TTL).

**Examples:**
```
/use kim_k2_poc    # Switch to K2 profile
/use default       # Reset to default profile
```

**Response:**
```json
{
  "ok": true,
  "action": "profile_update",
  "profile": "kim_k2_poc",
  "message": "Profile set to Kim K2"
}
```

### `/k2 <question>`

Sends one-off question through K2 profile without changing persistence.

**Example:**
```
/k2 What is quantum computing?
```

**Response:**
```json
{
  "ok": true,
  "action": "dispatch",
  "profile": "kim_k2_poc",
  "provider": "k2_thinking",
  "one_off": true
}
```

---

## Usage Examples

### Basic Usage

```python
from core.nlp.nlp_command_dispatcher import CommandDispatcher, create_redis_publisher
from core.nlp.profile_store import ProfileStore
from redis import Redis

# Setup
redis_client = Redis(host="127.0.0.1", port=6379, decode_responses=True)
store = ProfileStore("~/02luka/core/nlp/kim_session_profiles.json")
profiles = load_profiles(Path("~/02luka/config/kim_agent_profiles"))

# Create dispatcher
dispatcher = CommandDispatcher(
    profile_store=store,
    profiles=profiles,
    publisher=create_redis_publisher(redis_client),
)

# Handle message
result = dispatcher.handle_payload({
    "text": "/use kim_k2_poc",
    "chat": {"id": "123456"},
    "from": {"username": "user"}
})
print(result)  # {"ok": True, "action": "profile_update", ...}
```

### Running as Service

```bash
# Start dispatcher
cd ~/02luka/core/nlp
./start_dispatcher.sh

# Or via LaunchAgent
launchctl load ~/Library/LaunchAgents/com.02luka.nlp-dispatcher.plist
```

---

## Troubleshooting

### Dispatcher Not Receiving Messages

1. **Check Redis connection:**
   ```bash
   redis-cli -h 127.0.0.1 -p 6379 PING
   ```

2. **Verify subscription:**
   ```bash
   redis-cli -h 127.0.0.1 -p 6379 PUBSUB CHANNELS
   # Should show: gg:nlp
   ```

3. **Check logs:**
   ```bash
   tail -f ~/02luka/logs/nlp_dispatcher.log
   ```

### Profile Not Persisting

1. **Check file permissions:**
   ```bash
   ls -la ~/02luka/core/nlp/kim_session_profiles.json
   ```

2. **Verify TTL:**
   - Profiles expire after 30 days
   - Use `/use` command again to refresh

3. **Check store file:**
   ```bash
   cat ~/02luka/core/nlp/kim_session_profiles.json
   ```

### Profile Not Found

1. **Verify profile YAML exists:**
   ```bash
   ls -la ~/02luka/config/kim_agent_profiles/*.yaml
   ```

2. **Check profile ID:**
   - Must match YAML `id` field
   - Case-sensitive

3. **Check logs for load errors:**
   ```bash
   grep "Failed to load profile" ~/02luka/logs/nlp_dispatcher.log
   ```

---

## Testing

### Run Tests

```bash
# Unit tests
pytest tests/test_kim_profile_router.py -v

# Integration tests
pytest tests/integration/test_kim_k2_flow.py -v
```

### Manual Testing

```bash
# Health check
~/02luka/tools/kim_health_check.zsh

# A/B test
~/02luka/tools/kim_ab_test.zsh "Test question"

# Publish test message
python3 ~/02luka/tools/kim_nlp_publish.py "test message"
```

---

## Monitoring

### Events Channel

Monitor dispatcher events:
```bash
redis-cli -h 127.0.0.1 -p 6379 SUBSCRIBE kim:dispatcher:events
```

**Event Types:**
- `kim.dispatch.sent` - Message dispatched
- `kim.dispatch.profile_set` - Profile selected
- `kim.dispatch.profile_reset` - Profile reset to default

### Logs

- **Dispatcher:** `~/02luka/logs/nlp_dispatcher.log`
- **Errors:** `~/02luka/logs/nlp_dispatcher.err.log`
- **LaunchAgent:** `~/02luka/logs/nlp_dispatcher.out.log`

---

## Security Considerations

1. **Redis Password:** Always use password in production
2. **File Permissions:** Profile store should be readable/writable by dispatcher only
3. **Input Validation:** All user input is validated before processing
4. **Error Handling:** Exceptions are logged, not exposed to users

---

## Performance

- **Message Throughput:** ~1000 messages/second (Redis-limited)
- **Profile Lookup:** O(1) with in-memory cache
- **TTL Cleanup:** Lazy (on access) + explicit `clear_expired()`
- **Memory Usage:** ~1KB per active chat profile

---

## See Also

- `docs/kim_k2_dispatcher.md` - User guide
- `QUICKSTART_KIM_K2.md` - Quick start
- `reports/system/kim_k2_finalize_README.md` - Deployment notes
- `tools/kim_health_check.zsh` - Health check script

---

**End of README**
