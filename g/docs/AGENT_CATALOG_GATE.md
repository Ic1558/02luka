# Agent Catalog Gate — Single Source of Truth (Simplified)

**Date:** 2025-12-10  
**Purpose:** Prevent outdated info, misunderstanding, system lag  
**Authority:** System-wide rule for all agents/AI

---

## 🎯 Core Principle

**All agents must use `run_tool.zsh` wrapper for tool execution.**

This prevents:
- ❌ Outdated information
- ❌ Misunderstanding of tool locations
- ❌ System lag from wrong tool calls
- ❌ Breaking changes from memory-based assumptions

---

## 📋 Three Simple Rules

### Rule 1: Always Use run_tool.zsh Wrapper

**❌ FORBIDDEN:**
```bash
zsh tools/code_review_gate.zsh staged
./tools/save.sh
tools/spawn.zsh my-plugin
```

**✅ REQUIRED:**
```bash
zsh tools/run_tool.zsh code-review staged
zsh tools/run_tool.zsh save-now
zsh tools/run_tool.zsh spawn my-plugin "input"
```

### Rule 2: Tool IDs Must Be in catalog.yaml

- Every tool-id used must exist in `tools/catalog.yaml`
- `catalog_lookup.zsh` is the SOT for mapping: `<tool-id>` → `entry:`
- If tool not in catalog, `run_tool.zsh` will auto-discover (warn but allow)

### Rule 3: Code Review = Gate 2.5

In auto workflow:
```
DRYRUN → CODE-REVIEW (Gate 2.5) → VERIFY → [Gate 2]
```

**Usage:**
```bash
zsh tools/run_tool.zsh code-review staged --quick
```

---

## 🔧 How It Works

### run_tool.zsh Flow

1. **Catalog Lookup (Preferred)**
   - Query `catalog_lookup.zsh` for tool-id
   - Use `entry:` path from catalog
   - ✅ Fast, authoritative

2. **Auto-Discovery (Fallback)**
   - If not in catalog, try common patterns:
     - `tools/{tool-id}.zsh`
     - `tools/{tool-id}.sh`
     - `tools/{tool-id}_gate.zsh`
   - ⚠️ Warns but allows (prevents blocking/lag)

3. **Error (Last Resort)**
   - If not found anywhere, show helpful error
   - Suggest: add to catalog or check spelling

### Why Fallback?

**Problem:** If we block when tool not in catalog → agents lag/block

**Solution:** Auto-discovery with warning
- Allows tools not yet in catalog
- Warns to encourage catalog updates
- Prevents blocking/lag

---

## 📚 Catalog System

### Single Source of Truth
- **File:** `tools/catalog.yaml`
- **Query Tool:** `tools/catalog_lookup.zsh`
- **Wrapper:** `tools/run_tool.zsh`

### Catalog Scope

**Catalog = Curated "Official" Tools**
- Only tools that agents should use in workflow
- Not an index of every file in `tools/`
- Experimental/junk tools excluded

### Usage
```bash
# List available tools
zsh tools/catalog_lookup.zsh --list

# Lookup specific tool
zsh tools/catalog_lookup.zsh code-review

# Execute tool (always use wrapper)
zsh tools/run_tool.zsh code-review staged
```

---

## ✅ Success Criteria

1. **All agents use `run_tool.zsh`** for tool execution
2. **No direct tool calls** in code/docs (enforced by tests)
3. **Catalog integrity** validated (tests check entry → file exists)
4. **Fallback works** (no blocking when tool not in catalog)

---

## 📝 Examples

### Example 1: Code Review
```bash
# ❌ WRONG
zsh tools/code_review_gate.zsh staged

# ✅ CORRECT
zsh tools/run_tool.zsh code-review staged
```

### Example 2: Save Session
```bash
# ❌ WRONG
~/02luka/tools/save.sh

# ✅ CORRECT
zsh tools/run_tool.zsh save-now
```

### Example 3: Tool Not in Catalog (Fallback)
```bash
# Tool not yet in catalog
zsh tools/run_tool.zsh my-new-tool arg1

# Output:
# ⚠️  Tool 'my-new-tool' not in catalog, using fallback: /path/to/tools/my-new-tool.zsh
#    Suggestion: Add to tools/catalog.yaml
# [Tool executes successfully]
```

---

## 🧪 Tests

### Catalog Integrity Test
```bash
python3 tests/test_catalog_integrity.py
```
Checks: Every entry in catalog → file exists + executable

### No Direct Tool Calls Test
```bash
zsh tests/test_no_direct_tool_calls.sh
```
Checks: No `zsh tools/xxx.zsh` patterns (must use `run_tool.zsh`)

---

**Status:** ✅ **ACTIVE**  
**All agents must follow these 3 rules**
