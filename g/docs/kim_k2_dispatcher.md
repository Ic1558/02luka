# Kim K2 Dispatcher — User Guide

**Version:** 1.0  
**Last Updated:** 2025-11-12

---

## Quick Start

### 1. Start the Dispatcher

```bash
# Via LaunchAgent (recommended)
launchctl load ~/Library/LaunchAgents/com.02luka.nlp-dispatcher.plist

# Or manually
cd ~/02luka/core/nlp
./start_dispatcher.sh
```

### 2. Verify It's Running

```bash
~/02luka/tools/kim_health_check.zsh
```

Expected output:
```
✅ Redis reachable (PONG)
✅ Dispatcher running
✅ Profile store present at ~/02luka/core/nlp/kim_session_profiles.json
✅ LaunchAgent installed
```

### 3. Test Commands

Send a test message via Telegram:
```
/use kim_k2_poc
```

Or use the CLI:
```bash
python3 ~/02luka/tools/kim_nlp_publish.py "test message"
```

---

## Command Reference

### `/use <profile_id>`

Sets a persistent profile for the current chat. The selection persists for 30 days.

**Examples:**

```
/use kim_k2_poc    # Switch to K2 profile
/use default       # Reset to default profile
```

**Behavior:**
- Profile selection is stored per chat ID
- Automatically expires after 30 days
- All subsequent messages use the selected profile
- Event `kim.dispatch.profile_set` is emitted

**Response:**
```json
{
  "ok": true,
  "action": "profile_update",
  "profile": "kim_k2_poc",
  "message": "Profile set to Kim K2"
}
```

**Error Cases:**
- Unknown profile: Returns error with available profiles
- Missing profile ID: Returns error with usage hint

---

### `/k2 <question>`

Sends a one-off question through the K2 profile without changing the persistent selection.

**Example:**
```
/k2 What is quantum computing?
```

**Behavior:**
- Uses K2 profile for this message only
- Does not change persistent profile
- Useful for evaluation before committing
- Event `kim.dispatch.sent` is emitted with `one_off: true`

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

**Error Cases:**
- K2 profile not configured: Returns error
- Missing question: Returns error with usage hint

---

## Profile Management

### Available Profiles

List available profiles:
```bash
ls ~/02luka/config/kim_agent_profiles/*.yaml
```

Default profiles:
- `default` - Baseline Kim profile (legacy routing)
- `kim_k2_poc` - K2 Thinking model via OpenRouter

### Profile Selection Flow

1. **User sends `/use kim_k2_poc`**
   - Dispatcher parses command
   - Validates profile exists
   - Stores selection in profile store
   - Emits `kim.dispatch.profile_set` event

2. **User sends regular message**
   - Dispatcher looks up profile for chat
   - Uses stored profile (or default if none/expired)
   - Dispatches message to `kim:requests` channel
   - Emits `kim.dispatch.sent` event

3. **Profile expires (30 days)**
   - On next access, profile is cleared
   - Falls back to default profile
   - No error, seamless transition

### Checking Current Profile

View profile store:
```bash
cat ~/02luka/core/nlp/kim_session_profiles.json
```

Example:
```json
{
  "123456": {
    "profile": "kim_k2_poc",
    "updated_at": "2025-11-12T04:00:00.000000Z"
  }
}
```

---

## Examples

### Example 1: Switch to K2 Profile

```
User: /use kim_k2_poc
Bot: Profile set to Kim K2

User: Explain vector databases
Bot: [Response via K2 profile]
```

### Example 2: One-Off K2 Query

```
User: /k2 What is machine learning?
Bot: [Response via K2 profile, one-off]

User: Regular question
Bot: [Response via default profile - not changed]
```

### Example 3: Reset to Default

```
User: /use default
Bot: Profile reset to Kim Default

User: Regular question
Bot: [Response via default profile]
```

### Example 4: A/B Testing

```bash
# Test both profiles side-by-side
~/02luka/tools/kim_ab_test.zsh "Explain quantum computing"
```

Output:
```
Default: [Response from default profile]
K2: [Response from K2 profile]
```

---

## Best Practices

### 1. Profile Selection

