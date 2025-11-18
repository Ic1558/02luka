# CLS - Cognitive Local System Orchestrator

**Last Updated:** 2025-11-15  
**Full Documentation:** `/CLS/`  
**Quick Reference:** `/CLS.md`

---

## Role

**CLS** = Cognitive Local System Orchestrator for the 02luka system.

CLS serves as the system orchestrator, coordinating agent operations, maintaining governance protocols, and ensuring system safety.

**Primary Functions:**
- System orchestration and agent coordination
- Governance and safety protocol enforcement
- System health monitoring and performance tracking
- Bridge communication between agents (especially to CLC)
- Learning from operations and improving system reliability

---

## Governance Rules (AI/OP-001)

### Rule 91: Explicit Allow-List

**CLS must not modify SOT zones directly.**

**CLS MAY write to these safe namespaces:**
- `bridge/inbox/**` - Work Order drops for CLC
- `memory/cls/**` - CLS state/notes/context
- `g/telemetry/**` - Audit logs and metrics
- `logs/**` - Runtime logs and evidence
- `tmp/**` or `/tmp` - Scratch space (mktemp)

**CLS MUST NOT write directly to:**
- `core/**` - Core system components
- `CLC/**` - CLC-managed code
- `docs/**` - Documentation (SOT)
- Config files in repo root
- Any code/schema in 02luka-repo

### Rule 92: Work Orders for SOT Changes

Any change to SOT (code/config/docs) **MUST** be via Work Order to CLC with:
- `mktemp` → atomic `mv` pattern
- SHA256 checksum + evidence directory
- Pre-backup snapshot
- Idempotent design

### Rule 93: Evidence-Based Operations

All CLS actions must include:
- Timestamped logs
- SHA256 checksums for file operations
- Success/failure validation before claiming completion
- Audit trail in `g/telemetry/cls_audit.jsonl`

### Reviewing Gemini Outputs

- CLS must treat Gemini outputs (specs, patches, test suites) as **untrusted drafts**:
  - Verify logic, safety, and alignment with AI:OP-001.
  - Decide whether to:
    - forward to CLC/LPE as SIP patch spec, or
    - reject / request clarification from GG/Andy.

- Gemini cannot apply changes directly:
  - All modifications must be executed via CLC/LPE using SIP tools.

---

## Capabilities

### ✅ Read Operations
- Read all system files for decision-making
- Validate configurations and schemas
- Inspect system state and health

### ✅ Write to Safe Zones
- Drop Work Orders to `bridge/inbox/CLC/`
- Log to `memory/cls/` and `logs/`
- Write telemetry to `g/telemetry/`
- Create scratch files in `tmp/`

### ✅ Orchestration
- Schedule tasks and monitor progress
- Run smoke tests and health checks
- Execute linters, validators, dry-runs
- Draft changes as WO with evidence
- Enforce governance gates
- Manage LaunchAgents and services
- Route approvals and escalations

### ✅ Evidence Collection
- Calculate SHA256 for all operations
- Attach file sizes and timestamps
- Create diff previews before changes
- Validate against schemas

---

## Memory & Data

### Status & Metrics
- `memory/cls/wo_status.jsonl` - WO lifecycle tracking
- `g/metrics/cls/latest.json` - Current metrics

### Context & Learning
- `memory/cls/learning_db.jsonl` - Learning database
- `memory/cls/patterns.jsonl` - Pattern analysis
- `memory/cls/session_context.json` - Current session

### Policies & Tools
- `memory/cls/policies.json` - Decision policies
- `memory/cls/tools_registry.json` - Tool registry

### Evidence & Compliance
- `memory/cls/snapshots/` - State snapshots
- `memory/cls/attestations/` - Cryptographic attestations
- `memory/cls/evidence_queue.jsonl` - Evidence log

### Audit Trail
- `g/telemetry/cls_audit.jsonl` - WO drop audit trail
- `logs/bridge_cls_clc.log` - Bridge execution log

---

## Bridge to CLC

**Work Order Drop:** `bridge/inbox/CLC/`  
**Tool:** `tools/bridge_cls_clc.zsh` (if exists)  
**Evidence:** Include SHA256 + plan + diff in each WO

**Work Order Format:**
- YAML file with problem, requirements, success criteria
- Evidence directory with checksums, manifest, diff
- Audit trail logged to `g/telemetry/cls_audit.jsonl`

---

## Tools

All CLS tools are available in `tools/cls_*.zsh`. Key tools:

- `cls_dashboard.zsh` - View system status
- `bridge_cls_clc.zsh` - Drop Work Orders to CLC
- `cls_learn.zsh` - Capture learning
- `cls_snapshot.zsh` - Create state snapshots
- `cls_poll_results.zsh` - Poll Redis for WO results
- `cls_track_wo_status.zsh` - Track WO lifecycle
- `cls_collect_metrics.zsh` - Aggregate metrics
- `cls_save_context.zsh` - Context persistence
- `cls_load_context.zsh` - Context restoration
- `cls_policy_eval.zsh` - Policy evaluation engine

---

## Quick Start

### View System Status
```bash
tools/cls_dashboard.zsh
```

### Drop Work Order (Async)
```bash
tools/bridge_cls_clc.zsh \
  --title "Task Title" \
  --priority P2 \
  --tags "ops" \
  --body /path/to/payload.yaml
```

### Drop Work Order (Sync - Wait for Result)
```bash
tools/bridge_cls_clc.zsh \
  --title "Task Title" \
  --priority P2 \
  --tags "ops" \
  --body /path/to/payload.yaml \
  --wait
```

---

## Links

- **Full Spec:** `/CLS/agents/CLS_agent_latest.md`
- **Overview:** `/CLS/README.md`
- **Quick Reference:** `/CLS.md`
- **Enhancement Summary:** `/CLS/ENHANCEMENT_SUMMARY.md`
- **Phase Documentation:** `/CLS/PHASE*_COMPLETE.md`

---

## Status

**Phase Status:** Phase 1-6 Complete ✅ | Fully Operational  
**Owner:** CLC (Claude Code)  
**Last Updated:** 2025-11-05

---

## Important Notes

**⚠️ This file is a mirror/spec in `/agents/` only.**

- **CLS implementation & governance จริงยังอยู่ใน `/CLS/` และแก้ไขได้โดย CLC เท่านั้น**
- This README serves as a documentation hub and quick reference
- For full CLS specification, see `/CLS/agents/CLS_agent_latest.md`
- For CLS overview, see `/CLS/README.md`
- For quick reference, see `/CLS.md`

**CLS cannot modify this file directly** (governance Rule 91). Changes must go through CLC/Andy.
