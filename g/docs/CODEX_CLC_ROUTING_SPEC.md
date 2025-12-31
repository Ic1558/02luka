# Codex vs CLC Routing Specification
**Purpose:** Define when to use Codex CLI (enhanced) vs CLC (Claude Code)
**Goal:** Reduce CLC quota usage by 60-80% while maintaining system quality
**For:** GG Orchestrator decision-making

---

## Decision Matrix

### Priority 1: Zone-Based Routing

| Zone | Use | Reason |
|------|-----|--------|
| `/CLC/**` | **CLC only** | Locked zone, privileged access |
| `/core/governance/**` | **CLC only** | Governance docs, protocol surgery |
| `/memory/**` | **CLC only** | Memory system, critical data |
| `launchd/**` | **CLC only** | System daemons, high risk |
| `wo_pipeline_core/**` | **CLC only** | Work order pipeline core |
| Protocol files (`*_PROTOCOL_*.md`, `AI:OP-*.md`) | **CLC only** | System protocols |
| `/apps/**`, `/tools/**`, `/tests/**`, `/docs/**` | **Codex preferred** | Non-locked, safe for Codex |

**Rule:** If task touches ANY locked zone → CLC only (no exceptions)

---

### Priority 2: CLC Quota-Based Routing

Check CLC weekly usage before routing:

```bash
# Check CLC quota (in Claude Code)
/usage
```

| CLC Weekly Usage | Routing Rule |
|------------------|--------------|
| **< 40%** | CLC and Codex both OK, use task-based routing (Priority 3) |
| **40-60%** | Prefer Codex for non-locked tasks, CLC for locked/urgent |
| **60-80%** | **Quota Guard Active** - Codex only for non-locked, CLC only if critical |
| **> 80%** | **Emergency Mode** - CLC only for locked zones, everything else → Codex or Gemini |

**Rule:** When quota ≥ 60%, decline non-critical CLC work with:
> "CLC weekly usage is above 60%. Routing this task to Codex instead to preserve quota."

---

### Priority 3: Task-Based Routing

When zone is non-locked AND quota < 60%, use task type:

| Task Type | Use | Reason |
|-----------|-----|--------|
| **Code Review** | **Codex** | Codex has official `code-review` skill |
| **Refactoring** | **Codex** | Codex has `refactor` skill + repo-wide context |
| **Test Generation** | **Codex** | Codex has `test-generation` skill |
| **Debugging** | **Codex** | Codex has `debug-assistant` skill |
| **Multi-file bulk operations** | **Codex** | Cheaper, handles large-scale edits |
| **Long-form documentation** | **Codex or Gemini** | Save CLC for code tasks |
| **Interactive step-by-step work** | **CLC** | Better UX for back-and-forth |
| **Urgent bugfixes** | **CLC** | Faster turnaround |
| **Protocol edits** | **CLC** | Locked zone (see Priority 1) |
| **Governance changes** | **CLC** | Locked zone (see Priority 1) |
| **Plan mode required** | **CLC** | Codex doesn't have plan mode yet |

---

### Priority 4: Codex Capability Check

**Before routing to Codex, verify it can handle the task:**

| Capability | Codex Status | Notes |
|------------|--------------|-------|
| File read/write | ✅ Full support | Codex 0.77.0 has full file ops |
| Terminal commands | ✅ Full support | Can run bash commands |
| Code review | ✅ With skill | Install `openai/skills` first |
| Refactoring | ✅ With skill | Install `openai/skills` first |
| Test generation | ✅ With skill | Install `openai/skills` first |
| Debugging | ✅ With skill | Install `openai/skills` first |
| Plan mode | ❌ Not available | Use CLC for tasks requiring plan approval |
| Approval gates | ⚠️ Manual | Use `pre-commit` hooks as workaround |
| Slash commands | ❌ Not available | Use Codex skills instead |
| TodoWrite tracking | ❌ Not available | Manual tracking required |

**Rule:** If task requires plan mode or approval gates → use CLC (for now)

---

## Routing Decision Flow

**Flowchart:** `g/docs/CODEX_ROUTING_FLOWCHART.md`

```
START
  ↓
[1] Does task touch locked zones?
  ├─ YES → Use CLC
  └─ NO → Continue
      ↓
[2] Is CLC weekly usage ≥ 60%?
  ├─ YES → Use Codex (unless critical)
  └─ NO → Continue
      ↓
[3] Check task type
  ├─ Code review/refactor/test/debug → Use Codex
  ├─ Multi-file bulk operation → Use Codex
  ├─ Long-form docs → Use Codex or Gemini
  ├─ Plan mode required → Use CLC
  ├─ Interactive/urgent → Use CLC
  └─ Default → Use Codex
      ↓
[4] Verify Codex has required capability
  ├─ YES → Use Codex
  └─ NO → Fallback to CLC
```

---

## Examples

### Example 1: Code Review in `/apps/`
- **Zone:** Non-locked ✅
- **CLC Quota:** 45% (below 60%) ✅
- **Task Type:** Code review → Codex preferred
- **Codex Capability:** Has `code-review` skill ✅
- **Decision:** ✅ **Use Codex**

**Command:**
```bash
codex --skill code-review "review changes in apps/api/"
```

---

