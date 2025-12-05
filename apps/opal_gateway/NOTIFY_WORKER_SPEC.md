# Notification Worker Specification

> **⚠️ IMPORTANT NOTE FOR CLC/CLS:**
> 
> **Canonical behavior is defined in:**
> - `g/reports/feature_notification_system_v1_complete_PLAN.md` (main spec)
> - `g/reports/notification_v1_delta_spec.md` (delta updates)
> - `g/reports/notification_v1_final_polish.md` (final polish checklist)
> 
> **This file contains example structures only.**
> 
> When implementing the worker, refer to the canonical specs above for:
> - Startup guard requirements
> - Stale notification guard (24h threshold)
> - Metrics JSONL format
> - Per-chat token strategy
> - Retry logic
> - Fallback logic
> 
> This spec serves as a skeleton/reference structure that must be updated to match canonical behavior.

---

## Overview

The **Notification Worker** processes notification requests queued by the Opal Gateway and delivers them via Telegram and/or LINE.

---

## Architecture

```
Opal App/Gateway
    ↓ POST /api/notify
Gateway queues to bridge/inbox/NOTIFY/*.json
    ↓ File watcher
Notification Worker
    ↓ Delivery
Telegram Bot / LINE Notify API
```

---

## Input: Notification Queue Files

**Location:** `bridge/inbox/NOTIFY/`

**File naming:** `{wo_id}_notify.json`

**Schema:**

```json
{
  "wo_id": "WO-20251205-EXP-0001",
  "telegram": {
    "chat": "boss_private",
    "text": "02luka: WO 20251205-EXP-0001 [expense/high] - COMPLETED\nObjective: Log site expense for PD17 scaffolding\n\nAmount: ฿12,450\nProject: PD17",
    "meta": {
      "wo_id": "WO-20251205-EXP-0001",
      "lane": "dev_oss",
      "status": "COMPLETED",
      "app_mode": "expense"
    }
  },
  "line": {
    "room": "default",
    "text": "02luka Alert\nWO: 20251205-EXP-0001\nCompleted",
    "meta": {
      "wo_id": "WO-20251205-EXP-0001"
    }
  }
}
```

**Notes:**
- `telegram` and `line` are optional (at least one must be present)
- `text` is pre-formatted by Opal (no need to generate)
- `meta` contains context for logging/tracking

---

## Worker Implementation

### Option 1: Shell Script (Lightweight)

**File:** `tools/notify_worker.zsh`

```bash
#!/usr/bin/env zsh
# Notification Worker - Process queued notifications

INBOX_DIR="$HOME/02luka/bridge/inbox/NOTIFY"
PROCESSED_DIR="$HOME/02luka/bridge/processed/NOTIFY"
TELEGRAM_SCRIPT="$HOME/02luka/g/tools/system_alert_send.zsh"

mkdir -p "$PROCESSED_DIR"

for file in "$INBOX_DIR"/*.json; do
    [[ -f "$file" ]] || continue
    
    WO_ID=$(jq -r '.wo_id' "$file")
    echo "[NOTIFY] Processing: $WO_ID"
    
    # Send Telegram if enabled
    if jq -e '.telegram' "$file" >/dev/null 2>&1; then
        CHAT=$(jq -r '.telegram.chat // "boss_private"' "$file")
        TEXT=$(jq -r '.telegram.text' "$file")
        
        echo "  → Sending to Telegram: $CHAT"
        "$TELEGRAM_SCRIPT" "NOTIFY" "$WO_ID" "$TEXT"
    fi
    
    # Send LINE if enabled
    if jq -e '.line' "$file" >/dev/null 2>&1; then
        ROOM=$(jq -r '.line.room // "default"' "$file")
        TEXT=$(jq -r '.line.text' "$file")
        
        echo "  → Sending to LINE: $ROOM"
        # TODO: Call LINE notify script
        # "$LINE_SCRIPT" "$ROOM" "$TEXT"
    fi
    
    # Move to processed
    mv "$file" "$PROCESSED_DIR/"
    echo "  ✅ Processed: $WO_ID"
done
```

**Run as cron or launchd:**
```bash
# Every minute
* * * * * ~/02luka/tools/notify_worker.zsh
```

---

### Option 2: Python Worker (LAC Agent)

**File:** `agents/notify/notify_worker.py`

