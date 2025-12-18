# Persona Model v5 — Capability Matrix & Forbidden Behaviors

**Status**: WIRED (referenced by Router v5, SandboxGuard v5)  
**Scope**: All 13 actors across CLI and BACKGROUND worlds  
**Version**: v5 (aligned with Governance v5)  
**Last Updated**: 2025-12-18

---

## 1. Purpose

This document defines the **system-wide capability matrix** and **forbidden behaviors** for all actors in the 02luka system. It serves as the single source of truth for:

- **Router v5**: Determines which actors can write in which zones/worlds (Section 3)
- **SandboxGuard v5**: Enforces forbidden behaviors and zone restrictions (Section 5)

**Note**: This is a **capability model** (what can/cannot do), not an agent-specific persona (how to behave). For agent-specific personas, see `personas/*_PERSONA_v3.md`.

---

## 2. Actor Definitions

The 02luka system recognizes **13 actors**:

### 2.1 CLI World Actors (7)
- **Boss** - Human operator (full override)
- **CLS** - System Orchestrator / Router
- **Liam** - Explorer & Planner
- **GMX** - CLI Worker
- **Codex** - IDE Assistant
- **Gemini** - Operational Worker
- **LAC** - Auto-Coder

### 2.2 Background World Actors (6)
- **GG** - Co-Orchestrator (planner)
- **GM** - Co-Orchestrator with GG (planner)
- **Mary** - Traffic / Safety Router
- **CLC** - Locked-zone Executor
- **LPE** - Emergency Patcher
- **Cron** - Scheduled Tasks
- **Watchdog** - System Monitor

---

## 3. Capability Matrix

### 3.1 CLI World Write Capabilities

**Rule**: In CLI world, actors can write directly if they are in the CLI writers list.

#### CLI Writers (Can Write in CLI World)
- ✅ **Boss** - Full override (all zones, with confirmations)
- ✅ **CLS** - System orchestrator (with auto-approve conditions)
- ✅ **Liam** - Explorer & planner (OPEN zones)
- ✅ **GMX** - CLI worker (OPEN zones)
- ✅ **Codex** - IDE assistant (OPEN zones)
- ✅ **Gemini** - Operational worker (OPEN zones)
- ✅ **LAC** - Auto-coder (OPEN zones)

**Implementation** (from `router_v5.py:401`):
```python
cli_writers = ["Boss", "CLS", "Liam", "GMX", "Codex", "Gemini", "LAC"]
```

#### CLI Non-Writers (Cannot Write in CLI World)
- ❌ **GG** - Planner only (cannot write)
- ❌ **GM** - Planner only (cannot write)
- ❌ **Mary** - Router only (cannot write)
- ❌ **CLC** - Background actor (sleeps in CLI)
- ❌ **LPE** - Background actor (sleeps in CLI)
- ❌ **Cron** - Background actor (sleeps in CLI)
- ❌ **Watchdog** - Background actor (sleeps in CLI)

**Implementation** (from `router_v5.py:405-415`):
```python
# Planners cannot write
if actor in ["GG", "GM"]:
    return None

# Router cannot write
if actor == "Mary":
    return None

# Background actors sleep in CLI
if actor in ["CLC", "LPE"]:
    return None
```

### 3.2 BACKGROUND World Write Capabilities

**Rule**: In BACKGROUND world, only CLC (or LPE in emergency) can write.

#### BACKGROUND Writers
- ✅ **CLC** - Primary executor for LOCKED zone operations
- ✅ **LPE** - Emergency patcher (rare, requires explicit authorization)

**Implementation** (from `router_v5.py:395-396`):
```python
if world == "BACKGROUND":
    # Background world → CLC (or LPE in emergency)
    return "CLC"
```

#### BACKGROUND Non-Writers
- ❌ All other actors must create Work Orders (WO) for BACKGROUND operations

### 3.3 Zone-Based Capabilities

#### OPEN Zone
- **CLI Writers**: ✅ Can write directly
- **Background**: ✅ Allowed with WO (routed to CLC)

#### LOCKED Zone
- **Boss**: ✅ Override allowed
- **CLS**: ✅ Auto-approve (if mission scope + safety conditions) OR Boss/CLS authorization
- **Background**: ✅ Requires WO → CLC
- **Other CLI Writers**: ❌ Must create WO or get Boss/CLS override

