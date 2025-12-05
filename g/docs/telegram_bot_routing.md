# Telegram Bot Routing Matrix

**Last Updated**: 2025-12-05  
**Status**: Active

---

## Overview

This document defines the routing matrix for all Telegram bots in the 02luka system, including the unified **SYSTEM_ALERTS_BOT** that consolidates guard and error alerts.

---

## Bot Roles & Destinations

| Bot | Token Variable | Chat ID | Destination | Purpose | Alert Level |
|-----|---------------|---------|-------------|---------|-------------|
| **SYSTEM_ALERTS_BOT** | `TELEGRAM_SYSTEM_ALERT_BOT_TOKEN` | `6351780525` | Boss Private | System health, errors, guard alerts | Critical/Error/Guard |
| **EDGEWORK Bot** | `TELEGRAM_BOT_TOKEN_EDGEWORK` | `-1002727852946` | @Edge.Work (group) | Company work, progress reports | Info (non-sensitive) |
| **KIM Bot** | `TELEGRAM_BOT_TOKEN_KIM` | `-1002433798273` | @IC_Notify (group) | Team interaction, file sharing | Interactive |
| **TRADER Bot** | `TELEGRAM_BOT_TOKEN_TRADER` | `6351780525` | Boss Private | Trading signals | Trading-specific |
| **GGMESH** | `TELEGRAM_BOT_TOKEN_GGMESH` | `6351780525` | Boss Private | Internal dev | Dev-specific |

---

## Alert Routing Rules

### → SYSTEM_ALERTS_BOT (Boss Private: 6351780525)

**Send to SYSTEM_ALERTS_BOT for:**
- ✅ Guard health failures (`luka-guard` suite failures)
- ✅ Infrastructure failures (Redis unhealthy, tunnels down, reverse proxy errors)
- ✅ Agent/orchestrator crashes
- ✅ Error-level exceptions
- ✅ Fatal logs
- ✅ Any alert requiring immediate Boss attention
- ✅ System-level security issues

**Usage:**
```bash
"$HOME/02luka/g/tools/system_alert_send.zsh" \
  "GUARD" \
  "luka-guard" \
  "Guard health check FAILED: suite_version=${VERSION}, log=${LOG_PATH}"
```

**Alert Levels:**
- `GUARD` - Guard suite failures
- `ERROR` - System errors, exceptions
- `INFRA` - Infrastructure failures (Redis, tunnels, etc.)
- `WARN` - Warning-level issues
- `CRITICAL` - Critical system failures

### → EDGEWORK Bot (@Edge.Work: -1002727852946)

**Send to EDGEWORK Bot for:**
- ✅ Work progress reports
- ✅ Site photos
- ✅ Non-sensitive status updates
- ✅ Project milestones
- ❌ **NO system errors**
- ❌ **NO infrastructure details**
- ❌ **NO guard alerts**

### → KIM Bot (@IC_Notify: -1002433798273)

**Send to KIM Bot for:**
- ✅ Team interaction
- ✅ File sharing
- ✅ Interactive commands
- ✅ General team communication

### → TRADER Bot (Boss Private: 6351780525)

**Send to TRADER Bot for:**
- ✅ Trading signals
- ✅ Market alerts
- ✅ Trading-specific notifications

---

## Migration Notes

### Deprecated Variables

The following variables are **DEPRECATED** and should not be used in new code:

- `TELEGRAM_GUARD_BOT_TOKEN` → Use `TELEGRAM_SYSTEM_ALERT_BOT_TOKEN`
- `TELEGRAM_BOT_TOKEN_GPT_ALERTS` → Use `TELEGRAM_SYSTEM_ALERT_BOT_TOKEN`

**Backward Compatibility:**
- The `system_alert_send.zsh` helper includes fallback logic for deprecated variables
- Old scripts will continue to work during migration period
- New code must use `TELEGRAM_SYSTEM_ALERT_BOT_TOKEN`

---

## Implementation

### Unified Alert Sender

All system alerts should use the unified helper:

```bash
#!/usr/bin/env zsh
# File: g/tools/system_alert_send.zsh

# Usage:
system_alert_send.zsh LEVEL SOURCE "message text"

# Examples:
system_alert_send.zsh GUARD luka-guard "Guard suite failed"
system_alert_send.zsh ERROR redis-health "Redis connection lost"
system_alert_send.zsh INFRA ops-tunnel "Cloudflare tunnel down"
```

### Environment Variables

Required in `.env.local`:
```bash
# System Alert Bot (unified)
TELEGRAM_SYSTEM_ALERT_BOT_TOKEN="<token>"
TELEGRAM_SYSTEM_ALERT_CHAT_ID="6351780525"
```

---

## Security Considerations

1. **System Information Isolation**: All system/infra/error alerts are sent exclusively to Boss private chat
2. **No Team Exposure**: Team channels (`@Edge.Work`, `@IC_Notify`) do not receive sensitive system information
3. **Private Logs**: System alerts are traceable only in Boss's private chat

---

## Examples

### Guard Health Alert
```bash
if [[ "$HEALTHY" != "true" ]]; then
  "$HOME/02luka/g/tools/system_alert_send.zsh" \
    "GUARD" \
    "luka-guard" \
    "Guard health check FAILED: suite_version=${GUARD_SUITE_VERSION}, log=${LOG_PATH}"
fi
```

### Infrastructure Alert
```bash
"$HOME/02luka/g/tools/system_alert_send.zsh" \
  "INFRA" \
  "redis-health" \
  "Redis health check FAILED: ${DETAILS}"
```

### Error Alert
```bash
"$HOME/02luka/g/tools/system_alert_send.zsh" \
  "ERROR" \
  "orchestrator" \
  "Orchestrator crash detected: ${ERROR_MESSAGE}"
```

---

## Routing Decision Tree

```
Is it a system/infra/error/guard alert?
├─ YES → SYSTEM_ALERTS_BOT (Boss private)
│
└─ NO → Is it company work/progress?
    ├─ YES → EDGEWORK Bot (@Edge.Work)
    │
    └─ NO → Is it team interaction?
        ├─ YES → KIM Bot (@IC_Notify)
        │
        └─ NO → Is it trading-related?
            ├─ YES → TRADER Bot (Boss private)
            │
            └─ NO → Determine appropriate bot
```

---

**Note**: This routing matrix is enforced system-wide. All new alert implementations must follow these rules.
