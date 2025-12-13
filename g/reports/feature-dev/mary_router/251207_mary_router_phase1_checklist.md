# Mary Router Phase 1: Multi-Target Routing - Implementation Checklist

**Date:** 2025-12-07  
**Status:** Ready for Implementation

---

## 🎯 **Quick Reference**

**Goal:** Transform Mary Router from CLC-only to multi-target central dispatcher

**Key Changes:**
1. Config: Add `targets` mapping + multi-target `supported_targets`
2. Code: Use target mapping instead of hardcoded path
3. Comments: Remove "Phase 0: CLC only" mindset

---

## ✅ **Implementation Steps**

### Step 1: Update Config File

**File:** `g/config/mary_router_gateway_v3.yaml`

```bash
cd ~/02luka
# Backup current config
cp g/config/mary_router_gateway_v3.yaml g/config/mary_router_gateway_v3.yaml.phase0_backup

# Edit config (use draft from 251207_mary_router_phase1_config_draft.yaml)
```

**Changes:**
- [ ] Change `phase: 0` → `phase: 1`
- [ ] Add `GMX`, `LOCAL`, `KIM` to `supported_targets`
- [ ] Update `routing_hint_mapping` with multi-target examples
- [ ] Add `directories.targets` section
- [ ] Remove all "Phase 0: Only CLC" comments

---

### Step 2: Update Code - Module Docstring

**File:** `agents/mary_router/gateway_v3_router.py`

**Line 3-9:** Replace module docstring

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

- [ ] Update module docstring

---

### Step 3: Update Code - Add Target Mapping

**File:** `agents/mary_router/gateway_v3_router.py`

**After line 57** (after `self.default_target = ...`):

**Add:**
```python
# Target directory mapping (Phase 1: multi-target support)
self.target_dir_map = self.config["directories"].get("targets", {})
```

- [ ] Add `self.target_dir_map` initialization

---

### Step 4: Update Code - Use Target Mapping

**File:** `agents/mary_router/gateway_v3_router.py`

**Find:** `process_wo()` method, around line 200-210

**Find this line:**
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

- [ ] Update target path logic to use mapping

---

### Step 5: Update Code - Default Config

**File:** `agents/mary_router/gateway_v3_router.py`

**Method:** `_default_config()` (around line 76-99)

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

- [ ] Update `_default_config()` method

---

### Step 6: Remove Phase 0 Comments

**File:** `agents/mary_router/gateway_v3_router.py`

**Search for:**
- `"Phase 0: Only CLC"`
- `"Phase 0: CLC only"`
- `"Phase 0: Routes WOs from ... to CLC"`

**Replace/Remove:**
- [ ] Remove all Phase 0 CLC-only comments

---

### Step 7: Testing

**Test Cases:**

1. **Test strict_target routing:**
   ```bash
   # Create test WO
   cat > bridge/inbox/MAIN/WO-TEST-GMX.yaml <<EOF
   wo_id: "WO-TEST-GMX"
   title: "Test GMX routing"
   strict_target: "GMX"
   EOF
   
   # Wait 2 seconds, check routing
   sleep 2
   ls bridge/inbox/GMX/WO-TEST-GMX.yaml && echo "✅ GMX routing works"
   ```

2. **Test routing_hint:**
   ```bash
   cat > bridge/inbox/MAIN/WO-TEST-LOCAL.yaml <<EOF
   wo_id: "WO-TEST-LOCAL"
   title: "Test LOCAL routing"
   routing_hint: "local_fix"
   EOF
   
   sleep 2
   ls bridge/inbox/LOCAL/WO-TEST-LOCAL.yaml && echo "✅ LOCAL routing works"
   ```

3. **Test default routing:**
   ```bash
   cat > bridge/inbox/MAIN/WO-TEST-DEFAULT.yaml <<EOF
   wo_id: "WO-TEST-DEFAULT"
   title: "Test default routing"
   EOF
   
   sleep 2
   ls bridge/inbox/CLC/WO-TEST-DEFAULT.yaml && echo "✅ Default routing works"
   ```

4. **Test invalid target:**
   ```bash
   cat > bridge/inbox/MAIN/WO-TEST-INVALID.yaml <<EOF
   wo_id: "WO-TEST-INVALID"
   title: "Test invalid target"
   strict_target: "INVALID_AGENT"
   EOF
   
   sleep 2
   ls bridge/error/MAIN/WO-TEST-INVALID.yaml && echo "✅ Error handling works"
   ```

- [ ] Test strict_target routing
- [ ] Test routing_hint mapping
- [ ] Test default routing
- [ ] Test invalid target handling
- [ ] Verify target directories created automatically

---

### Step 8: Verify Logs

```bash
# Check Mary router log
tail -20 logs/launchd_mary_coo.out | grep -E "routing|target|GMX|LOCAL"

# Check telemetry (JSONL format - one JSON object per line)
tail -10 g/telemetry/gateway_v3_router.log | jq -r '.target_inbox // .target // empty'
```

- [ ] Verify logs show correct target routing
- [ ] Verify telemetry tracks targets correctly

---

### Step 9: Commit

```bash
cd ~/02luka
git add g/config/mary_router_gateway_v3.yaml
git add agents/mary_router/gateway_v3_router.py
git add g/reports/feature-dev/mary_router/
git commit -m "feat(mary-router): Phase 1 multi-target routing support

- Updated config: added targets mapping + multi-target support
- Code: use target mapping instead of hardcoded path
- Removed Phase 0 CLC-only comments
- Supports CLC, GMX, LOCAL, KIM, etc.

Co-Authored-By: Claude <noreply@anthropic.com>"
```

- [ ] Commit changes

---

## 🎯 **Success Criteria**

- ✅ Config supports multiple targets (CLC, GMX, LOCAL, KIM)
- ✅ Routing works for all supported targets
- ✅ Target directories created automatically
- ✅ Default routing still works (CLC)
- ✅ Invalid targets handled correctly (error/)
- ✅ No "Phase 0: CLC only" comments remain
- ✅ Telemetry tracks targets correctly

---

## 📝 **Notes**

- **Backward Compatible:** Phase 0 configs still work
- **Default Pattern:** `bridge/inbox/{target}` used if mapping missing
- **No Breaking Changes:** Existing WOs continue to route correctly

---

**Ready to implement?** Start with Step 1 (Config Update) → Step 2-6 (Code) → Step 7-8 (Test) → Step 9 (Commit)
