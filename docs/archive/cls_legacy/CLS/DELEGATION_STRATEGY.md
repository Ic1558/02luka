# CLS Enhancement Roadmap - Delegation Strategy

**Owner:** CLC (Claude Code)
**Delegate:** CLS (Cognitive Local System) in Cursor
**Status:** Phase 1-2 complete, Phase 3-6 delegated
**Date:** 2025-10-30

---

## Executive Summary

**Delegation Principle:** CLC provides architectural guidance and creates foundational infrastructure. CLS executes implementation within allow-list zones, escalating to CLC via Work Orders when SOT access needed.

**Why Delegation Works:**
- **CLS Strengths:** Host access, filesystem operations, Cursor integration, rapid iteration
- **CLC Strengths:** Architecture design, SOT governance, complex analysis, cross-system coordination
- **Cost Efficiency:** Local agents (free) → Ollama (free) → CLC (expensive)

---

## Delegation Model

### Decision Matrix

| Task Type | Owner | Rationale |
|-----------|-------|-----------|
| Architecture design | CLC | Requires system-wide view, governance knowledge |
| Tool creation | CLS | Host access needed, can write to allow-list zones |
| Testing & iteration | CLS | Fast feedback loop, host environment |
| SOT modifications | CLC | Governance requirement (AI/OP-001 Rule 92) |
| Documentation | CLS | Can write to allow-list zones |
| Integration work | Both | CLS implements, CLC reviews and integrates |

### Allow-List Zones (CLS Can Write)

```
✅ bridge/inbox/**        # WO drops to CLC
✅ memory/cls/**          # CLS state, notes, context
✅ g/telemetry/**         # Audit logs, metrics
✅ logs/**                # System logs
✅ tmp/**                 # Temporary files
✅ /tmp/**                # System temp

❌ Everything else requires WO to CLC
```

---

## Phase 3: Context Management (DELEGATED TO CLS)

### Overview
**Impact:** High
**Complexity:** Medium
**CLS Capability:** ✅ Can execute autonomously

### Tasks for CLS

#### 3.1: Learning Database
**Goal:** Store and retrieve learned patterns

**Implementation:**
```bash
# Create learning database
~/02luka/memory/cls/learning_db.jsonl

# Schema:
{
  "pattern_id": "uuid",
  "category": "error_handling|optimization|workflow",
  "description": "What was learned",
  "context": {
    "wo_id": "WO-*",
    "timestamp": "ISO8601",
    "tags": []
  },
  "outcome": "success|failure",
  "confidence": 0.0-1.0
}
```

**Script:** `~/tools/cls_learn.zsh`
```zsh
#!/usr/bin/env zsh
# Usage: cls_learn.zsh --category "error_handling" --description "..."
```

**Test:**
```bash
cls_learn.zsh \
  --category "optimization" \
  --description "Pre-validate file paths before WO drop reduces errors by 40%"
```

---

#### 3.2: Pattern Recognition
**Goal:** Identify repeated tasks and suggest automation

**Implementation:**
```bash
# Create pattern detector
~/tools/cls_detect_patterns.zsh

# Analyzes:
# - WO titles for repeated phrases
# - Tag combinations that recur
# - Time-based patterns (e.g., daily tasks)
```

**Output:**
```json
{
  "pattern": "daily_backup",
  "occurrences": 15,
  "last_seen": "2025-10-30T05:00:00Z",
  "suggestion": "Create cron job for automated daily backup WO"
}
```

---

#### 3.3: Context Memory
**Goal:** Persist context between Cursor sessions

**Implementation:**
```bash
# Session context storage
~/02luka/memory/cls/session_context.json

# Schema:
{
  "session_id": "uuid",
  "started_at": "ISO8601",
  "current_focus": "what CLS is working on",
  "open_wos": ["WO-*", ...],
  "notes": "markdown notes for next session",
  "deferred_tasks": []
}
```

**Script:** `~/tools/cls_save_context.zsh`, `~/tools/cls_load_context.zsh`

**Cursor Integration:**
Update `.cursorrules` to auto-load context on session start.

