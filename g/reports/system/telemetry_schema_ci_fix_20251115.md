# Telemetry Schema CI Fix

**Date:** 2025-11-15  
**Issue:** System Telemetry v2 workflow failing - schema file not found  
**Status:** 🔍 **INVESTIGATING**

---

## Problem

The System Telemetry v2 workflow is failing with:
```
❌ g/schemas/telemetry_v2.schema.json not found
Error: Process completed with exit code 1.
```

**Context:**
- File exists in `feature/multi-agent-pr-contract` branch (commit `16c1870c5`)
- File is committed and tracked
- CI workflow is checking for the file but can't find it

---

## Root Cause Analysis

### Possible Causes

1. **Branch Mismatch:**
   - Workflow runs on `main` branch (scheduled runs)
   - Schema file is only in `feature/multi-agent-pr-contract`
   - File not yet merged to `main`

2. **Workflow Context:**
   - Scheduled workflows run on default branch (`main`)
   - Workflow dispatch might run on different branches
   - File needs to be in the branch being checked

3. **Timing Issue:**
   - File was added but not yet merged
   - CI ran before merge completed

---

## Current Status

### ✅ File Status in `feature/multi-agent-pr-contract`
- **Exists:** ✅ Yes
- **Committed:** ✅ Yes (commit `16c1870c5`)
- **Tracked:** ✅ Yes
- **Pushed:** ✅ Yes (to `origin/feature/multi-agent-pr-contract`)

### ❌ File Status in `main`
- **Exists:** ❌ Unknown (needs verification)
- **Committed:** ❌ Likely not yet merged

---

## Solutions

### Option 1: Merge Feature Branch (Recommended)
**When:** After PR #287 is approved and merged
- Schema file will be included in merge
- All changes go together
- **Timeline:** Depends on PR review

### Option 2: Cherry-Pick Schema Commit
**When:** Immediate fix needed
```bash
git checkout main
git cherry-pick 16c1870c5
git push origin main
```
- **Pros:** Quick fix, schema available immediately
- **Cons:** Schema commit separated from other changes

### Option 3: Separate PR for Schema
**When:** Want to fix CI immediately without waiting for PR #287
- Create `fix/telemetry-schema-only` branch
- Cherry-pick schema commit
- Open PR targeting `main`
- **Timeline:** ~15 minutes

---

## Recommended Action

**Immediate Fix (if CI is blocking):**
1. Create separate PR for schema only:
   ```bash
   git checkout -b fix/telemetry-schema-only main
   git cherry-pick 16c1870c5
   git push -u origin fix/telemetry-schema-only
   gh pr create --title "fix(ci): add telemetry_v2 schema for System Telemetry v2 workflow"
   ```

**Long-term (preferred):**
- Wait for PR #287 (`feature/multi-agent-pr-contract`) to be merged
- Schema will be included automatically

---

## Verification

After fix is applied:
```bash
# Verify file exists in target branch
git show <branch>:g/schemas/telemetry_v2.schema.json

# Verify workflow can find it
# Check CI run logs for: "✅ g/schemas/telemetry_v2.schema.json exists"
```

---

## Related

- **Commit:** `16c1870c5` - "fix(ci): add telemetry_v2 schema to g/schemas/"
- **Branch:** `feature/multi-agent-pr-contract`
- **PR:** #287 (Multi-agent PR contract)
- **Workflow:** `.github/workflows/system-telemetry-v2.yml`

---

**Status:** 🔍 **INVESTIGATING** - Need to determine if file is in `main` branch
