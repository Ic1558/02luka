# Auto-Clean Logs Feature — PLAN

**Version**: v01  
**Date**: 2025-11-21  
**Owner**: Liam  
**Executor**: Hybrid

---

## 1. Implementation Steps

### Step 1: Create Config File
**File**: `g/config/auto_clean_logs.yaml`

**Content**:
```yaml
directories:
  - g/ledger
  - g/mls/ledger
  - logs

rules:
  age_archive_days: 30
  age_delete_days: 90
  size_threshold_mb: 100
  total_size_threshold_gb: 1

whitelist:
  - "**/current.jsonl"
  - "**/*$(date +%Y-%m-%d)*"

dry_run: true
```

---

### Step 2: Create Cleanup Script
**File**: `g/tools/auto_clean_logs.py`

**Functions**:
- `load_config()` - Load YAML config
- `scan_directories()` - Find all log files
- `apply_rules()` - Determine which files to archive/delete
- `archive_file()` - Compress to .gz
- `delete_file()` - Remove file
- `log_action()` - Write to AP/IO ledger
- `main()` - Orchestrate cleanup

---

### Step 3: Add AP/IO Events
**Events**:
- `log_cleanup_started`
- `log_file_archived`
- `log_file_deleted`
- `log_cleanup_completed`

---

### Step 4: Create Tests
**File**: `tests/test_auto_clean_logs.py`

**Test Cases**:
1. Test dry-run mode
2. Test age-based archiving
3. Test size-based deletion
4. Test whitelist protection
5. Test AP/IO logging

---

### Step 5: Run Dry-Run Test
```bash
python g/tools/auto_clean_logs.py --dry-run
```

Verify output shows what WOULD be cleaned without actually doing it.

---

### Step 6: Run Real Cleanup (Boss Approval Required)
```bash
python g/tools/auto_clean_logs.py
```

---

## 2. Execution Order

1. ✅ Create SPEC.md
2. ✅ Create PLAN.md
3. ⬜ Create config file
4. ⬜ Create cleanup script
5. ⬜ Add AP/IO events
6. ⬜ Create tests
7. ⬜ Run dry-run test
8. ⬜ Get Boss approval
9. ⬜ Run real cleanup

---

**Status**: ✅ PLAN COMPLETE - READY FOR IMPLEMENTATION
