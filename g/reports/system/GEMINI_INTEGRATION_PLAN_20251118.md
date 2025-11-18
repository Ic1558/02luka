# Gemini API Integration Plan – Conservative Additive (Backup)

**Date:** 2025-11-18
**Source:** Chat planning session (GG + CLC)
**Status:** NOT IN MLS (capture failed) – this file is the backup SOT for now.
**Approach:** Conservative Additive Only (no workflow replacement)
**Budget:** Quota-based (respect subscription limits)
**Use Cases:** Versatile (heavy compute, testing, bulk ops, script generation)

---

## Overview

Integrate Gemini API to offload heavy compute from CLC/Codex while preserving existing workflows.

**Total Timeline:** ~10 days (conservative estimate)

**Files Impact:**
- **13 new files** (connectors, handlers, templates, trackers, docs)
- **11 modified files** (protocols, personas, contracts, dashboards)

**Risk:** Zero disruption (additive-only approach)

---

## Phase 1: Foundation Setup (2-3 days)

**Goal:** Create core Gemini infrastructure

### Files to CREATE:
```
$SOT/g/connectors/gemini_connector.py          # API client wrapper
$SOT/agents/gemini_agent/PERSONA_PROMPT.md     # Agent persona definition
$SOT/agents/gemini_agent/README.md             # Agent documentation
$SOT/bridge/handlers/gemini_handler.py         # Task handler
$SOT/bridge/memory/gemini_memory_loader.py     # Context loader
```

### Tasks:
- Implement `gemini_connector.py` using Google AI Python SDK
- Define Gemini agent persona (role: heavy compute offloader)
- Create bridge handler for work order processing
- Test API connectivity with GEMINI_API_KEY
- Install `gemini-cli` if needed (currently missing)

### Dependencies:
- ✅ Gemini API subscription active (confirmed)
- ⚠️ GEMINI_API_KEY obtained (need to verify)

### Deliverable:
Working API connection + basic task handler

---

## Phase 2: Routing Logic (1-2 days)

**Goal:** Extend orchestrator routing to include Gemini

### Files to MODIFY:
```
$SOT/agents/liam/PERSONA_PROMPT.md             # Add Gemini routing rules
$SOT/docs/GG_ORCHESTRATOR_CONTRACT.md          # Expand agent_action examples
$SOT/g/docs/CONTEXT_ENGINEERING_PROTOCOL_v3.md # Add Layer 4.5: Gemini
```

### Changes in Liam PERSONA_PROMPT.md:
```yaml
gg_decision:
  route_to: andy | cls | clc_spec | gemini | external  # Add 'gemini'

# Routing rules:
# - complexity = complex + impact_zone = apps|tools → consider Gemini
# - task_type = bulk_operations | test_generation → Gemini
# - Large script generation → Gemini
```

### Changes in CONTEXT_ENGINEERING_PROTOCOL_v3.md:
```markdown
### Layer 4.5: Gemini (Heavy Compute Offload)
- **Role:** Heavy computation, bulk operations, test generation
- **Token source:** Gemini API (consumer subscription)
- **Use when:** CLC/Codex token budget tight, complex multi-file analysis
- **Output:** Specs/patches routed back to Andy/CLS for review
```

### Deliverable:
Liam/GG can route tasks to Gemini

---

## Phase 3: Work Order Integration (2 days)

**Goal:** Integrate Gemini into WO system for audit trail

### Files to CREATE:
```
$SOT/bridge/inbox/GEMINI/.gitkeep
$SOT/bridge/outbox/GEMINI/.gitkeep
$SOT/bridge/templates/gemini_task_template.yaml
```

### Files to MODIFY:
```
$SOT/agents/kim_bot/kim_router.py              # Add Gemini routing
$SOT/tools/wo_dispatcher.zsh                   # Handle GEMINI prefix
```

### WO Flow:
```
GG/Liam creates WO → /bridge/inbox/GEMINI/WO_xxx.yaml
→ gemini_handler.py processes
→ Result → /bridge/outbox/GEMINI/WO_xxx_result.yaml
→ Andy/CLS reviews output
```

### Task Template Example:
```yaml
wo_id: GEMINI_20251118_001
task_type: bulk_test_generation
input:
  target_files: ["$SOT/g/apps/dashboard/**/*.js"]
  test_framework: "jest"
  coverage_target: 80
output_format: test_suite_patch
review_by: andy
```

