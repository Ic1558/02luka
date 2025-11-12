# Feature Specification: Claude Code Week 3-4 - Documentation & Monitoring (MVS)

**Feature ID:** `claude_code_week3_4_docs_monitoring`  
**Date:** 2025-11-12  
**Status:** 📋 **SPECIFICATION**

---

## Objective

Complete Week 3-4 (Documentation & Monitoring) of Claude Code Best Practices System by implementing practical documentation, basic metrics dashboard, light MLS capture, and comprehensive smoke tests. Focus on **MVS (Minimum Viable Set)** - deliverable within 1-2 working days.

---

## Context

**Completed (Week 1):**
- ✅ `.claude/settings.json` configured
- ✅ Hooks installed (pre_commit, quality_gate, verify_deployment)
- ✅ Health dashboard operational
- ✅ Deploy/rollback/certificate flow working

**Completed (Week 2):**
- ✅ 5 slash commands: `/feature-dev`, `/deploy`, `/code-review`, `/commit`, `/health-check`
- ✅ Backend-agnostic orchestrator (CLS default)
- ✅ Subagent orchestration with error handling
- ✅ Metrics logging infrastructure

**Current State:**
- Foundation and workflows complete
- Ready for documentation and monitoring
- Need practical guides for users
- Need visibility into system usage

---

## Requirements

### Must Have (MVS - Minimum Viable Set)

#### 1. Documentation (3 files)

**Location:** `docs/claude_code/`

1. **`ONBOARDING.md`**
   - Quick start guide (5-minute setup)
   - First run instructions
   - Example commands with outputs
   - Sample SPEC/PLAN template included
   - Language: Thai/English (concise)

2. **`BEST_PRACTICES.md`**
   - Do/don't patterns
   - Short patterns based on real usage
   - Command usage guidelines
   - Common workflows
   - Language: Thai/English (concise)

3. **`TROUBLESHOOTING.md`**
   - Symptoms → Common causes → Solutions
   - Command reference for fixes
   - Hook debugging steps
   - Error message interpretation
   - Language: Thai/English (concise)

#### 2. Metrics Dashboard

**Location:** `g/apps/dashboard/claude_code.html`

**Features:**
- Periodic updates (not real-time)
- 3 main cards:
  1. **Hook Success Rate** (latest/week)
  2. **Subagent Usage** (review/compete counts)
  3. **Deployment Outcomes** (success/rollback)
- Reads from: `g/reports/claude_code_metrics_YYYYMM.json` (primary) + `g/reports/claude_code_metrics_YYYYMM.md` (fallback) + log summaries
- Error handling: Shows "No data available" if JSON missing or invalid

**Helper Script (if needed):**
- `tools/claude_tools/metrics_to_json.zsh`
- Generates `g/reports/claude_code_metrics_YYYYMM.json`

#### 3. MLS Capture (Light)

**Location:** `g/knowledge/mls_lessons.jsonl` (existing MLS database)

**Tool:** Uses existing `tools/mls_capture.zsh`

**Trigger Points:**
- After code review completion
- After deployment completion

**Format:**
- JSONL entry via `mls_capture.zsh` tool
- Captures: type, title, description, context
- Types: `solution`, `improvement`, `pattern` (as appropriate)
- No automatic pattern mining (future enhancement)

**Integration:**
- Hook into existing `tools/subagents/compare_results.zsh`
- Hook into existing `tools/claude_hooks/verify_deployment.zsh`
- Call: `"$BASE/tools/mls_capture.zsh" <type> "<title>" "<description>" "<context>"`

**Example:**
```zsh
# After code review
"$BASE/tools/mls_capture.zsh" solution \
  "Code Review: Week 3-4 SPEC/PLAN" \
  "Multi-agent review completed with 2 agents (backend: cls)" \
  "Review strategy, backend=cls, agents=2"

# After deployment
"$BASE/tools/mls_capture.zsh" improvement \
  "Claude Code Week 3-4: Documentation & Monitoring" \
  "Documentation, dashboard, and MLS capture integrated" \
  "MVS approach, 8-12 hours, all acceptance criteria met"
```

#### 4. Smoke Tests

**Location:** `tests/claude_code/`

1. **`e2e_smoke_commands.zsh`**
   - Tests all 5 commands: `/feature-dev`, `/deploy`, `/code-review`, `/commit`, `/health-check`
   - Uses `check_runner.zsh` pattern
   - Exit code 0 = pass, non-zero = fail