#### DANGER Zone
- **Boss**: ✅ Only with explicit confirmation (`boss_confirmed_danger`)
- **All Others**: ❌ Hard block (never allowed)

---

## 4. Actor Role Matrix

| Actor | World | Write Capability | Zone Restrictions | Notes |
|-------|-------|------------------|-------------------|-------|
| **Boss** | CLI | ✅ Full override | DANGER requires explicit confirmation | Human operator |
| **CLS** | CLI | ✅ With auto-approve or authorization | LOCKED: auto-approve if mission scope | System orchestrator |
| **Liam** | CLI | ✅ OPEN zones | LOCKED/DANGER: Must create WO | Explorer & planner |
| **GMX** | CLI | ✅ OPEN zones | LOCKED/DANGER: Must create WO | CLI worker |
| **Codex** | CLI | ✅ OPEN zones | LOCKED/DANGER: Must create WO | IDE assistant |
| **Gemini** | CLI | ✅ OPEN zones | LOCKED/DANGER: Must create WO | Operational worker |
| **LAC** | CLI | ✅ OPEN zones | LOCKED/DANGER: Must create WO | Auto-coder |
| **GG** | CLI | ❌ Cannot write | N/A | Planner only |
| **GM** | CLI | ❌ Cannot write | N/A | Planner only |
| **Mary** | CLI | ❌ Cannot write | N/A | Router only |
| **CLC** | BACKGROUND | ✅ LOCKED zones (via WO) | OPEN: Allowed with WO | Locked-zone executor |
| **LPE** | BACKGROUND | ✅ Emergency only | Requires explicit authorization | Emergency patcher |
| **Cron** | BACKGROUND | ❌ Must create WO | N/A | Scheduled tasks |
| **Watchdog** | BACKGROUND | ❌ Must create WO | N/A | System monitor |

---

## 5. Forbidden Behaviors

### 5.1 DANGER Zone Restrictions

**Rule**: DANGER zone operations are **hard-blocked** for all actors except Boss with explicit confirmation.

