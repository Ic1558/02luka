# V4 Writer Policy Extensions

**Version**: V4  
**Date**: 2025-11-21  
**Owner**: Liam  
**Type**: Policy Extension (extends V3.5)

---

## Overview

V4 extends the V3.5 Writer Policy with two new protected zones for memory and contract management.

---

## New Zones (V4)

| Zone | Paths | Write Allowed | Purpose | Enforcement |
|------|-------|---------------|---------|-------------|
| **memory-write** | `g/memory/ledger/**` | ✅ Via Memory Hub only | Agent memory ledgers | FDE Validator |
| **contract-write** | `g/core/fde/**`, `agents/*/PERSONA_PROMPT.md` | ✅ Via approved processes only | FDE rules, persona contracts | FDE Validator |

---

## Updated Writer Roles (V4)

| Agent | Memory Zone | Contract Zone | Notes |
|-------|-------------|---------------|-------|
| **Memory Hub** | ✅ Write | ❌ No | Only component that writes to `g/memory/ledger/**` |
| **Liam** | ❌ No (via Hub) | ✅ Limited | Can update own persona, FDE rules via approved process |
| **GMX** | ❌ No (via Hub) | ❌ No | Planning only |
| **Hybrid** | ❌ No | ❌ No | Executes code, not governance |

---

## Enforcement

V4 zones are enforced by:
1. **FDE Validator** (`g/core/fde/fde_validator.py`) - Pre-execution validation
2. **Memory Hub API** (`agents/memory_hub/memory_hub.py`) - Controlled access to memory ledgers
3. **AP/IO Events** (`g/tools/ap_io_events.py`) - All memory/contract operations logged

---

## V4 Events

New AP/IO events for V4 zones:
- `v4_memory_loaded` - Memory read from ledger
- `v4_memory_saved` - Memory written to ledger
- `v4_fde_validation_passed` - FDE check passed
- `v4_fde_validation_failed` - FDE check blocked action
- `v4_persona_migrated` - Persona contract updated

---

**Status**: ✅ V4 ZONES DEFINED
