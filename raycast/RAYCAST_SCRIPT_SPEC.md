# Raycast Script Specification (Final - Cache-Proof)

**Date**: 2026-01-08  
**Status**: Production spec to prevent cache conflicts

---

## Script Architecture

### 1. Auto-Run Script (Primary)

**File**: `raycast/atg-snapshot-auto.command`

**Purpose**: One-key snapshot trigger (no user input)

**Header** (exact spec):
```bash
#!/usr/bin/env zsh
# @raycast.schemaVersion 1
# @raycast.title ATG Snapshot AUTO
# @raycast.mode silent
# @raycast.packageName 02luka
# @raycast.icon 🚀
# @raycast.description One-key snapshot → auto-run
# @raycast.needsConfirmation false
```

**Critical Rules**:
- ❌ NEVER add `@raycast.argument`
- ✅ Mode must be `silent` (no output window)
- ✅ No confirmation prompt

**Hotkey**: Control+A (^A)

**Behavior**: Press hotkey → runs immediately → no Enter required

---

## Next Steps

1. **In Raycast**: Settings → Extensions → Scripts → Reload
2. **Find**: "ATG Snapshot AUTO" (new script)
3. **Bind**: Control+A to this script
4. **Test**: Press Control+A → should run immediately

---

**Verification**: File renamed successfully ✅  
**No @raycast.argument**: Confirmed ✅
