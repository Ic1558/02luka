# CLC - Claude Code Agent

**Last Updated:** 2025-11-15  
**Status:** Documentation Placeholder

---

## Role

**CLC** = Claude Code Agent

CLC is the privileged agent responsible for:
- SOT (Source of Truth) modifications
- Governance changes
- Privileged execution
- Work Order processing from CLS

---

## Capabilities

### Privileged Operations
- Write to SOT zones (`core/`, `CLC/`, `docs/`, config files)
- Process Work Orders from CLS
- Execute governance changes
- Handle SIP patches and migrations

### Work Order Processing
- Receive Work Orders from `bridge/inbox/CLC/`
- Validate evidence (SHA256, manifest, diff)
- Execute changes with atomic operations
- Return results via Redis or file system

---

## Governance

CLC is the only agent that can modify SOT zones directly. All other agents (including CLS) must use Work Orders to request CLC to make SOT changes.

**Work Order Requirements:**
- `mktemp` → atomic `mv` pattern
- SHA256 checksum + evidence directory
- Pre-backup snapshot
- Idempotent design

---

## Relationship to CLS

CLS delegates SOT changes to CLC via Work Orders:
- CLS creates Work Order with evidence
- Drops to `bridge/inbox/CLC/`
- CLC processes Work Order
- Returns results to CLS

---

## Links

- **Agent System Index:** `/agents/README.md`
- **CLS Documentation:** `/agents/cls/README.md`

---

**Note:** This is a placeholder. Full CLC documentation TBD.
