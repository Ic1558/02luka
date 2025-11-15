# CLC - Privileged Patcher

**Last Updated:** 2025-11-15  
**Status:** Privileged Operations Agent

---

## Role

**CLC** = Claude Code Agent / Privileged Patcher

CLC is the privileged agent responsible for:
- SOT (Source of Truth) modifications
- Governance changes
- Privileged execution
- Work Order processing from CLS
- SIP (System Integrity Protection) patches
- Safe zone modifications

---

## Capabilities

### Privileged Operations
- **Write to SOT zones:** `core/`, `CLC/`, `docs/`, config files, governance files
- **Process Work Orders:** Receive and execute Work Orders from CLS
- **Execute governance changes:** Modify system protocols and governance rules
- **Handle SIP patches:** Apply System Integrity Protection patches safely
- **Migrations:** Execute system migrations and upgrades
- **Safe execution context:** Run in isolated, safe execution environment

### Work Order Processing
- **Receive Work Orders:** From `bridge/inbox/CLC/`
- **Validate evidence:** SHA256 checksums, manifest, diff previews
- **Atomic operations:** `mktemp` → atomic `mv` pattern
- **Pre-backup snapshots:** Create backups before changes
- **Idempotent design:** Safe to re-run operations
- **Return results:** Via Redis or file system

---

## Governance

**CLC is the only agent that can modify SOT zones directly.**

All other agents (including CLS) must use Work Orders to request CLC to make SOT changes.

**Work Order Requirements:**
- `mktemp` → atomic `mv` pattern
- SHA256 checksum + evidence directory
- Pre-backup snapshot
- Idempotent design
- Evidence validation before execution

**Prohibited Zones (for other agents, not CLC):**
- `/CLC/**` - CLC-managed code
- `/core/governance/**` - Core governance
- `02luka Master System Protocol` files
- `memory_center/**` - Memory center
- `launchd/**` - LaunchAgents
- `production bridges/**` - Production bridges
- `wo pipeline core/**` - WO pipeline core

---

## Relationship to CLS

CLS delegates SOT changes to CLC via Work Orders:

1. **CLS creates Work Order** with evidence (SHA256, manifest, diff)
2. **Drops to** `bridge/inbox/CLC/`
3. **CLC processes Work Order** with validation
4. **Returns results** to CLS via Redis or file system
5. **Audit trail** logged to `g/telemetry/cls_audit.jsonl`

**Bridge Tool:** `tools/bridge_cls_clc.zsh` (used by CLS to drop Work Orders)

---

## Execution Context

CLC operates in a **safe execution context**:
- Isolated execution environment
- Privileged access to SOT zones
- SIP patch support
- Atomic operation guarantees
- Evidence-based validation

---

## Links

- **Agent System Index:** `/agents/README.md`
- **CLS Documentation:** `/agents/cls/README.md`
- **Bridge Inbox:** `bridge/inbox/CLC/`
- **Audit Trail:** `g/telemetry/cls_audit.jsonl`

---

**Note:** CLC implementation details are in `/CLC/**` (not to be modified by other agents).
