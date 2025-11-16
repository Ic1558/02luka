# Follow-Up Tracker - Symlink Access Map

**Deployed:** 2025-11-06
**Status:** ✅ ALL SYMLINKS VERIFIED

## Visual Symlink Structure

```
📂 ~/02luka/
│
├── 📄 followup.json  ──────────────────┐
│   (fastest access)                    │
│                                        │
├── 📂 g/                                │
│   ├── 📂 knowledge/                   │
│   │   └── 📄 followup_index.json ◄───┼─── PRIMARY SOURCE (auto-updated)
│   │                                    │
│   ├── 📂 apps/dashboard/              │
│   │   └── 📂 data/                    │
│   │       └── 📄 followup.json  ──────┤
│   │          (dashboard reads here)   │
│   │                                    │
│   └── 📂 run/                          │
│       └── 📄 followup_index.json  ────┤
│          (runtime access)              │
│                                        │
└── 📂 tools/                            │
    └── 📂 data/                         │
        └── 📄 followup.json  ───────────┘
           (tools read here)

ALL ARROWS POINT TO: ~/02luka/g/knowledge/followup_index.json
```

## Access Patterns by Use Case

### 1. Quick CLI Access (Human)
```bash
# Fastest - just 2 keystrokes after ~
cat ~/02luka/followup.json | jq .
```

### 2. Dashboard Integration
```python
# Dashboard code at ~/02luka/g/apps/dashboard/
import json
with open('data/followup.json') as f:
    data = json.load(f)
```

### 3. Tool Scripts
```bash
# From ~/02luka/tools/*.zsh
jq '.active_items' tools/data/followup.json
```

### 4. Runtime Monitoring
```bash
# System monitoring scripts
watch -n 5 'jq .metadata ~/02luka/g/run/followup_index.json'
```

## Verification Test

```bash
# All these commands should return the SAME timestamp
echo "Root level:"
cat ~/02luka/followup.json | jq -r '.metadata.last_updated'

echo "Dashboard:"
cat ~/02luka/g/apps/dashboard/data/followup.json | jq -r '.metadata.last_updated'

echo "Tools:"
cat ~/02luka/tools/data/followup.json | jq -r '.metadata.last_updated'

echo "Runtime:"
cat ~/02luka/g/run/followup_index.json | jq -r '.metadata.last_updated'

echo "Primary:"
cat ~/02luka/g/knowledge/followup_index.json | jq -r '.metadata.last_updated'
```

**Expected:** All 5 commands show identical timestamp ✅

## LaunchAgent Update Flow

```
Every 5 minutes:
  ┌─────────────────────────────────────────────┐
  │ LaunchAgent: com.02luka.followup_tracker    │
  │ PID: 57407                                  │
  └────────────┬────────────────────────────────┘
               │
               ▼
  ┌─────────────────────────────────────────────┐
  │ Script: followup_tracker_update.zsh         │
  │ - Check Dashboard API (port 8770)           │
  │ - Validate MLS JSONL format                 │
  │ - Count RAG mls:// entries                  │
  │ - Count GitHub PRs                          │
  └────────────┬────────────────────────────────┘
               │
               ▼
  ┌─────────────────────────────────────────────┐
  │ WRITE TO PRIMARY SOURCE:                    │
  │ ~/02luka/g/knowledge/followup_index.json    │
  └────────────┬────────────────────────────────┘
               │
               ▼ (symlinks automatically reflect changes)
  ┌─────────────────────────────────────────────┐
  │ ALL SYMLINKS UPDATED INSTANTLY              │
  │ - ~/02luka/followup.json                    │
  │ - g/apps/dashboard/data/followup.json       │
  │ - tools/data/followup.json                  │
  │ - g/run/followup_index.json                 │
  └─────────────────────────────────────────────┘
```

## Benefits of Symlink Approach

✅ **Single source of truth** - Only one file gets written
✅ **Instant propagation** - All symlinks reflect changes immediately
✅ **No synchronization lag** - Zero delay between update and access
✅ **Context-appropriate paths** - Each location makes sense for its use case
✅ **Easy to remember** - Root level = quick access, app/data = integration

## Troubleshooting

### Symlink appears broken
```bash
# Check if primary source exists
ls -lh ~/02luka/g/knowledge/followup_index.json

# Recreate symlinks
cd ~/02luka && ln -sf g/knowledge/followup_index.json followup.json
cd ~/02luka/g/apps/dashboard/data && ln -sf ../../../knowledge/followup_index.json followup.json
cd ~/02luka/tools/data && ln -sf ../../g/knowledge/followup_index.json followup.json
cd ~/02luka/g/run && ln -sf ../knowledge/followup_index.json followup_index.json
```

### Primary source not updating
```bash
# Check LaunchAgent status
launchctl list | grep followup_tracker

# Check logs
tail -f ~/02luka/logs/followup_tracker.log

# Manual update
~/02luka/tools/followup_tracker_update.zsh
```

---

**Status:** ✅ OPERATIONAL
**All Symlinks:** VERIFIED WORKING
**Last Test:** 2025-11-06T05:29