---

### Deliverables for Phase 3
1. ✅ `~/tools/cls_learn.zsh` - Learning capture tool
2. ✅ `~/tools/cls_detect_patterns.zsh` - Pattern recognition
3. ✅ `~/tools/cls_save_context.zsh` - Context persistence
4. ✅ `~/tools/cls_load_context.zsh` - Context restoration
5. ✅ `~/02luka/memory/cls/learning_db.jsonl` - Learning database
6. ✅ `~/02luka/memory/cls/session_context.json` - Session context
7. ✅ Phase 3 documentation in `~/02luka/CLS/PHASE3_COMPLETE.md`

**Escalation to CLC:** None needed - all work within allow-list zones

---

## Phase 4: Advanced Decision-Making (DELEGATED TO CLS)

### Overview
**Impact:** Medium
**Complexity:** Medium-High
**CLS Capability:** ⚠️ Partial - policy engine within allow-list, approval workflows may need CLC

### Tasks for CLS

#### 4.1: Policy Engine
**Goal:** Auto-approve routine tasks based on rules

**Implementation:**
```bash
# Policy rules database
~/02luka/memory/cls/policies.yaml

# Schema:
policies:
  - name: "auto_approve_low_risk"
    conditions:
      - priority: "P3"
      - tags: ["test", "sandbox"]
    actions:
      - auto_approve: true
      - notify: false

  - name: "require_approval_prod"
    conditions:
      - tags: ["production"]
    actions:
      - require_approval: true
      - notify: "telegram"
```

**Script:** `~/tools/cls_evaluate_policy.zsh`
```zsh
#!/usr/bin/env zsh
# Returns: approve|deny|escalate
```

---

#### 4.2: Approval Workflows
**Goal:** Route complex decisions to appropriate approvers

**Implementation:**
```bash
# Approval tracking
~/02luka/memory/cls/approvals.jsonl

# Schema:
{
  "approval_id": "uuid",
  "wo_id": "WO-*",
  "requested_at": "ISO8601",
  "status": "pending|approved|denied",
  "approver": "user|CLC|auto",
  "reason": "..."
}
```

**Escalation Point:** ⚠️ May require CLC integration for Telegram notifications

---

#### 4.3: Confidence Scoring
**Goal:** CLS rates its confidence in decisions

**Implementation:**
```bash
# Add to WO metadata
{
  "wo_id": "WO-*",
  "confidence": {
    "score": 0.85,  # 0.0-1.0
    "factors": [
      "similar_task_succeeded_10x",
      "clear_rollback_path",
      "non_production_environment"
    ],
    "recommendation": "auto_approve|manual_review"
  }
}
```

**Script:** `~/tools/cls_calculate_confidence.zsh`

---

### Deliverables for Phase 4
1. ✅ `~/tools/cls_evaluate_policy.zsh` - Policy engine
2. ✅ `~/tools/cls_calculate_confidence.zsh` - Confidence scoring
3. ✅ `~/02luka/memory/cls/policies.yaml` - Policy rules
4. ✅ `~/02luka/memory/cls/approvals.jsonl` - Approval tracking
5. ⚠️ Approval workflow integration (may need WO to CLC for Telegram)
6. ✅ Phase 4 documentation in `~/02luka/CLS/PHASE4_COMPLETE.md`

**Escalation to CLC:** Telegram notification integration (if needed)

---

## Phase 5: Tool Integrations (DELEGATED TO CLS)

### Overview
**Impact:** Low-Medium
**Complexity:** Low
**CLS Capability:** ✅ Can execute autonomously

### Tasks for CLS

#### 5.1: Tool Registry
**Goal:** Catalog CLS capabilities for self-discovery

**Implementation:**
```bash
# Tool catalog
~/02luka/memory/cls/tool_registry.yaml

# Schema:
tools:
  - name: "bridge_cls_clc"
    path: "~/tools/bridge_cls_clc.zsh"
    capabilities: ["wo_drop", "result_polling"]
    permissions: ["filesystem_read", "redis_read_write"]

  - name: "cls_dashboard"
    path: "~/tools/cls_dashboard.zsh"
    capabilities: ["metrics_display"]
    permissions: ["filesystem_read"]
```

