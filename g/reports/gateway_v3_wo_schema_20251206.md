# Gateway v3 - Work Order Schema

**Version:** 3.0  
**Date:** 2025-12-06  
**Phase:** 0

---

## 📋 **SCHEMA OVERVIEW**

Gateway v3 WO Schema is a **superset** of v2 - all existing WOs continue to work.

---

## 🔧 **BASE FIELDS (v2 Compatible)**

### **Required Fields**

```yaml
wo_id: string              # Work Order identifier (required)
title: string              # Brief description (required)
```

### **Optional Fields (v2)**

```yaml
strict_target: string      # Target agent: "CLC", "LIAM", "LAC", etc.
routing_hint: string       # Routing hint: "dev_oss", "qa", etc.
priority: string           # Priority: "P1", "P2", "P3", "low", "normal", "high"
status: string             # Status: "pending", "processing", "completed"
objective: string          # Multi-line description
scope:                     # Scope definition
  include: [string]        # Paths to include
  exclude: [string]        # Paths to exclude
constraints: [string]      # List of constraints
tasks:                     # Task breakdown
  - id: string
    desc: string
    steps: [string]
acceptance_criteria: [string]  # Success criteria
outputs: [string]          # Expected outputs
notes: string              # Additional notes
```

---

## 🆕 **NEW FIELDS (v3)**

### **Tracking Fields**

```yaml
entry_channel: string      # Entry point: "MAIN", "ENTRY", "direct"
created_by: string         # Creator: "GG", "Opal", "CLI", "GMX", "Codex"
source: string             # Source system identifier
created_at: string         # ISO timestamp (e.g., "2025-12-06T12:34:56Z")
```

**Note:** All new fields are **optional** - v2 WOs without these fields still work.

---

## 🔄 **ROUTING PRIORITY**

### **Phase 0 Routing Logic**

1. **strict_target** (highest priority)
   - If present and valid → Use this target
   - Phase 0: Only "CLC" supported

2. **routing_hint** (fallback)
   - If no strict_target → Map routing_hint to target
   - Phase 0 mapping: `{"dev_oss": "CLC", "dev_oss_lane": "CLC"}`

3. **default_target** (final fallback)
   - If no strict_target and no routing_hint → Use default
   - Phase 0 default: "CLC"

4. **Error** (no valid route)
   - If no valid route found → Move to `bridge/error/MAIN/`

---

## 📝 **EXAMPLES**

### **Example 1: Minimal WO (v2 Compatible)**

```yaml
wo_id: "WO-20251206-TEST-001"
title: "Test Work Order"
strict_target: "CLC"
```

**Result:** Routes to CLC ✅

---

### **Example 2: WO with routing_hint**

```yaml
wo_id: "WO-20251206-TEST-002"
title: "Test with routing hint"
routing_hint: "dev_oss"
```

**Result:** Routes to CLC (via routing_hint mapping) ✅

---

### **Example 3: WO with v3 fields**

```yaml
wo_id: "WO-20251206-TEST-003"
title: "Test with v3 fields"
strict_target: "CLC"
entry_channel: "MAIN"
created_by: "GG"
source: "gateway_v3"
created_at: "2025-12-06T12:34:56Z"
```

**Result:** Routes to CLC, all fields tracked in telemetry ✅

---

### **Example 4: Full WO (v2 + v3)**

```yaml
wo_id: "WO-20251206-FULL-001"
title: "Complete Work Order Example"
strict_target: "CLC"
routing_hint: "dev_oss"
priority: "P1"
status: "pending"
entry_channel: "MAIN"
created_by: "GG"
source: "gateway_v3"
created_at: "2025-12-06T12:34:56Z"

objective: |
  Complete example with all fields

scope:
  include:
    - "agents/**"
    - "tools/**"
  exclude:
    - ".git/**"
    - "logs/**"

constraints:
  - "No breaking changes"
  - "Backward compatible"

tasks:
  - id: "T1"
    desc: "Task 1"
    steps:
      - "Step 1"
      - "Step 2"

acceptance_criteria:
  - "All tests pass"
  - "Documentation complete"

outputs:
  - "Implementation"
  - "Documentation"

notes: |
  Additional notes here
```

---

## ✅ **BACKWARD COMPATIBILITY**

### **v2 WOs**

All v2 WOs work without modification:
- ✅ No new fields required
- ✅ Existing routing logic preserved
- ✅ All v2 fields still supported

### **Migration Path**

**Phase 0:**
- ✅ v2 WOs work as-is
- ✅ v3 fields optional

**Phase 1+ (Future):**
- Migrate producers to use v3 fields
- Add validation for required v3 fields (optional)

---

## 🔍 **VALIDATION RULES**

### **Required Fields**

- `wo_id`: Must be present (or inferred from filename)
- `title`: Must be present

### **Routing Validation**

- `strict_target`: Must be in `supported_targets` (Phase 0: ["CLC"])
- `routing_hint`: Must map to valid target (Phase 0: all map to "CLC")

### **Error Cases**

- Missing required fields → Error (moved to error/)
- Invalid YAML → Error (moved to error/)
- No valid route → Error (moved to error/)

---

## 📊 **FIELD REFERENCE**

| Field | Type | Required | Default | Notes |
|-------|------|----------|---------|-------|
| `wo_id` | string | ✅ Yes | filename | Work Order ID |
| `title` | string | ✅ Yes | - | Brief description |
| `strict_target` | string | ❌ No | - | Target agent (priority 1) |
| `routing_hint` | string | ❌ No | - | Routing hint (priority 2) |
| `priority` | string | ❌ No | - | Priority level |
| `status` | string | ❌ No | "pending" | Current status |
| `objective` | string | ❌ No | - | Multi-line description |
| `scope` | object | ❌ No | - | Include/exclude paths |
| `constraints` | array | ❌ No | [] | List of constraints |
| `tasks` | array | ❌ No | [] | Task breakdown |
| `acceptance_criteria` | array | ❌ No | [] | Success criteria |
| `outputs` | array | ❌ No | [] | Expected outputs |
| `notes` | string | ❌ No | - | Additional notes |
| `entry_channel` | string | ❌ No | - | **v3:** Entry point |
| `created_by` | string | ❌ No | - | **v3:** Creator |
| `source` | string | ❌ No | - | **v3:** Source system |
| `created_at` | string | ❌ No | - | **v3:** ISO timestamp |

---

## 🎯 **PHASE 0 CONSTRAINTS**

- ✅ Only `strict_target: "CLC"` supported
- ✅ All `routing_hint` values map to "CLC"
- ✅ Default target: "CLC"
- ❌ Other targets (LIAM, QA, etc.) not supported

---

**Schema Version:** 3.0  
**Phase:** 0  
**Status:** ✅ **DOCUMENTED**
