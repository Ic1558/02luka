# AP/IO v3.1 Migration Guide

**Version:** 3.1  
**Date:** 2025-11-16  
**Status:** Active

---

## Overview

This guide explains how to migrate from Agent Ledger v1.0 to AP/IO v3.1.

---

## Migration Strategy

### Automatic Conversion

The `reader.zsh` automatically converts v1.0 format to v3.1 structure:

```bash
# v1.0 format is automatically converted when reading
tools/ap_io_v31/reader.zsh g/ledger/cls/2025-11-16.jsonl
```

### Manual Migration

If you need to convert existing v1.0 files:

1. Read v1.0 entries
2. Convert to v3.1 format
3. Write to new ledger file

---

## Format Differences

### v1.0 Format
```json
{
  "ts": "2025-11-16T10:00:00+07:00",
  "agent": "cls",
  "event": "task_start",
  "task_id": "wo-test",
  "data": {
    "status": "started",
    "duration_sec": 5
  }
}
```

### v3.1 Format
```json
{
  "protocol": "AP/IO",
  "version": "3.1",
  "ledger_id": "ledger-20251116-100000-cls-001",
  "ts": "2025-11-16T10:00:00+07:00",
  "agent": "cls",
  "event": {
    "type": "task_start",
    "task_id": "wo-test",
    "source": "system",
    "summary": ""
  },
  "data": {
    "status": "started",
    "duration_sec": 5
  }
}
```

---

## Migration Steps

1. **Backup existing ledger files**
   ```bash
   cp -r g/ledger g/ledger_backup_v1.0
   ```

2. **Test reader conversion**
   ```bash
   tools/ap_io_v31/reader.zsh g/ledger/cls/2025-11-16.jsonl | head -5
   ```

3. **Gradually migrate agents**
   - Start with one agent (e.g., CLS)
   - Verify conversion works
   - Migrate other agents

4. **Update integration scripts**
   - Use v3.1 writer
   - Update status files
   - Test thoroughly

---

## Backward Compatibility

- ✅ Reader supports both v1.0 and v3.1
- ✅ Writer generates v3.1 only
- ✅ Extension fields optional (backward compatible)

---

**Document Owner:** Liam  
**Last Updated:** 2025-11-16