---

#### 5.2: Command Executor
**Goal:** Safe wrapper for host commands

**Implementation:**
```bash
# Command whitelist
~/02luka/memory/cls/allowed_commands.yaml

# Schema:
allowed_commands:
  - command: "git status"
    risk_level: "low"
  - command: "git diff"
    risk_level: "low"
  - command: "git push"
    risk_level: "high"
    require_approval: true
```

**Script:** `~/tools/cls_exec_safe.zsh`
```zsh
#!/usr/bin/env zsh
# Validates command against whitelist before execution
```

---

#### 5.3: External Integrations
**Goal:** Connect to other local systems

**Candidates:**
- Knowledge base search (if exists)
- Local LLM (Ollama)
- Git operations (read-only within allow-list)

---

### Deliverables for Phase 5
1. ✅ `~/tools/cls_exec_safe.zsh` - Safe command executor
2. ✅ `~/02luka/memory/cls/tool_registry.yaml` - Tool catalog
3. ✅ `~/02luka/memory/cls/allowed_commands.yaml` - Command whitelist
4. ✅ Phase 5 documentation in `~/02luka/CLS/PHASE5_COMPLETE.md`

**Escalation to CLC:** None needed

---

## Phase 6: Evidence & Compliance (MIXED DELEGATION)

### Overview
**Impact:** High
**Complexity:** High
**CLS Capability:** ⚠️ Partial - CLS collects evidence, CLC validates compliance

### Tasks for CLS

#### 6.1: Validation Gates
**Goal:** Pre-flight checks before risky operations

**Implementation:**
```bash
# Validation rules
~/02luka/memory/cls/validation_rules.yaml

# Schema:
validations:
  - gate: "pre_wo_drop"
    checks:
      - file_exists: true
      - file_size_under: "10MB"
      - valid_yaml: true

  - gate: "pre_git_commit"
    checks:
      - no_secrets: true
      - linter_passed: true
```

**Script:** `~/tools/cls_validate.zsh`
```zsh
#!/usr/bin/env zsh
# Returns: pass|fail with details
```

---

#### 6.2: State Snapshots (NEEDS CLC)
**Goal:** Capture before/after states for rollback

**CLS Part:** Collect file states, compute diffs
**CLC Part:** Store snapshots in SOT, manage rollback

**Escalation:** WO to CLC for snapshot storage

---

#### 6.3: Compliance Reporting
**Goal:** Generate audit reports for governance

**CLS Part:** Aggregate data from audit logs
**CLC Part:** Generate formal compliance reports

**Escalation:** WO to CLC for final report generation

---

### Deliverables for Phase 6
1. ✅ `~/tools/cls_validate.zsh` - Validation gate executor
2. ✅ `~/tools/cls_snapshot_state.zsh` - State capture (CLS part)
3. ✅ `~/02luka/memory/cls/validation_rules.yaml` - Validation rules
4. ⚠️ WO to CLC: Snapshot storage system
5. ⚠️ WO to CLC: Compliance report generator
6. ✅ Phase 6 documentation in `~/02luka/CLS/PHASE6_COMPLETE.md`

**Escalation to CLC:** Snapshot storage, compliance reporting

---

## Coordination Protocol

### CLS → CLC Work Order Template

```yaml
# ~/tmp/phase_N_wo.yaml
title: "Phase N: [Task Name]"
priority: "P2"
tags: ["cls_enhancement", "phase_N", "integration"]
body: |
  ## Context
  CLS has completed [X, Y, Z] within allow-list zones.

  ## Escalation Needed
  Require CLC to:
  1. [Specific SOT modification]
  2. [System integration]
  3. [Governance decision]

  ## CLS Deliverables
  - File 1: ~/02luka/memory/cls/file1
  - File 2: ~/02luka/memory/cls/file2

  ## Expected CLC Output
  - Integration complete
  - SOT updated
  - Documentation in g/reports/
```