### Deliverable:
Gemini tasks tracked via WO system

---

## Phase 4: Quota Tracking (2-3 days)

**Goal:** Monitor multi-engine token usage to prevent overspend

### Files to CREATE:
```
$SOT/g/tools/quota_tracker.py                  # Multi-engine tracker
$SOT/g/schemas/quota_metrics.json              # Quota data schema
$SOT/g/apps/dashboard/widgets/quota_widget.html # Dashboard UI
```

### Files to MODIFY:
```
$SOT/g/apps/dashboard/data/metrics.json        # Add quota data source
```

### Metrics to Track:
- GPT (ChatGPT) token usage
- Gemini API token usage
- Codex (Cursor) token usage
- Claude (CLC) token usage

### Alerts:
- Warning at 80% quota
- Stop routing at 95% quota
- Daily/weekly reports

### Dashboard Widget:
```
┌─────────────────────────────┐
│ Token Distribution (Weekly) │
├─────────────────────────────┤
│ GPT:    ████████░░ 45%      │
│ Gemini: ████░░░░░░ 20%      │
│ Codex:  ██████░░░░ 30%      │
│ Claude: █░░░░░░░░░  5%      │
└─────────────────────────────┘
```

### Deliverable:
Real-time quota monitoring + alerts

---

## Phase 5: Documentation & Deployment (2 days)

**Goal:** Complete docs, test end-to-end, deploy to production

### Files to CREATE:
```
$SOT/g/manuals/GEMINI_INTEGRATION.md           # User manual
$SOT/g/reports/gemini/deployment_report.md     # Deployment summary
```

### Files to MODIFY:
```
$SOT/g/CLAUDE_CONTEXT.md                       # Add Gemini layer
$SOT/agents/andy/PERSONA_PROMPT.md             # Reference Gemini for heavy tasks
$SOT/agents/cls/README.md                      # Gemini output review protocol
```

### Testing Checklist:
- [ ] GG → Liam → Gemini task routing works
- [ ] WO created in /bridge/inbox/GEMINI/
- [ ] Gemini processes task via gemini_handler.py
- [ ] Result appears in /bridge/outbox/GEMINI/
- [ ] Andy receives spec for review
- [ ] Quota tracker updates correctly
- [ ] Dashboard shows Gemini usage

### Success Criteria:
- ✅ No disruption to existing workflows
- ✅ Token distribution across engines
- ✅ Quota compliance maintained
- ✅ Audit trail via WO system
- ✅ CLC/Codex token pressure reduced

### Deliverable:
Production-ready Gemini integration

---

## Pattern: Conservative Additive Integration

**Principle:**
When integrating new AI engines, preserve existing workflows and add new capabilities incrementally.

### Key Rules:
1. **Additive Only** — No replacement of working systems
2. **Quota-Based** — Respect subscription limits, no artificial caps
3. **Clear Routing** — Explicit rules in orchestrator (Liam/GG)
4. **Versatile Use** — Preserve token optimization across use cases
5. **Audit Trail** — Work order system maintains governance
6. **Multi-Engine Tracking** — Prevent overuse of any single engine

### Applied to Gemini:
- Gemini offloads heavy compute (preserves CLC/Codex for local dev)
- GG/Liam decide routing (no automatic replacement)
- All Gemini work goes through WO system (audit trail)
- Quota tracker prevents overspend

---

## MLS Entries (Planned)

When MLS capture is fixed, create these entries:

1. **improvement** — Phase 1: Foundation Setup
2. **improvement** — Phase 2: Routing Logic
3. **improvement** — Phase 3: Work Order Integration
4. **improvement** — Phase 4: Quota Tracking
5. **improvement** — Phase 5: Documentation & Deployment
6. **pattern** — Conservative Additive Integration Pattern

---

## References

- **GG Review:** Approved 2025-11-18
- **Governance Check:** Protocol v3.2 compliant
- **Risk Assessment:** Additive-only, zero disruption
- **Chat Session:** Full planning discussion with GG + CLC

---

**Next Steps:**

1. Obtain GEMINI_API_KEY
2. Execute Phase 1 (Foundation Setup)
3. Test API connectivity
4. Proceed with Phases 2-5 sequentially

---

**Status:** ✅ Plan complete and backed up
**Implementation:** Awaiting MLS fix and Boss approval to execute