- **Use `/use` for persistent selection:** When you want all messages to use a profile
- **Use `/k2` for evaluation:** When testing before committing
- **Reset when done:** Use `/use default` to return to baseline

### 2. Profile Expiration

- Profiles expire after 30 days
- Re-run `/use` command to refresh
- No action needed for expiration (automatic fallback)

### 3. Error Handling

- Check health before use: `~/02luka/tools/kim_health_check.zsh`
- Monitor logs: `tail -f ~/02luka/logs/nlp_dispatcher.log`
- Verify Redis: `redis-cli PING`

### 4. Testing

- Use A/B test tool for comparison
- Test with CLI before Telegram
- Monitor events channel for debugging

---

## Common Issues

### Issue: Profile Not Persisting

**Symptoms:**
- Profile resets after restart
- Profile not found on next message

**Solutions:**
1. Check file permissions:
   ```bash
   ls -la ~/02luka/core/nlp/kim_session_profiles.json
   ```

2. Verify TTL hasn't expired (30 days)

3. Re-run `/use` command

### Issue: Dispatcher Not Responding

**Symptoms:**
- Commands not processed
- No events emitted

**Solutions:**
1. Check if dispatcher is running:
   ```bash
   pgrep -f nlp_command_dispatcher.py
   ```

2. Check LaunchAgent:
   ```bash
   launchctl list | grep nlp-dispatcher
   ```

3. Check logs:
   ```bash
   tail -f ~/02luka/logs/nlp_dispatcher.log
   ```

### Issue: Unknown Profile Error

**Symptoms:**
- Error: "unknown profile: X"
- Available profiles list shown

**Solutions:**
1. Verify profile YAML exists:
   ```bash
   ls ~/02luka/config/kim_agent_profiles/*.yaml
   ```

2. Check profile ID matches YAML `id` field

3. Restart dispatcher to reload profiles

### Issue: Redis Connection Failed

**Symptoms:**
- Dispatcher can't connect
- Messages not received

**Solutions:**
1. Check Redis is running:
   ```bash
   redis-cli PING
   ```

2. Verify credentials:
   ```bash
   echo $REDIS_PASSWORD
   ```

3. Check network:
   ```bash
   redis-cli -h 127.0.0.1 -p 6379 PING
   ```

---

## Monitoring

### Events Channel

Monitor dispatcher events:
```bash
redis-cli SUBSCRIBE kim:dispatcher:events
```

**Event Types:**
- `kim.dispatch.sent` - Message dispatched
- `kim.dispatch.profile_set` - Profile selected
- `kim.dispatch.profile_reset` - Profile reset

**Example Event:**
```json
{
  "ts": "2025-11-12T04:00:00.000000Z",
  "event": "kim.dispatch.sent",
  "chat_id": "123456",
  "profile": "kim_k2_poc",
  "provider": "k2_thinking",
  "one_off": false
}
```

### Logs

**Dispatcher Log:**
```bash
tail -f ~/02luka/logs/nlp_dispatcher.log
```

**Error Log:**
```bash
tail -f ~/02luka/logs/nlp_dispatcher.err.log
```

**LaunchAgent Log:**
```bash
tail -f ~/02luka/logs/nlp_dispatcher.out.log
```

---

## Advanced Usage

### Force Profile via Payload

For programmatic access, include `force_profile` in payload:

```python
payload = {
    "text": "Hello from CLI",
    "chat": {"id": "cli-1"},
    "force_profile": "kim_k2_poc"
}
```

This bypasses profile store and uses specified profile for one message.

### Custom Profile Configuration

Create custom profile in `config/kim_agent_profiles/custom.yaml`:

```yaml
id: custom_profile
name: Custom Profile
description: My custom profile
provider: custom_provider
channel: kim:requests
metadata:
  custom_key: custom_value
```

Restart dispatcher to load new profile.

---

## See Also

- `core/nlp/README.md` - Technical documentation
- `QUICKSTART_KIM_K2.md` - Quick start guide
- `reports/system/kim_k2_finalize_README.md` - Deployment notes
- `tools/kim_health_check.zsh` - Health check script

---

**End of User Guide**