**Usage:**
```bash
~/tools/bridge_cls_clc.zsh \
  --title "Phase N: Task Name" \
  --priority P2 \
  --tags "cls_enhancement,phase_N" \
  --body /tmp/phase_N_wo.yaml \
  --wait
```

---

## Success Criteria

### For Each Phase

**CLS Responsibilities:**
1. ✅ All tools created in `~/tools/`
2. ✅ All data files in allow-list zones
3. ✅ Comprehensive documentation in `~/02luka/CLS/`
4. ✅ Testing scripts and examples
5. ✅ Self-contained: no SOT dependencies

**Escalation to CLC (if needed):**
1. ⚠️ WO dropped with clear requirements
2. ⚠️ Evidence attached (files, logs, test results)
3. ⚠️ Expected outcome specified
4. ⚠️ Rollback plan documented

---

## Timeline Estimate

**Aggressive (CLS focus):**
- Phase 3: 2-4 hours
- Phase 4: 4-6 hours (partial escalation)
- Phase 5: 2-3 hours
- Phase 6: 3-5 hours (CLC heavy)

**Total:** 11-18 hours of CLS implementation

**Conservative (Boss decides priority):**
- Phase 3: 1 week
- Phase 4: 1-2 weeks
- Phase 5: 3-5 days
- Phase 6: 1 week

**Total:** 3-5 weeks elapsed time

---

## Cost Analysis

### Token Usage (Estimated)

**Without Delegation:**
- CLC implements everything: ~500K tokens ($50-100)
- CLC debugging on host: Impossible (no host access)

**With Delegation:**
- CLC: Architecture + review: ~50K tokens ($5-10)
- CLS: Implementation: 0 tokens (local agent, free)
- Total savings: 90% reduction

### Time to Value

**Without Delegation:**
- CLC designs → Boss implements → CLC reviews
- Each phase: 3-5 days
- Total: 3-5 weeks

**With Delegation:**
- CLC delegates → CLS implements → CLC integrates
- Each phase: 1-2 days (CLS can work continuously)
- Total: 1-2 weeks

**Time savings:** 50-66% reduction

---

## Delegation Handoff

### For CLS in Cursor

**To start Phase 3:**
1. Read this document
2. Read `~/02luka/CLS/PHASE1_AND_2_COMPLETE.md` for context
3. Read `~/02luka/CLS/CLS_ENHANCEMENT_ROADMAP.md` for full scope
4. Create `/tmp/phase3_plan.md` with detailed steps
5. Implement Phase 3.1, test, then 3.2, test, then 3.3
6. Create `~/02luka/CLS/PHASE3_COMPLETE.md` documenting results
7. If escalation needed, drop WO to CLC with evidence

**Questions for Boss:**
- "Should CLS prioritize Phase 3, 4, 5, or 6 next?"
- "Any specific requirements or constraints for [phase]?"
- "Should CLS implement all at once or phase-by-phase with review?"

---

## Monitoring Delegation Success

### Key Metrics
- **Autonomy:** % of tasks CLS completes without escalation
- **Quality:** Test pass rate, documentation completeness
- **Speed:** Time from delegation to completion
- **Cost:** Token usage vs. CLC direct implementation

### Success Threshold
- ≥80% autonomy (minimal escalation)
- 100% test coverage
- <2 weeks per phase
- 90%+ cost savings

---

## Conclusion

**Delegation is the optimal strategy** for CLS enhancement because:

1. **CLS has host access** - can execute, test, iterate rapidly
2. **Allow-list zones sufficient** - 80%+ of work within permitted areas
3. **Clear escalation path** - WO to CLC when SOT needed
4. **Cost effective** - 90% token savings
5. **Time effective** - 50-66% faster implementation

**Next action:** Boss decides which phase CLS should tackle first, or delegates entire Phase 3-6 sequence to CLS for autonomous execution.

---

**Status:** Ready for handoff to CLS. Phase 1-2 infrastructure in place. Phase 3-6 delegated.
