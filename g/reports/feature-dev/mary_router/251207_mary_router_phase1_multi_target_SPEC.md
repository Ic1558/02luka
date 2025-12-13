# Mary Router Gateway v3 - Phase 1: Multi-Target Routing

**Date:** 2025-12-07  
**Status:** SPEC  
**Phase:** 0 → 1

---

## 🎯 **Objective**

Transform Mary Router from "CLC-only router" to **true central dispatcher** supporting multiple agent targets (CLC, GMX, LOCAL, KIM, etc.).

**Design Principle:**
- **Entry Point:** `bridge/inbox/MAIN` (central inbox)
- **Mary Router:** Central dispatcher (not CLC-specific)
- **Targets:** Configurable agent inboxes (CLC, GMX, LOCAL, KIM, etc.)

---

## 📋 **Current State (Phase 0)**

### Code Structure ✅
- Routing logic already supports multi-target (uses `supported_targets` set)
- `route_wo()` method is target-agnostic
- Telemetry tracks target dynamically

### Config & Comments ❌
- Comments say "Phase 0: Only CLC supported"
- Config hardcodes `supported_targets: [CLC]`
- Target path hardcoded: `bridge/inbox/{target}` (no mapping)
- Default config in code is CLC-only

---

## 🔧 **Phase 1 Changes**

### 1. **Config Schema Update**

**File:** `g/config/mary_router_gateway_v3.yaml`

**From:**
```yaml
routing:
  default_target: "CLC"
  supported_targets:
    - "CLC"
  # Phase 0: Only CLC supported
  routing_hint_mapping:
    "dev_oss": "CLC"
    "dev_oss_lane": "CLC"
    # Phase 0: All routing_hints map to CLC

directories:
  inbox: "bridge/inbox/MAIN"
  processed: "bridge/processed/MAIN"
  error: "bridge/error/MAIN"
```

**To:**
```yaml
routing:
  default_target: "CLC"  # Fallback if no strict_target/routing_hint
  supported_targets:
    - "CLC"
    - "GMX"
    - "LOCAL"
    - "KIM"
    - "PAULA"
  routing_hint_mapping:
    "dev_oss": "GMX"
    "dev_oss_lane": "CLC"
    "local_fix": "LOCAL"
    "trading": "PAULA"

directories:
  inbox: "bridge/inbox/MAIN"
  processed: "bridge/processed/MAIN"
  error: "bridge/error/MAIN"
  targets:
    CLC: "bridge/inbox/CLC"
    GMX: "bridge/inbox/GMX"
    LOCAL: "bridge/inbox/LOCAL"
    KIM: "bridge/inbox/KIM"
    PAULA: "bridge/inbox/PAULA"
    # Default pattern: bridge/inbox/{target} if not specified
```

---

### 2. **Code Changes**

**File:** `agents/mary_router/gateway_v3_router.py`

#### 2.1 Update Module Docstring

**From:**
```python
"""
Mary Router Gateway v3 - Central Inbox Router

Phase 0: Routes WOs from bridge/inbox/MAIN/ to bridge/inbox/CLC/
- Supports strict_target (priority)
- Supports routing_hint (fallback)
- Phase 0: Only CLC destination supported
"""
```

**To:**
```python
"""
Mary Router Gateway v3 - Central Inbox Router

Routes Work Orders from central inbox (bridge/inbox/MAIN/) to agent-specific inboxes.

Routing Priority:
1. strict_target (if present and valid)
2. routing_hint (mapped via config)
3. default_target (from config)

Phase 1: Multi-target routing (CLC, GMX, LOCAL, KIM, etc.)
"""
```

#### 2.2 Update `__init__` to Load Target Mapping

**Add after line 57:**
```python
# Target directory mapping
self.target_dir_map = self.config["directories"].get("targets", {})
```

#### 2.3 Update `process_wo()` to Use Target Mapping

**Find this line (around line 200-210):**
```python
target_inbox = ROOT / "bridge/inbox" / target
```

**Replace with:**
```python
# Use target mapping if available, fallback to default pattern
target_rel = self.target_dir_map.get(target, f"bridge/inbox/{target}")
target_inbox = ROOT / target_rel
target_inbox.mkdir(parents=True, exist_ok=True)
```

#### 2.4 Update `_default_config()` Method

