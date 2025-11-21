# ATG Liam Session Memory v0.1 — PLAN

**Version**: v01  
**Date**: 2025-11-21  
**Owner**: Liam  
**Executor**: Liam (design) → Hybrid (file creation)

---

## 1. Overview

This plan implements the **contract-based memory system** with forced validation for Liam in Antigravity.

**Effort**: Medium  
**Risk**: Low  
**Duration**: 2-3 hours

---

## 2. Implementation Steps

### Step 1: Create Directory Structure

**Directories**:
```bash
mkdir -p g/memory/ledger
mkdir -p g/memory/reports
mkdir -p g/tools
```

**Tool**: `run_command`

---

### Step 2: Create Loader Script

**File**: `g/tools/atg_memory_load.py`

**Functions**:
- `load_recent_entries(limit=10)` - Read last N entries
- `extract_constraints(entries)` - Extract MUST_DO / MUST_NOT_DO
- `generate_context(entries)` - Create recent context summary
- `main()` - Output JSON to stdout

**Logic**:
1. Read `g/memory/ledger/liam_memory.jsonl`
2. Parse last 10 entries
3. Extract all `MUST_DO` and `MUST_NOT_DO` from learnings
4. Deduplicate constraints
5. Generate context summary
6. Output JSON: `{"constraints": {...}, "recent_context": {...}}`

**Tool**: `write_to_file`

---

### Step 3: Create Saver Script

**File**: `g/tools/atg_memory_save.py`

**Functions**:
- `generate_content_hash(payload)` - MD5 hash for deduplication
- `check_duplicate(hash, hours=24)` - Check recent duplicates
- `save_to_ledger(entry)` - Append to JSONL
- `create_report(entry)` - Generate markdown report
- `main()` - Process payload and save

**Logic**:
1. Parse JSON payload from `--payload` arg
2. Generate content hash
3. Check for duplicates in last 24h
4. If duplicate: skip and log warning
5. If unique: add session_id + timestamp
6. Append to `liam_memory.jsonl`
7. Create markdown report in `g/memory/reports/`

**Tool**: `write_to_file`

---

### Step 4: Update Liam Persona

**File**: `agents/liam/PERSONA_PROMPT.md`

**Action**: Add mandatory protocol as **Section 1** (before all other content)

**Content**:
```markdown
## Core Protocol: Memory and Validation (MANDATORY)

This protocol is CRITICAL and must NEVER be bypassed.

### 1. On Session Start (First Interaction)
[Boss-provided content]

### 2. Before Every Response (Constraint Validation)
[Boss-provided content]

### 3. On Session End or Milestone Completion
[Boss-provided content]

*Violation of this protocol constitutes a failure of your core function.*
```

**Tool**: `replace_file_content` (insert at line 1)

---

### Step 5: Create Initial Memory Ledger

**File**: `g/memory/ledger/liam_memory.jsonl`

**Content**: Empty file (will be populated by saver)

**Tool**: `write_to_file` (empty file)

---

### Step 6: Create Unit Tests

**File**: `tests/test_atg_memory_v01.py`

**Test Cases**:
1. Test loader with empty ledger
2. Test loader with 5 entries
3. Test saver with new entry
4. Test saver with duplicate (should skip)
5. Test constraint extraction
6. Test deduplication

**Tool**: `write_to_file`

---

### Step 7: Run Tests

**Commands**:
```bash
# Test loader (empty ledger)
python g/tools/atg_memory_load.py --mode=liam-session

# Test saver
python g/tools/atg_memory_save.py --payload '{"outcome": {"result": "success"}, "learnings": {...}}'

# Verify ledger file created
cat g/memory/ledger/liam_memory.jsonl

# Run unit tests
python tests/test_atg_memory_v01.py
```

**Tool**: `run_command`

---

### Step 8: Proof of Concept Test

**Scenario**: Test forced validation

**Steps**:
1. Manually add entry to ledger:
   ```json
   {"learnings": {"MUST_DO": ["Create spec/plan first"]}}
   ```

2. Load memory:
   ```bash
   python g/tools/atg_memory_load.py
   ```

3. Verify output contains constraint:
   ```json
   {"constraints": {"MUST_DO": ["Create spec/plan first"]}}
   ```

4. Test validation in next session:
   - Boss: "Create memory system"
   - Expected: I create spec/plan, NOT files
   - Actual: [verify behavior]

**Tool**: Manual test + observation

---

### Step 9: Log to AP/IO

**Event**: `atg_memory_system_deployed`

**Data**:
```json
{
  "version": "v0.1",
  "type": "contract_based_memory",
  "components": [
    "loader",
    "saver",
    "persona_contract",
    "validation_checklist"
  ],
  "enforcement": "mandatory"
}
```

**Tool**: Python script with `write_ledger_entry`

---

## 3. File Structure

```
g/
├── memory/
│   ├── ledger/
│   │   └── liam_memory.jsonl          # Append-only memory ledger
│   └── reports/
│       └── session_YYYYMMDD_HHMMSS.md # Human-readable reports
├── tools/
│   ├── atg_memory_load.py             # Loader script
│   └── atg_memory_save.py             # Saver script
└── reports/
    └── feature-dev/
        └── atg_liam_memory_v01/
            ├── 251121_atg_liam_memory_v01_spec_v01.md
            └── 251121_atg_liam_memory_v01_plan_v01.md

agents/liam/
└── PERSONA_PROMPT.md                  # Updated with mandatory protocol

tests/
└── test_atg_memory_v01.py             # Unit tests
```

---

## 4. Execution Order

1. ✅ Create SPEC.md
2. ✅ Create PLAN.md
3. ⬜ Create directories
4. ⬜ Create loader script
5. ⬜ Create saver script
6. ⬜ Update Liam persona
7. ⬜ Create initial ledger file
8. ⬜ Create unit tests
9. ⬜ Run tests
10. ⬜ Proof of concept test
11. ⬜ Log to AP/IO

---

## 5. Testing

### Test 1: Loader (Empty Ledger)
```bash
python g/tools/atg_memory_load.py
# Expected: {"constraints": {"MUST_DO": [], "MUST_NOT_DO": []}, "recent_context": {}}
```

### Test 2: Saver (New Entry)
```bash
python g/tools/atg_memory_save.py --payload '{"outcome": {"result": "success"}, "learnings": {"MUST_DO": ["test"]}}'
# Expected: Entry appended to ledger, report created
```

### Test 3: Saver (Duplicate)
```bash
# Run same command twice
# Expected: Second run skips with "Duplicate detected" message
```

### Test 4: Validation (Proof of Concept)
```
Session 1: Save "MUST_DO: Create spec/plan first"
Session 2: Boss says "create X"
Expected: I create spec/plan, NOT files
```

---

## 6. Rollback Plan

**If system fails**:
1. Remove persona protocol from `PERSONA_PROMPT.md`
2. Delete `g/memory/` directory
3. Delete loader/saver scripts
4. Revert to no memory system

**Risk**: Very low (no impact on existing functionality)

---

## 7. Post-Implementation

### Documentation:
- Create `g/memory/README.md` explaining system
- Update `agents/liam/README.md` with memory section

### Next Steps:
- Monitor memory usage over 1 week
- Verify constraints are actually enforced
- Collect Boss feedback
- Plan v0.2 improvements

---

**Status**: ✅ PLAN COMPLETE - READY FOR EXECUTION
