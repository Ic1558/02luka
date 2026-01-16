# Phase 1: Cursor SQLite Schema Investigation Report

**Date:** 2025-11-13  
**Status:** ✅ Investigation Complete

## Findings

### Database Location
- **Path:** `~/Library/Application Support/Cursor/User/workspaceStorage/{hash}/state.vscdb`
- **Target DB:** `028075471bf4d7f39dc0a2b40a669a01/state.vscdb` (most recent)

### Schema Structure

**Tables:**
1. `ItemTable` - Main storage (key-value pairs)
   - `key` (TEXT)
   - `value` (BLOB/JSON)

2. `cursorDiskKV` - Empty (not used)

### Key Findings

**1. Composer Metadata: `composer.composerData`**
- Contains `allComposers` array (23 composers found)
- Each composer has:
  - `composerId` (UUID)
  - `name` (conversation title)
  - `createdAt` (timestamp)
  - `lastUpdatedAt` (timestamp)
  - `subtitle` (file names)
  - Metadata (lines added/removed, files changed, etc.)
- **Does NOT contain actual messages/prompts**

**2. Potential Message Storage:**
- `aiService.prompts` - Found, needs investigation
- `workbench.panel.composerChatViewPane.*` - Found, needs investigation

### Workspace Detection

**Challenge:** Multiple workspace directories exist (16 found)
**Current Approach:** Using most recent `state.vscdb` as fallback
**Issue:** Cannot reliably identify which workspace is `~/02luka`

**Possible Solutions:**
1. Check workspace.json files (if they exist)
2. Query database for path references
3. Use file modification time (current approach)

## Next Steps

1. ✅ Schema discovered
2. ⏳ Investigate `aiService.prompts` and `composerChatViewPane` for actual messages
3. ⏳ Implement workspace detection logic
4. ⏳ Test conversation extraction

## Phase 1.5 Decision Criteria

**If messages found in:**
- ✅ `aiService.prompts` or `composerChatViewPane` → Proceed Option A
- ❌ Messages not accessible → Pivot Option C (Session Summary)


## Update: Found Prompts Storage

**Key:** `aiService.prompts`
- **Type:** JSON array
- **Structure:** Each entry contains:
  - `text` - The actual prompt text
  - `commandType` - Type of command (e.g., 4)
- **Size:** ~4MB (3969668 bytes)
- **Contains:** All prompts entered by user

**Finding:** Prompts are stored, but responses may be stored separately or not persisted.

## Phase 1.5 Decision

**Status:** ✅ **PROCEED WITH OPTION A**

**Rationale:**
- ✅ Prompts are accessible via `aiService.prompts`
- ✅ Can extract prompts with timestamps (via composer metadata)
- ✅ Can track new prompts by comparing array length/timestamps
- ⚠️ Responses may not be stored (need to investigate further)

**Next Steps:**
1. Extract prompts from `aiService.prompts`
2. Match prompts to composers via timestamps
3. Record prompts to MLS Ledger (even without responses)
4. Investigate response storage separately