**Update `routing` section:**
```python
"routing": {
    "default_target": "CLC",
    "supported_targets": ["CLC", "GMX", "LOCAL", "KIM", "PAULA"],  # Phase 1: Multi-target ready
    "routing_hint_mapping": {
        "dev_oss": "GMX",
        "dev_oss_lane": "CLC",
        "local_fix": "LOCAL",
        "trading": "PAULA"
    }
}
```

**Add `targets` to `directories`:**
```python
"directories": {
    "inbox": "bridge/inbox/MAIN",
    "processed": "bridge/processed/MAIN",
    "error": "bridge/error/MAIN",
    "targets": {
        "CLC": "bridge/inbox/CLC",
        "GMX": "bridge/inbox/GMX",
        "LOCAL": "bridge/inbox/LOCAL",
        "KIM": "bridge/inbox/KIM",
        "PAULA": "bridge/inbox/PAULA"
    }
}
```

---

### 3. **Comments & Documentation**

**Update all comments mentioning "Phase 0: CLC only" to reflect multi-target capability.**

**Files to update:**
- `agents/mary_router/gateway_v3_router.py` (module docstring, inline comments)
- `g/config/mary_router_gateway_v3.yaml` (remove "Phase 0: Only CLC" comments)

---

## ✅ **Implementation Checklist**

### Phase 1.1: Config Update
- [ ] Update `g/config/mary_router_gateway_v3.yaml`:
  - [ ] Add `GMX`, `LOCAL`, `KIM` to `supported_targets`
  - [ ] Add `routing_hint_mapping` entries for new targets
  - [ ] Add `directories.targets` mapping section
  - [ ] Remove "Phase 0: Only CLC" comments

### Phase 1.2: Code Changes
- [ ] Update module docstring (remove "Phase 0: CLC only")
- [ ] Add `self.target_dir_map` in `__init__`
- [ ] Update `process_wo()` to use target mapping
- [ ] Update `_default_config()` for multi-target
- [ ] Remove all "Phase 0: CLC only" comments

### Phase 1.3: Testing
- [ ] Test routing with `strict_target: GMX`
- [ ] Test routing with `routing_hint: local_fix` → LOCAL
- [ ] Test default routing (no strict_target/routing_hint) → CLC
- [ ] Verify target inbox directories created automatically
- [ ] Check telemetry logs for correct target tracking

### Phase 1.4: Documentation
- [ ] Update `g/reports/gateway_v3_wo_schema_20251206.md` (if needed)
- [ ] Update any SPEC/PLAN docs mentioning "CLC-only"
- [ ] Commit with message: `feat(mary-router): Phase 1 multi-target routing support`

---

## 📝 **Example Config (Phase 1)**

```yaml
version: "3.0"
phase: 1

routing:
  default_target: "CLC"
  supported_targets:
    - "CLC"
    - "GMX"
    - "LOCAL"
    - "KIM"
    - "PAULA"
  routing_hint_mapping:
    "dev_oss": "GMX"
    "dev_oss_lane": "CLC"
    "local_fix": "LOCAL"
    "trading": "PAULA"

telemetry:
  log_file: "g/telemetry/gateway_v3_router.log"
  log_level: "INFO"

directories:
  inbox: "bridge/inbox/MAIN"
  processed: "bridge/processed/MAIN"
  error: "bridge/error/MAIN"
  targets:
    CLC: "bridge/inbox/CLC"
    GMX: "bridge/inbox/GMX"
    LOCAL: "bridge/inbox/LOCAL"
    KIM: "bridge/inbox/KIM"
    PAULA: "bridge/inbox/PAULA"

worker:
  sleep_interval_seconds: 1.0
  process_one_by_one: true
```

---

## 🎯 **Expected Behavior After Phase 1**

1. **WO with `strict_target: GMX`** → Routes to `bridge/inbox/GMX/`
2. **WO with `routing_hint: local_fix`** → Routes to `bridge/inbox/LOCAL/`
3. **WO with no target/hint** → Routes to `bridge/inbox/CLC/` (default)
4. **WO with invalid target** → Moves to `bridge/error/MAIN/`
5. **Target inbox directories** → Created automatically if missing

---

## 🔄 **Backward Compatibility**

- ✅ Phase 0 configs still work (CLC-only)
- ✅ Default pattern `bridge/inbox/{target}` used if mapping missing
- ✅ Existing WOs continue to route correctly
- ✅ No breaking changes to WO schema

---

**Next Steps:**
1. Review this SPEC
2. Implement Phase 1.1-1.2 (Config + Code)
3. Test Phase 1.3
4. Update docs Phase 1.4
5. Deploy and verify
