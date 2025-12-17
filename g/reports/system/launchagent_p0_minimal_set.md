# P0 Minimal Set - Reality-Based Classification
**Generated:** 2025-12-18  
**Purpose:** Minimal P0 set based on actual execution surface

---

## 🔍 Execution Surface Analysis

### ✅ **Actually Running & Used Daily**
1. **Gateway v3** - Active routing (telemetry shows WO routing)
2. **CLC Executor** - Active execution (recently fixed, processing WOs)
3. **RAG API** - Active service (port 8765, responding)
4. **Memory Hub** - Active (running, has plist)
5. **MCP.fs** - Active (running)

### ❌ **Not Currently Active**
- **WO Pipeline** (json_wo_processor, wo_executor, followup_tracker, guardrail)
  - No telemetry/logs showing activity
  - WOs are processed directly by CLC executor
  - Gateway v3 routes directly to CLC inbox
  
- **Mary-dispatch, mary-bridge**
  - Gateway v3 handles routing directly
  - No evidence of mary-dispatch/bridge usage
  
- **MLS cursor watcher**
  - MLS lessons file exists (21KB)
  - But no evidence cursor watcher is actively running/recording
  
- **gg.mcp-bridge**
  - No evidence of active usage

---

## 🎯 **Recommended P0 Minimal Set**

### **P0 (Critical) - Must Be Running** (5 agents)

1. **`com.02luka.mary-gateway-v3`** (conditional)
   - **Why P0**: Active routing system, telemetry shows daily usage
   - **Evidence**: `g/telemetry/gateway_v3_router.jsonl` has recent entries
   - **Status**: Running (pid=36016)

2. **`com.02luka.clc-executor`**
   - **Why P0**: Executes work orders, recently fixed and verified
   - **Evidence**: Processing WOs from `bridge/inbox/CLC/`
   - **Status**: Running (pid=13817)

3. **`com.02luka.rag.api`**
   - **Why P0**: Active API service, recently fixed
   - **Evidence**: Responding on port 8765, 250 docs indexed
   - **Status**: Running (pid=10617)

4. **`com.02luka.memory.hub`** (conditional)
   - **Why P0**: Active memory system, has plist
   - **Evidence**: Running (pid=2332), plist exists
   - **Status**: Running (conditional - required if plist exists)

5. **`com.02luka.mcp.fs`**
   - **Why P0**: MCP filesystem bridge, currently running
   - **Evidence**: Running (pid=26393)
   - **Status**: Running

---

## 📋 **Move to Optional** (Previously P0, but not actively used)

### WO Pipeline → Optional
- `com.02luka.json_wo_processor` → **Optional**
- `com.02luka.wo_executor` → **Optional**
- `com.02luka.followup_tracker` → **Optional**
- `com.02luka.wo_pipeline_guardrail` → **Optional**
- `com.02luka.lpe.worker` → **Optional**

**Reason**: Gateway v3 + CLC executor handle WO processing directly. No evidence of pipeline usage.

### Mary Routing → Optional
- `com.02luka.mary-dispatch` → **Optional**
- `com.02luka.mary-bridge` → **Optional**

**Reason**: Gateway v3 handles routing. Mary-dispatch/bridge appear to be legacy.

### MLS → Optional
- `com.02luka.mls.cursor.watcher` → **Optional**
- `com.02luka.mls.ledger.monitor` → **Optional**

**Reason**: MLS lessons file exists but no evidence cursor watcher is actively recording.

### MCP → Optional
- `com.02luka.gg.mcp-bridge` → **Optional**

**Reason**: No evidence of active usage. MCP.fs is running but gg.mcp-bridge is not.

### CLC Backup → Optional
- `com.02luka.clc_local` → **Optional**

**Reason**: `clc-executor` is the active one. `clc_local` appears to be backup/alternative.

---

## 🚀 **Kickstart Sequence (Safe Order)**

### Phase 1: Verify Current P0 (No Action Needed)
All 5 P0 agents are already running. ✅

### Phase 2: Update Priority List
1. Move WO pipeline agents → Optional
2. Move mary-dispatch/bridge → Optional
3. Move MLS watchers → Optional
4. Move gg.mcp-bridge → Optional
5. Move clc_local → Optional

### Phase 3: Re-run Status Check
```bash
python3 g/tools/launchagent_status.py
```
Expected: **GREEN** (all 5 P0 running)

---

## 📊 **Updated Priority List Structure**

```markdown
## P0 (Critical) - Must Be Running

### Core Execution
- `com.02luka.mary-gateway-v3` - Gateway v3 router (if deployed)
- `com.02luka.clc-executor` - Executes CLC work orders
- `com.02luka.rag.api` - RAG API server
- `com.02luka.memory.hub` - Memory hub (if using shared memory system)
- `com.02luka.mcp.fs` - MCP filesystem bridge

## Optional - Nice to Have Running

### WO Pipeline (Legacy/Alternative)
- `com.02luka.json_wo_processor` - Parses WO files (alternative to direct CLC)
- `com.02luka.wo_executor` - Runs work orders (alternative to CLC executor)
- `com.02luka.followup_tracker` - Computes derived metadata
- `com.02luka.wo_pipeline_guardrail` - Validates WO pipeline health
- `com.02luka.lpe.worker` - Local Patch Engine worker

### Routing (Legacy)
- `com.02luka.mary-dispatch` - Routes work orders (legacy, gateway-v3 replaces)
- `com.02luka.mary-bridge` - Bridge for Mary routing (legacy)

### MLS (Optional Enhancement)
- `com.02luka.mls.cursor.watcher` - Monitors Cursor IDE for prompts
- `com.02luka.mls.ledger.monitor` - Monitors MLS ledger health

### MCP (Optional)
- `com.02luka.gg.mcp-bridge` - MCP bridge routes tasks to GG

### CLC (Backup)
- `com.02luka.clc_local` - Local CLC executor (backup/alternative)
```

---

## ✅ **Verification Checklist**

After updating `launchagent_priority_list.md`:

- [ ] Run `python3 g/tools/launchagent_status.py`
- [ ] Verify overall status = **GREEN**
- [ ] Verify P0 count = 5
- [ ] Verify all 5 P0 agents show `running`
- [ ] Verify moved agents show in Optional section
- [ ] Test dashboard integration (if applicable)

---

## 🎯 **Expected Result**

**Before**: RED (16 P0, 4 running)  
**After**: GREEN (5 P0, 5 running)

This reflects the **actual execution surface** rather than aspirational architecture.