```python
#!/usr/bin/env python3
"""
Notification Worker - LAC Agent
Processes notification queue and delivers via Telegram/LINE
"""

import os
import json
import subprocess
from pathlib import Path
from datetime import datetime, timezone

LUKA_HOME = Path.home() / "02luka"
INBOX_DIR = LUKA_HOME / "bridge" / "inbox" / "NOTIFY"
PROCESSED_DIR = LUKA_HOME / "bridge" / "processed" / "NOTIFY"
TELEGRAM_SCRIPT = LUKA_HOME / "g" / "tools" / "system_alert_send.zsh"

PROCESSED_DIR.mkdir(parents=True, exist_ok=True)

def send_telegram(chat, text):
    """Send telegram notification using existing script"""
    try:
        subprocess.run(
            [str(TELEGRAM_SCRIPT), "NOTIFY", "notification", text],
            check=True,
            capture_output=True
        )
        return True
    except Exception as e:
        print(f"❌ Telegram send failed: {e}")
        return False

def send_line(room, text):
    """Send LINE notification (placeholder)"""
    # TODO: Implement LINE notify integration
    print(f"⚠️  LINE notify not yet implemented (room: {room})")
    return False

def process_notification(file_path):
    """Process a single notification file"""
    try:
        data = json.loads(file_path.read_text())
        wo_id = data.get("wo_id", "UNKNOWN")
        
        print(f"[NOTIFY] Processing: {wo_id}")
        
        # Send Telegram
        if data.get("telegram"):
            tg = data["telegram"]
            chat = tg.get("chat", "boss_private")
            text = tg.get("text", "No message")
            
            print(f"  → Sending to Telegram: {chat}")
            send_telegram(chat, text)
        
        # Send LINE
        if data.get("line"):
            line = data["line"]
            room = line.get("room", "default")
            text = line.get("text", "No message")
            
            print(f"  → Sending to LINE: {room}")
            send_line(room, text)
        
        # Move to processed
        processed_file = PROCESSED_DIR / file_path.name
        file_path.rename(processed_file)
        print(f"  ✅ Processed: {wo_id}")
        
    except Exception as e:
        print(f"❌ Error processing {file_path.name}: {e}")

def main():
    """Main worker loop"""
    print(f"🔔 Notification Worker - Checking {INBOX_DIR}")
    
    queue_files = list(INBOX_DIR.glob("*.json"))
    if not queue_files:
        print("  (No notifications in queue)")
        return
    
    for file_path in queue_files:
        process_notification(file_path)
    
    print(f"✅ Processed {len(queue_files)} notification(s)")

if __name__ == "__main__":
    main()
```

**Run via launchd:**

Create `~/Library/LaunchAgents/com.02luka.notify-worker.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.02luka.notify-worker</string>
    
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/python3</string>
        <string>/Users/icmini/02luka/agents/notify/notify_worker.py</string>
    </array>
    
    <key>StartInterval</key>
    <integer>60</integer>
    
    <key>RunAtLoad</key>
    <true/>
    
    <key>StandardOutPath</key>
    <string>/Users/icmini/02luka/logs/notify_worker.log</string>
    
    <key>StandardErrorPath</key>
    <string>/Users/icmini/02luka/logs/notify_worker.err</string>
</dict>
</plist>
```

---

## Integration with Existing Tools

### Telegram

**Existing Script:** `g/tools/system_alert_send.zsh`

**Usage:**
```bash
system_alert_send.zsh "NOTIFY" "wo_id" "message_text"
```

**Requirements:**
- `TELEGRAM_SYSTEM_ALERT_BOT_TOKEN` in environment
- `TELEGRAM_SYSTEM_ALERT_CHAT_ID` for boss_private channel (verified in .env.local)

### LINE Notify

**To Implement:** `g/tools/line_notify.zsh`

```bash
#!/usr/bin/env zsh
# LINE Notify sender

ROOM=$1
MESSAGE=$2

case "$ROOM" in
    "boss_private")
        TOKEN="$LINE_NOTIFY_TOKEN_PRIVATE"
        ;;
    *)
        TOKEN="$LINE_NOTIFY_TOKEN_DEFAULT"
        ;;
esac

curl -X POST https://notify-api.line.me/api/notify \
    -H "Authorization: Bearer $TOKEN" \
    -d "message=$MESSAGE"
```

---

## State Tracking (AP/IO v3.1)

After delivering notification, log to AP/IO ledger:

```json
{
  "timestamp": "2025-12-05T06:45:12Z",
  "agent": "notify_worker",
  "event": "notification_delivered",
  "wo_id": "WO-20251205-EXP-0001",
  "channels": ["telegram"],
  "status": "success"
}
```

---

## Error Handling

**Retry Logic:**
- Failed notifications: Don't delete, rename to `.failed`
- Retry after 5 minutes (optional)
- Alert admin if 3 consecutive failures

**Example:**
```bash
# On failure
mv "$file" "${file%.json}.failed"
```

---

## Testing

```bash
# Create test notification
cat > ~/02luka/bridge/inbox/NOTIFY/WO-TEST-NOTIFY.json <<EOF
{
  "wo_id": "WO-TEST-NOTIFY",
  "telegram": {
    "chat": "boss_private",
    "text": "🧪 Test notification from worker"
  }
}
EOF

# Run worker manually
python agents/notify/notify_worker.py

# Check processed
ls -la ~/02luka/bridge/processed/NOTIFY/
```

---

## Deployment Checklist

- [ ] Create `bridge/inbox/NOTIFY/` directory
- [ ] Create `bridge/processed/NOTIFY/` directory
- [ ] Install notification worker (shell or Python)
- [ ] Configure Telegram tokens in environment
- [ ] Set up LINE Notify tokens (if using)
- [ ] Deploy as launchd service or cron job
- [ ] Test end-to-end: Gateway → Worker → Telegram
- [ ] Monitor logs for delivery failures

---

**Version:** 1.0  
**Compatible with:** Opal Gateway v1.1+  
**Status:** Spec Ready - Implementation Pending