#### Forbidden
- ❌ Any actor (except Boss) attempting DANGER zone write
- ❌ Boss attempting DANGER zone write without explicit confirmation
- ❌ Path traversal patterns (`../`, `..\`, mixed traversal)
- ❌ Null-byte or newline injection in paths
- ❌ System paths outside `~/02luka` (unless explicitly whitelisted)

#### Allowed (Exception)
- ✅ Boss with `boss_confirmed_danger=True` in context

**Implementation** (from `sandbox_guard_v5.py:448-452`):
```python
if zone == "DANGER":
    if actor == "Boss" and context and context.get("boss_confirmed_danger"):
        return (True, None, "Boss explicitly confirmed DANGER zone operation")
    return (False, SecurityViolation.DANGER_ZONE_WRITE, "DANGER zone write requires Boss explicit confirmation")
```

### 5.2 LOCKED Zone Restrictions

**Rule**: LOCKED zone operations require authorization or Work Order.

#### Forbidden
- ❌ CLI writers (except Boss/CLS) writing directly to LOCKED zones
- ❌ Background actors writing to LOCKED zones without WO
- ❌ Unauthorized modifications to governance files
- ❌ Unauthorized modifications to core bridge/router code

#### Allowed (Exceptions)
- ✅ Boss override (always allowed)
- ✅ CLS auto-approve (if mission scope whitelist + safety conditions)
- ✅ CLS with Boss/CLS authorization (`boss_cls_authorized=True`)
- ✅ Background world with WO (`wo_id` present) → routed to CLC

**Implementation** (from `sandbox_guard_v5.py:454-471`):
```python
if zone == "LOCKED":
    if actor == "Boss":
        return (True, None, "Boss override allowed for LOCKED zone")
    
    if actor == "CLS":
        if context and context.get("cls_auto_approve_allowed"):
            return (True, None, "CLS auto-approve allowed (Mission Scope + safety conditions)")
        if context and context.get("boss_cls_authorized"):
            return (True, None, "Boss/CLS authorized LOCKED zone write")
    
    if context and context.get("wo_id"):
        return (True, None, "Background world with WO → CLC")
    
    return (False, SecurityViolation.LOCKED_ZONE_NO_AUTH, "LOCKED zone requires Boss/CLS authorization or WO")
```

### 5.3 OPEN Zone Restrictions

**Rule**: OPEN zone operations are allowed for CLI writers, with audit for background operations.

#### Forbidden
- ❌ Non-CLI writers attempting direct write (must create WO)
- ❌ Background operations without WO (should be routed)

#### Allowed
- ✅ CLI writers (Boss, CLS, Liam, GMX, Codex, Gemini, LAC)
- ✅ Background operations with WO (audited)

**Implementation** (from `sandbox_guard_v5.py:473-483`):
```python
if zone == "OPEN":
    cli_writers = ["Boss", "CLS", "Liam", "GMX", "Codex", "Gemini", "LAC"]
    if actor in cli_writers:
        return (True, None, "OPEN zone write allowed for CLI writer")
    
    if context and context.get("wo_id"):
        return (True, None, "OPEN zone write allowed with WO (background)")
```

### 5.4 General Forbidden Behaviors

#### Path Safety
- ❌ Path traversal outside repository (`../` escaping `~/02luka`)
- ❌ Accessing system paths (`/System/`, `/usr/`, `/etc/`, `/bin/`, `~/.ssh/`)
- ❌ Null-byte or newline injection in file paths
- ❌ Symlink following to dangerous locations

#### Operation Safety
- ❌ Destructive operations without confirmation (delete, move, exec)
- ❌ Bypassing SandboxGuard checks
- ❌ Modifying governance files without proper authorization
- ❌ Creating uppercase inbox directories (must use lowercase)

#### Actor Safety
- ❌ CLI actors attempting BACKGROUND world operations directly
- ❌ Background actors attempting CLI world operations
- ❌ Planners (GG, GM) attempting write operations
- ❌ Router (Mary) attempting write operations

---

## 6. CLS Auto-Approve Conditions

**Reference**: PR-10 (CLS Auto-Approve Semantics)

CLS can auto-approve LOCKED zone operations when **ALL** conditions are met:

1. ✅ Actor is CLS
2. ✅ Zone is LOCKED
3. ✅ Path is in Mission Scope Whitelist
4. ✅ No DANGER patterns matched
5. ✅ No privileged paths (e.g., governance core, bridge core)

**Result**: CLS request routed to `FAST` lane (not `STRICT`)

**Implementation** (from `router_v5.py:294-333`):
```python
def check_cls_auto_approve_conditions(actor, zone, path_str, context):
    if actor != "CLS" or zone != "LOCKED":
        return (False, {})
    
    # Check mission scope whitelist
    is_whitelisted = check_mission_scope_whitelist(path_str)
    
    conditions = {
        "actor_is_cls": actor == "CLS",
        "zone_is_locked": zone == "LOCKED",
        "path_in_whitelist": is_whitelisted,
        # ... other safety checks
    }
    
    can_auto_approve = all(conditions.values())
    return (can_auto_approve, conditions)
```

---

## 7. References

### Governance Documents
- `g/docs/GOVERNANCE_UNIFIED_v5.md` - Main governance document
- `g/docs/AI_OP_001_v5.md` - Operational protocol (BACKGROUND world)
- `g/docs/HOWTO_TWO_WORLDS_v2.md` - CLI world guide

### Implementation Code
- `bridge/core/router_v5.py` - Routing engine (references Section 3)
- `bridge/core/sandbox_guard_v5.py` - Security guard (references Section 5)

### Agent Personas
- `personas/*_PERSONA_v3.md` - Agent-specific behavioral contracts

---

## 8. Version History

- **v5.0 (2025-12-18)**: Initial restoration from code logic
  - Extracted capability matrix from `router_v5.py`
  - Extracted forbidden behaviors from `sandbox_guard_v5.py`
  - Documented all 13 actors and their capabilities
  - Aligned with Governance v5 and PR-10 semantics

---

**Status**: ✅ Restored and WIRED  
**Maintained By**: Governance v5 team  
**Last Verified**: 2025-12-18
