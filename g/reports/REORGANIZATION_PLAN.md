# g/reports Safe Reorganization Options

**Date:** 2025-12-06  
**Current State:** 87 files, some structure exists  
**Risk Level:** Medium (code dependencies found)

---

## Current Structure (Actual)

```
g/reports/
├── health/              ✅ (referenced by tools)
├── system/              ✅ (referenced by tools)
├── feature-dev/         ✅ (referenced by fde_validator)
├── sessions/            ✅ (referenced by save.sh)
├── deployments/         ✅ exists
├── deployed/            ✅ exists
├── autopilot_digests/   ✅ exists
├── gemini/              ✅ exists
└── [87 loose MD files]  ⚠️ needs organization
```

---

## Option 1: Safe Minimal Cleanup (RECOMMENDED)

**What:** Move loose files into existing folders only  
**Risk:** Very Low ✅  
**Time:** 5 minutes

### Actions:
```bash
# Move RAM analysis to system/
mv ram_*.md system/
mv app_closure*.md system/

# Move LaunchAgent to system/
mv launchagent_*.md system/

# Move code reviews to deployed/ or deployments/
mv code_review_*.md deployed/

# Leave existing structure unchanged
```

**Benefits:**
- ✅ No script updates needed
- ✅ Uses existing folders
- ✅ Safe and fast

---

## Option 2: Create Subfolders (MEDIUM RISK)

**What:** Add subfolders under existing directories  
**Risk:** Low  
**Time:** 10 minutes

### Structure:
```
g/reports/
├── system/
│   ├── ram/           [NEW]
│   ├── launchagent/   [NEW]
│   └── health/        [NEW]
├── deployed/
│   ├── gateways/      [NEW]
│   └── workers/       [NEW]
└── [keep others as-is]
```

**Note:** Scripts reference `g/reports/system/` but not subpaths, so safe

---

## Option 3: Full Reorganization (HIGH RISK)

**What:** Complete restructure  
**Risk:** High ⚠️  
**Time:** 2+ hours (updating scripts)  
**Not Recommended**

---

## Recommendation

**Use Option 1: Safe Minimal Cleanup**

**Why:**
1. ✅ Existing folders already logical
2. ✅ No code changes needed
3. ✅ Immediate improvement
4. ✅ Zero risk

**Execute:**
```bash
# Just move loose files to appropriate existing folders
```

---

**Boss, which option?**
- A: Option 1 (Safe minimal - recommended) ✅
- B: Option 2 (Add subfolders)
- C: Option 3 (Full reorg - not recommended)
