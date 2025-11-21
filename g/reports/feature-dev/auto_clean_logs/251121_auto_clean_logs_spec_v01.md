# Auto-Clean Logs Feature — SPEC

**Version**: v01  
**Date**: 2025-11-21  
**Owner**: Liam  
**Type**: System Maintenance Feature

---

## 1. Objective

Create an automated log cleaning utility that:
- Identifies old/large log files in the 02luka system
- Archives or deletes them based on configurable rules
- Prevents disk space issues from log accumulation
- Logs cleanup actions to AP/IO

---

## 2. Scope

### In Scope:
- ✅ Scan designated log directories
- ✅ Identify files older than N days
- ✅ Archive to compressed format (optional)
- ✅ Delete files exceeding size threshold
- ✅ AP/IO logging of cleanup actions
- ✅ Dry-run mode for safety

### Out of Scope:
- ❌ Real-time log rotation (use system logrotate)
- ❌ Log parsing/analysis
- ❌ Cloud backup integration

---

## 3. Target Directories

- `g/ledger/*.jsonl` (AP/IO ledger files)
- `g/mls/ledger/*.jsonl` (MLS ledger files)
- `logs/` (if exists)
- Configurable via config file

---

## 4. Cleanup Rules

### Age-Based:
- Files older than 30 days → archive to `.gz`
- Files older than 90 days → delete

### Size-Based:
- Files larger than 100MB → archive immediately
- Total directory size > 1GB → trigger cleanup

---

## 5. Safety Features

- **Dry-run mode**: Preview actions without executing
- **Backup before delete**: Optional archive step
- **AP/IO logging**: All actions logged
- **Whitelist**: Never touch certain files (e.g., current day's ledger)

---

## 6. Success Criteria

- [ ] Script created and tested
- [ ] Dry-run mode works
- [ ] Archive functionality works
- [ ] Delete functionality works
- [ ] AP/IO logging works
- [ ] Boss approves

---

**Status**: ✅ SPEC COMPLETE
