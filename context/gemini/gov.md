# Governance Summary (02luka)

**Source of Truth**: `g/docs/GOVERNANCE_UNIFIED_v5.md`  
**Last Synced**: 2025-12-18  
**Version**: v5

---

## Two Worlds Model (CRITICAL)

The 02luka system operates in **two distinct layers**:

### Layer 1: CLI / Interactive World
- **Agents**: GMX, Codex CLI, Cursor, Antigravity, GG, GM (Gemini)
- **Governance**: **Advisory** (guidelines, not blockers)
- **Flexibility**: High - Boss has full control
- **Open Zones**: Can be written directly by CLI tools when Boss is present

### Layer 2: Background / Automated World
- **Agents**: Gateway v3, Router v5, SandboxGuard v5, WO Processor v5, CLC
- **Governance**: **Mandatory** (enforced by routing/guarding)
- **Flexibility**: Low - Must follow strict rules
- **Locked Zones**: Require WO/CLC lane per governance

## Core Components

### Gateway v3 Router
- **File**: `agents/mary_router/gateway_v3_router.py`
- **LaunchAgent**: `com.02luka.mary-gateway-v3`
- **Responsibilities**: Watch main inbox, dispatch WOs via v5 stack, emit telemetry
- **Config**: `g/config/mary_router_gateway_v3.yaml`

### Router v5
- **File**: `bridge/core/router_v5.py`
- **Purpose**: Lane + zone resolution
- **Lanes**: FAST / WARN / STRICT / BLOCKED
- **Zones**: OPEN / LOCKED / DANGER

### SandboxGuard v5
- **File**: `bridge/core/sandbox_guard_v5.py`
- **Purpose**: Path/content guard for filesystem and command safety
- **Enforces**: SIP requirements, traversal protection

### WO Processor v5
- **File**: `bridge/core/wo_processor_v5.py`
- **Purpose**: Lane execution engine
- **Behavior**: FAST/WARN → local, STRICT → CLC

## Lowercase Inbox Standard

- Canonical directories are **lowercase**: `main`, `clc`, `cls`, `entry`, `gemini`, etc.
- Uppercase names (e.g. `CLC`, `MAIN`, `GEMINI`) are **symlinks only**, never primary paths.

## Telemetry

- Canonical gateway telemetry: `g/telemetry/gateway_v3_router.jsonl` (NDJSON)
- Monitor tool: `tools/monitor_v5_production.zsh`

---

**For full details, see**: `g/docs/GOVERNANCE_UNIFIED_v5.md`