2. **`orchestrator_review_smoke.zsh`**
   - Tests orchestrator "review strategy" (single case)
   - Verifies subagent execution
   - Verifies result synthesis

### Nice to Have (Explicitly Out of Scope)

- ❌ Real-time dashboard updates
- ❌ Complex graphs/charts
- ❌ Automatic pattern mining
- ❌ Coverage percentage requirements
- ❌ Video tutorials
- ❌ Interactive setup wizards

---

## Design

### Documentation Structure

**Pattern:**
```markdown
# Title
Brief intro

## Quick Start
Step 1...
Step 2...

## Examples
[Real examples from codebase]

## Common Issues
Q: Problem?
A: Solution
```

### Dashboard Design

**Layout:**
- Simple HTML with inline CSS
- 3-card grid layout
- JSON data source (periodic refresh)
- No JavaScript frameworks (vanilla JS only)

**Data Flow:**
```
metrics_collector.zsh → logs
metrics_to_json.zsh → g/reports/claude_code_metrics_YYYYMM.json
claude_code.html → reads JSON → displays cards (with error handling)
```

**Error Handling:**
- If JSON file missing: Display "No data available" message
- If JSON invalid: Display "Data format error" message
- Fallback: Try reading from MD file if JSON unavailable

### MLS Capture Pattern

**Uses Existing Tool:** `tools/mls_capture.zsh`

**Format:** JSONL entry in `g/knowledge/mls_lessons.jsonl`

**Structure:**
```json
{
  "id": "MLS-<timestamp>",
  "type": "solution|improvement|pattern|failure|antipattern",
  "title": "Claude Code: <event>",
  "description": "<what happened>",
  "context": "<additional context>",
  "timestamp": "2025-11-12T...",
  "related_wo": "...",
  "related_session": "..."
}
```

**Integration Pattern:**
- Call `mls_capture.zsh` at end of hook functions
- Wrap in `|| true` to prevent hook failure if MLS capture fails
- Log capture success/failure for debugging

### Test Strategy

**Using `check_runner.zsh`:**
- Each command test = one `cr_run_check`
- Orchestrator test = one `cr_run_check`
- Always generate reports (Markdown + JSON)
- Exit 0 if all pass, non-zero if any fail

---

## Acceptance Criteria

### Documentation
1. ✅ User can read `ONBOARDING.md` and complete first run without hook errors
2. ✅ User can follow all 5 commands successfully
3. ✅ `BEST_PRACTICES.md` contains real patterns from codebase
4. ✅ `TROUBLESHOOTING.md` covers common issues with solutions

### Dashboard
1. ✅ `g/apps/dashboard/claude_code.html` displays 3 cards:
   - Hook success rate (latest/week)
   - Subagent usage (counts)
   - Deployment outcomes (success/rollback)
2. ✅ Dashboard reads from JSON/metrics files
3. ✅ Dashboard updates periodically (not real-time)

### MLS Capture
1. ✅ MLS entries created automatically after code review
2. ✅ MLS entries created automatically after deployment
3. ✅ Entries stored in `g/knowledge/mls_lessons.jsonl` (existing MLS database)
4. ✅ Format is JSONL (compatible with existing MLS system)
5. ✅ Uses existing `tools/mls_capture.zsh` tool

### Smoke Tests
1. ✅ `e2e_smoke_commands.zsh` passes (exit 0)
2. ✅ `orchestrator_review_smoke.zsh` passes (exit 0)
3. ✅ Tests use `check_runner.zsh` pattern
4. ✅ Tests generate reports (Markdown + JSON)

---

## Constraints

- **Timebox:** 1-2 working days (8-12 hours)
- **Scope:** MVS only (no advanced features)
- **Dependencies:** Week 1 & Week 2 must be complete
- **Language:** Thai/English (concise, practical)
- **No Breaking Changes:** Must not affect existing functionality

---

## Success Metrics

- Documentation: Users can onboard in < 5 minutes
- Dashboard: Shows accurate metrics from last week
- MLS: Captures lessons automatically
- Tests: All smoke tests pass consistently

---

## Out of Scope (Explicitly)

- Real-time dashboard updates
- Complex visualizations
- Automatic pattern mining
- Coverage percentage enforcement
- Video tutorials
- Interactive wizards

---

**Status:** 📋 **READY FOR IMPLEMENTATION** (v1.1 - Fixed per code review)
