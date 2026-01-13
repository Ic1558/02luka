# ❌ ปัญหาหลัก: Agents ไม่เรียกผ่าน Catalog System

**วันที่**: 2026-01-08  
**สถานะ**: 🔴 Critical Issue  
**ผลกระทบ**: Data loss ระหว่าง push/pull/clean

---

## 🎯 Root Cause

**Agents ไม่ปฏิบัติตาม Catalog System** → เรียก tools โดยตรง → bypass metadata tracking → ข้อมูลหาย!

---

## 📚 ระบบที่มีอยู่แล้ว (แต่ไม่ได้ใช้)

### ✅ Catalog Infrastructure

| Component | Path | Status |
|-----------|------|--------|
| **Catalog Definition** | `tools/catalog.yaml` | ✅ มี save-now, seal-now |
| **Query Tool** | `tools/catalog_lookup.zsh` | ✅ ใช้งานได้ |
| **Wrapper** | `tools/run_tool.zsh` | ✅ มีอยู่ (3.5K) |
| **Documentation** | `g/docs/AGENT_CATALOG_GATE.md` | ✅ มี rules |

### ⚠️ Catalog Rules (ที่ agents ควรปฏิบัติ)

From `AGENT_CATALOG_GATE.md`:

**Rule 1**: ทุก agents ต้องใช้ `run_tool.zsh` wrapper  
**Rule 2**: Tool IDs ต้องมีใน `catalog.yaml`  
**Rule 3**: Never call tools directly

---

## ❌ ปัญหาที่เกิดขึ้นจริง

### Agents ยังเรียกแบบเก่า (Bypass Catalog):

```bash
# ❌ สิ่งที่ agents ทำ (ผิด)
./tools/save.sh
./tools/session_save.zsh
save-now  # alias โดยตรง
```

### ควรจะเป็น (ตาม catalog):

```bash
# ✅ สิ่งที่ควรทำ
cd ~/02luka && zsh tools/run_tool.zsh save-now
cd ~/02luka && zsh tools/run_tool.zsh seal-now
```

---

## 💥 ผลกระทบ

1. **ไม่ผ่าน gateway** → Missing agent context
2. **ไม่ได้ telemetry** → ไม่รู้ว่าใครเรียก
3. **Missing AGENT_ID** → Save ไม่ถูก attribute
4. **Partial atomicity** → MLS/telemetry อาจแยกกัน
5. **Data loss** → ข้อมูลหายระหว่าง git operations

---

## 🎓 ทำไมต้องใช้ Catalog?

From `catalog.yaml` line 18-22:

```yaml
save-now:
  entry: "./tools/save.sh"
  env: "AGENT_ID=<agent_name> SAVE_SOURCE=terminal"
  notes: "Uses save.sh as gateway, NOT session_save.zsh directly"
```

**Key Points**:
- ✅ Gateway enforced (`save.sh` not direct `session_save.zsh`)
- ✅ Environment variables set (`AGENT_ID`, `SAVE_SOURCE`)
- ✅ Consistent entry point
- ✅ Telemetry tracking

---

## 🛠️ Solution

### Option 1: Enforce Catalog Rules (Recommended)

**ทำให้ทุก agents ปฏิบัติตาม**:

1. **Update agent instructions** → Always use `run_tool.zsh`
2. **Test catalog wrapper** → Verify it works
3. **Monitor adoption** → Check telemetry for direct calls
4. **Add safeguards** → Prevent direct tool calls

**Example**:
```bash
# ใน Gemini persona/instructions
"When using tools, ALWAYS call via catalog:
  zsh tools/run_tool.zsh <tool-id> [args]
  
  NEVER call tools directly like:
  ./tools/xxx.sh (FORBIDDEN)"
```

---

### Option 2: Fix Direct Calls (Temporary)

**ถ้ายังไม่สามารถบังคับ catalog ได้**:

1. **Patch git_safety_aliases.zsh** → ให้เรียก `run_tool.zsh`
2. **Add AGENT_ID detection** → ใน `save.sh`
3. **Keep telemetry atomic** → ไม่แยก writers

---

## 📊 Catalog Entries (ปัจจุบัน)

From `catalog.yaml`:

```yaml
commands:
  save-now:
    description: "Lightweight session save from MLS ledger"
    entry: "./tools/save.sh"
    env: "AGENT_ID=<agent_name> SAVE_SOURCE=terminal"
    
  seal-now:
    description: "Full chain: Review → GitDrop → Save"
    entry: "./tools/workflow_dev_review_save.zsh"
    env: "GG_AGENT_ID=<agent_name>"
    
aliases:
  save: "save-now"
  seal: "seal-now"
```

**Problem**: Aliases bypass `run_tool.zsh` → ไม่ได้ env vars!

---

## ✅ Next Steps

1. **Test catalog wrapper**:
   ```bash
   cd ~/02luka
   zsh tools/run_tool.zsh save-now
   # ตรวจสอบว่า AGENT_ID ถูก set หรือไม่
   ```

2. **Update agent instructions**:
   - Add catalog enforcement to persona files
   - Update tooling.md context

3. **Add telemetry**:
   - Track whether calls go through `run_tool.zsh`
   - Alert on direct tool calls

4. **Validate**:
   - Run catalog integrity tests
   - Check that env vars propagate correctly

---

## 🎯 Success Criteria

- ✅ All agents use `run_tool.zsh` for save/seal
- ✅ AGENT_ID always set
- ✅ Telemetry shows catalog usage
- ✅ No data loss during git operations
- ✅ Atomic writes preserved

---

**Status**: 🔴 **CRITICAL** - Needs immediate enforcement  
**Priority**: P0 (Data Loss Prevention)  
**Owner**: All agents (enforcement required)