### Example 2: Refactor in `/core/governance/`
- **Zone:** Locked zone (`/core/governance/**`) ❌
- **Decision:** ✅ **Use CLC** (locked zone = CLC only)

---

### Example 3: Test Generation, CLC at 65%
- **Zone:** Non-locked (`/apps/tests/`) ✅
- **CLC Quota:** 65% (Quota Guard active) ❌
- **Task Type:** Test generation → Codex preferred
- **Decision:** ✅ **Use Codex** (save CLC quota)

**Command:**
```bash
codex --skill test-generation "generate tests for apps/api/auth.ts"
```

---

### Example 4: Plan-First Feature Development
- **Zone:** Non-locked ✅
- **CLC Quota:** 30% ✅
- **Task Type:** Requires plan mode ❌
- **Codex Capability:** No plan mode support ❌
- **Decision:** ✅ **Use CLC** (Codex can't do plan mode yet)

**Command:**
```bash
# In Claude Code
/plan "add user authentication feature"
```

---

### Example 5: Urgent Bugfix in `/apps/`
- **Zone:** Non-locked ✅
- **CLC Quota:** 50% ✅
- **Task Type:** Urgent bugfix → CLC preferred (faster)
- **Decision:** ✅ **Use CLC** (speed matters)

---

### Example 6: Multi-File Refactor, CLC at 70%
- **Zone:** Non-locked ✅
- **CLC Quota:** 70% (Quota Guard active) ❌
- **Task Type:** Multi-file refactor → Codex preferred
- **Decision:** ✅ **Use Codex** (must save CLC quota)

**Command:**
```bash
codex --skill refactor "refactor 15 files in tools/ for better error handling"
```

---

## Integration with GG Orchestrator

**GG should follow this routing spec when deciding which engine to use.**

**Add to GG_ORCHESTRATOR_CONTRACT.md:**

```markdown
### 4.6 Codex CLI Routing

When routing tasks to Codex CLI (after Phase 1+ enhancement):

1. Check locked zones (Priority 1)
2. Check CLC quota (Priority 2)
3. Check task type (Priority 3)
4. Verify Codex capability (Priority 4)

See: `g/docs/CODEX_CLC_ROUTING_SPEC.md` for full decision matrix.

**GG MUST state routing decision:**
- Engine chosen: Codex CLI
- Reason: Non-locked zone + CLC quota at 65% + code review task
- Command: `codex --skill code-review ...`
```

---

## Monitoring & Optimization

### Track Routing Metrics

Create routing log to track decisions:

```bash
# Log format (append to g/reports/routing_log.jsonl)
{
  "timestamp": "2025-12-30T10:00:00Z",
  "task": "code review in apps/api/",
  "zone": "non-locked",
  "clc_quota": "45%",
  "task_type": "code_review",
  "decision": "codex",
  "reason": "non-locked + has skill + quota OK",
  "success": true
}
```

### Weekly Review

Every week, analyze routing log:
- How many tasks routed to Codex vs CLC?
- CLC quota savings achieved?
- Any Codex failures requiring CLC fallback?
- Adjust routing thresholds if needed

**Target KPIs:**
- 60-70% tasks routed to Codex (after Phase 1+2)
- 70-80% tasks routed to Codex (after Phase 3+4)
- CLC quota savings: 60-80%
- Task success rate: >95% (both Codex and CLC)

---

## Rollout Plan

### Phase 0: Preparation (Now)
- [ ] Install Codex enhancement stack (Phases 1-4)
- [ ] Test Codex skills with sample tasks
- [ ] Create routing decision template for GG

### Phase 1: Soft Launch (Week 1-2)
- [ ] Route only code review tasks to Codex
- [ ] Monitor success rate and CLC quota
- [ ] Adjust routing rules based on feedback

### Phase 2: Expand (Week 3-4)
- [ ] Add refactoring tasks to Codex
- [ ] Add test generation tasks to Codex
- [ ] Gradually increase Codex task types

### Phase 3: Full Deployment (Week 5+)
- [ ] Route all non-locked, non-plan tasks to Codex
- [ ] CLC reserved for locked zones + plan mode only
- [ ] Achieve 60-80% CLC quota savings

---

## Fallback Policy

**If Codex fails, fallback to CLC:**

1. Log failure reason to routing log
2. Immediately retry with CLC
3. Update routing spec to avoid similar failures
4. Report to Boss for review

**Common failure scenarios:**
- Codex skill not installed → Install skill, then retry
- Codex API quota exceeded → Fallback to CLC immediately
- Codex output quality poor → Use CLC, investigate later
- Task requires plan mode → Use CLC (expected, not failure)

---

## Summary

**Key Principles:**
1. **Zone first** - Locked zones = CLC only (no exceptions)
2. **Quota matters** - CLC ≥ 60% = route to Codex aggressively
3. **Task type** - Use Codex skills when available
4. **Verify capability** - Don't route if Codex can't handle it
5. **Log & learn** - Track decisions, optimize over time

**Expected Outcome:**
- **60-80% CLC quota savings**
- **Zero quality degradation** (locked zones still use CLC)
- **Faster iteration** (Codex cheaper = less quota anxiety)
- **Better delegation** (GG routes intelligently)

---

**Next:** Install Codex enhancement stack (Phases 1-4) to enable this routing spec.
