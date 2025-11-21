# Feature-Dev Reports Structure

This directory contains all feature development specifications and plans organized by feature.

## Directory Structure

```
g/reports/feature-dev/
├── <feature_name>/
│   ├── yymmdd_topic_spec_v01.md    # Initial specification
│   ├── yymmdd_topic_plan_v01.md    # Initial implementation plan
│   ├── yymmdd_topic_spec_v02.md    # Updated spec (if needed)
│   ├── yymmdd_topic_plan_v02.md    # Updated plan (if needed)
│   └── ...
└── README.md                        # This file
```

## Naming Conventions

### Feature Folder Names:
- **All lowercase**
- **Use underscores** for spaces
- **Descriptive** but concise
- Examples: `wo_hybrid_blueprint`, `writer_policy_v35`, `v35_blueprint`

### File Names:
- **Format**: `yymmdd_topic_spec_vXX.md` or `yymmdd_topic_plan_vXX.md`
- **yymmdd**: Date created (e.g., `251121` for 2025-11-21)
- **topic**: Feature name (lowercase with underscores)
- **spec/plan**: Type of document
- **vXX**: Version number (v01, v02, v03, etc.)

**Examples**:
- `251121_v35_blueprint_spec_v01.md`
- `251121_wo_hybrid_blueprint_plan_v01.md`
- `251121_writer_policy_v35_spec_v02.md`

### Version Increments:
- Create new version when:
  - Boss requests significant changes to spec
  - Implementation approach changes
  - New requirements discovered
- Keep old versions for history
- Date prefix helps track when each version was created

## Current Features

### 1. v35_blueprint
**Purpose**: Create 02luka V3.5 Architecture Blueprint

**Files**:
- `251121_v35_blueprint_spec_v01.md`
- `251121_v35_blueprint_plan_v01.md`

### 2. wo_hybrid_blueprint
**Purpose**: Create V3.5 Blueprint via HYBRID Work Order

**Files**:
- `251121_wo_hybrid_blueprint_spec_v01.md`
- `251121_wo_hybrid_blueprint_plan_v01.md`

### 3. writer_policy_v35
**Purpose**: Define formal writer permissions for V3.5

**Files**:
- `251121_writer_policy_v35_spec_v01.md`
- `251121_writer_policy_v35_plan_v01.md`

## Usage

### For Liam (feature-dev lane):

When Boss requests a feature:

1. **Create feature folder**:
   ```bash
   mkdir -p g/reports/feature-dev/<feature_name>
   ```

2. **Create initial files** (with today's date):
   ```bash
   # Format: yymmdd_topic_spec_v01.md
   # Example: 251121_my_feature_spec_v01.md
   ```

3. **When Boss requests changes**:
   - Create `yymmdd_topic_spec_v02.md` with updated requirements
   - Create `yymmdd_topic_plan_v02.md` with updated approach
   - Keep v01 files for history

### For Boss:

- Review `*_spec_v01.md` first (what will be built)
- Review `*_plan_v01.md` second (how it will be built)
- Request changes → Liam creates v02 files with same date prefix
- Approve → Liam proceeds with implementation

## File Templates

### Spec Template:
```markdown
# <Feature Name> — SPEC

**Version**: v01
**Date**: YYYY-MM-DD
**Owner**: Liam
**Type**: <type>

## 1. Objective
## 2. Scope
## 3. Requirements
## 4. Deliverables
## 5. Constraints
## 6. Success Criteria
## 7. Risks
```

### Plan Template:
```markdown
# <Feature Name> — PLAN

**Version**: v01
**Date**: YYYY-MM-DD
**Owner**: Liam
**Executor**: <agent>

## 1. Overview
## 2. Implementation Steps
## 3. File Structure
## 4. Execution Order
## 5. Rollback Plan
## 6. Testing
## 7. Post-Implementation
```

---

**Last Updated**: 2025-11-21
