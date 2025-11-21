# Feature-Dev Structure Deployment — SPEC

**Version**: v01  
**Date**: 2025-11-21  
**Owner**: Liam  
**Type**: Deployment (Documentation & Structure)

---

## 1. Objective

Deploy the new **feature-dev structure and naming convention** for all future feature development work in 02luka.

**Goals**:
- ✅ Establish standard directory structure
- ✅ Enforce naming convention (yymmdd_topic_spec/plan_vXX.md)
- ✅ Document usage for all agents
- ✅ Migrate existing files to new structure
- ✅ Update Liam persona to use new convention

---

## 2. What is Being Deployed

### Directory Structure:
```
g/reports/feature-dev/
├── README.md                                    # Structure documentation
├── <feature_name>/
│   ├── yymmdd_topic_spec_v01.md                # Specification
│   └── yymmdd_topic_plan_v01.md                # Implementation plan
```

### Naming Convention:
- **Format**: `yymmdd_topic_spec_vXX.md` / `yymmdd_topic_plan_vXX.md`
- **yymmdd**: Creation date (e.g., 251121)
- **topic**: Feature name (lowercase, underscores)
- **spec/plan**: Document type
- **vXX**: Version (v01, v02, etc.)

### Current Features Deployed:
1. `v35_blueprint/` - V3.5 Architecture Blueprint
2. `wo_hybrid_blueprint/` - WO HYBRID creation script
3. `writer_policy_v35/` - Writer permissions policy

---

## 3. Pre-Deployment Checklist

- [x] Directory structure created
- [x] All existing files migrated
- [x] Naming convention applied
- [x] README.md created
- [x] No old files remaining in `g/reports/`

---

## 4. Deployment Steps

### Step 1: Verify Structure
```bash
tree g/reports/feature-dev -L 2
```

### Step 2: Verify Naming
```bash
find g/reports/feature-dev -name "*.md" -type f | grep -E "^[0-9]{6}_.*_(spec|plan)_v[0-9]{2}\.md$"
```

### Step 3: Verify No Old Files
```bash
ls g/reports/*.md 2>/dev/null | grep -E "(SPEC|PLAN)" || echo "✅ Clean"
```

---

## 5. Post-Deployment Checks

- [ ] All files follow naming convention
- [ ] README.md is accurate
- [ ] No orphaned files in `g/reports/`
- [ ] Liam persona updated to use new convention
- [ ] Documentation references updated

---

## 6. Rollback Plan

**If deployment fails**:
1. Restore old file names
2. Move files back to `g/reports/`
3. Delete `feature-dev/` directory

**Risk**: Very low (documentation only, no code changes)

---

## 7. Success Criteria

- [x] Directory structure exists
- [x] All files follow naming convention
- [x] README.md documents usage
- [x] No old files remaining
- [ ] Liam uses new convention automatically

---

## 8. Impact Assessment

| Component | Impact | Notes |
|-----------|--------|-------|
| Existing workflows | None | No breaking changes |
| Liam behavior | Updated | Auto-creates files in new structure |
| File organization | Improved | Better tracking with date prefixes |
| Version control | Improved | Clear version history |

---

**Status**: ✅ DEPLOYMENT READY
