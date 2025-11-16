# Phase 22 Telemetry — Quick Commands

**Last Updated**: 2025-11-08

---

## 🧰 Quick Commands

### 1. Run PR Watcher (Background)
```bash
~/watch_phase22_v0.zsh &
```
**What it does**: Monitors for Phase 22 PRs every 15 seconds and exits when found.

**Status**: ✅ Verified

---

### 2. Check Telemetry Events
```bash
tail ~/02luka/g/telemetry/unified.jsonl
```

**Pretty format**:
```bash
tail ~/02luka/g/telemetry/unified.jsonl | jq -c '.'
```

**Status**: ✅ Verified (5 events logged)

**Latest events**:
- `ocr` → `sha256_validation` (3 events)
- `system` → `phase22_v0_queue` (1 event)
- `pr_scoring` → `evaluated` (1 event)

---

### 3. Check CLC Inbox
```bash
ls -lh ~/02luka/bridge/inbox/CLC/*.json
```

**View contents**:
```bash
cat ~/02luka/bridge/inbox/CLC/*.json | jq -r '.title, .status'
```

**Status**: ✅ Verified (2 files)
- `WO-20251108_204850-PHASE22-TEL-DASH.json` (3.3K)
- `WO-20251108_212952-PHASE22_1-INTERACTIVE.json` (10K)

---

### 4. View Spec 22.1
```bash
cat ~/02luka/specs/phase22_1_telemetry_dashboard_v1.md
```

**Status**: ✅ Verified

**Key features**:
- Auto-refresh (5-10s intervals)
- Client-side filters (agent, event, status, time range)
- Export to JSON/CSV
- Search functionality

---

### 5. Send New Telemetry Event
```bash
~/02luka/tools/telemetry_unified.zsh <agent> <event> <ok> '<detail_json>'
```

**Examples**:
```bash
# Success event
~/02luka/tools/telemetry_unified.zsh ocr file_processed true '{"file":"doc.pdf","size":1024}'

# Failure event
~/02luka/tools/telemetry_unified.zsh router query_failed false '{"error":"timeout","query":"test"}'

# System event
~/02luka/tools/telemetry_unified.zsh system phase22_started true '{"version":"v0"}'
```

**Status**: ✅ Verified

**Output location**: `~/02luka/g/telemetry/unified.jsonl`

**Format**:
```json
{"ts":"2025-11-08T21:30:00Z","agent":"ocr","event":"file_processed","ok":true,"detail":{"file":"doc.pdf","size":1024}}
```

---

## 📊 System Status

| Component | Status | Location |
|-----------|--------|----------|
| PR Watcher | ✅ Ready | `~/watch_phase22_v0.zsh` |
| Telemetry Log | ✅ Active | `~/02luka/g/telemetry/unified.jsonl` |
| CLC Inbox | ✅ Active | `~/02luka/bridge/inbox/CLC/` |
| Spec 22.1 | ✅ Available | `~/02luka/specs/phase22_1_telemetry_dashboard_v1.md` |
| Event Tool | ✅ Ready | `~/02luka/tools/telemetry_unified.zsh` |

---

## 🔍 Advanced Usage

### Monitor telemetry in real-time
```bash
tail -f ~/02luka/g/telemetry/unified.jsonl | jq -c '.'
```

### Filter by agent
```bash
grep '"agent":"ocr"' ~/02luka/g/telemetry/unified.jsonl | jq -c '.'
```

### Filter by event type
```bash
grep '"event":"sha256_validation"' ~/02luka/g/telemetry/unified.jsonl | jq -c '.'
```

### Count events by agent
```bash
cat ~/02luka/g/telemetry/unified.jsonl | jq -r '.agent' | sort | uniq -c
```

### Count events by status
```bash
cat ~/02luka/g/telemetry/unified.jsonl | jq -r 'if .ok then "success" else "failure" end' | sort | uniq -c
```

---

## 📝 Notes

- All commands use absolute paths for reliability
- Telemetry events are appended to `unified.jsonl` (JSONL format)
- CLC inbox files are created by the workflow orchestration system
- PR watcher runs in background and exits when Phase 22 PR is found
- Event tool requires valid JSON for `detail_json` parameter
