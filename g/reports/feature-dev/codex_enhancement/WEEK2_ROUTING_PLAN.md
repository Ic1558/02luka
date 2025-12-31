# Week 2 Codex Routing Plan
**Period:** Week 2 post-Week 1 routing success  
**Goal:** Scale to 10-15 tasks, maintain 95%+ success, 9.0+ quality, 70-80%+ CLC savings  
**Status:** Ready to execute  
**Inputs:** `g/docs/CODEX_ROUTING_FLOWCHART.md`, `g/docs/CODEX_CLC_ROUTING_SPEC.md`, Week 1 metrics

---

## Routing Rules v2.0 (Based on Flowchart + Metrics)

### Use Codex (Interactive) When:
✅ **Zone:** tools/, apps/, g/ (non-locked)  
✅ **Scope:** Clear patch (1-4 files if tightly related)  
✅ **Risk:** Low-medium, easy rollback  
✅ **Task type:** reliability fixes, small refactors, docs, test updates  
✅ **TTY:** Run `codex-task` interactively (TTY required)

### Use CLC When:
❌ **Locked zones:** core/governance/launchd/memory, protocol files  
❌ **Security-critical:** auth, permissions, credential handling  
❌ **Design-heavy:** architecture decisions or multi-file redesign  
❌ **Complex changes:** 4+ files with unclear dependencies  

---

## Task Buckets (Week 2)

### Bucket 1: Reliability Backlog (Codex)

#### Task 1.1: Add error handling to solution_collector.zsh
**File:** `tools/solution_collector.zsh`  
**Issue:** No error handling for file operations  
**Fix:** Add mkdir checks, file writability checks, jq availability if used  
**Priority:** P2  
**Command:**
```bash
codex-task "Add error handling to tools/solution_collector.zsh: Add checks for (1) directory creation with mkdir -p || die, (2) file writability before writing, (3) jq availability if used. Use die() and warn() functions for errors."
```

#### Task 1.2: Add atomic write to save.sh
**File:** `tools/save.sh`  
**Issue:** Direct writes risk corruption on interruption  
**Fix:** Use temp file + atomic rename  
**Priority:** P2  
**Command:**
```bash
codex-task "Add atomic write pattern to tools/save.sh: When writing output files, use temp file (mktemp) + atomic rename to prevent corruption if interrupted. Pattern: write to temp, validate, then mv to final location."
```

#### Task 1.3a: Standardize quoting in session_save.zsh
**File:** `tools/session_save.zsh`  
**Issue:** Inconsistent quoting  
**Fix:** Use double quotes for expansions, single quotes for literals  
**Priority:** P4  
**Command:**
```bash
codex-task "Standardize quoting in tools/session_save.zsh: Use double quotes for variable expansion (\"\$var\"), single quotes for literals. Fix unquoted variables in conditionals and assignments."
```

#### Task 1.3b: Standardize quoting in save.sh
**File:** `tools/save.sh`  
**Issue:** Inconsistent quoting  
**Fix:** Use double quotes for expansions, single quotes for literals  
**Priority:** P4  
**Command:**
```bash
codex-task "Standardize quoting in tools/save.sh: Use double quotes for variable expansion (\"\$var\"), single quotes for literals. Fix unquoted variables in conditionals and assignments."
```

#### Task 1.4: Update telemetry comments in session_save.zsh
**File:** `tools/session_save.zsh`  
**Issue:** Comments may drift from jq-based telemetry behavior  
**Fix:** Align comments with jq -nc usage and type preservation  
**Priority:** P4  
**Command:**
```bash
codex-task "Update comments in tools/session_save.zsh: Update telemetry section comments to reflect jq -nc usage, auto-escaping, and numeric type preservation."
```

#### Task 1.5: Reduce noisy warnings in codex_metrics_summary.zsh
**File:** `tools/codex_metrics_summary.zsh`  
**Issue:** Comment/header lines counted as invalid JSON  
**Fix:** Skip blank and comment lines without warnings  
**Priority:** P3  
**Command:**
```bash
codex-task "Improve tools/codex_metrics_summary.zsh validation: Skip blank lines and lines starting with '#' without warnings. Only warn on truly invalid JSON lines."
```

---

### Bucket 2: Scale-Up Integration (Mixed)

#### Task 2.1: Add TTY guard to codex-task wrapper
**File:** `tools/setup_codex_workspace.zsh`  
**Issue:** codex-task fails without TTY, no guidance  
**Fix:** Detect non-interactive shell and print guidance  
**Priority:** P3  
**Engine:** Codex (interactive)  
**Command:**
```bash
codex-task "Improve codex-task in tools/setup_codex_workspace.zsh: Detect non-interactive shells and print a short message explaining TTY requirement and how to run interactively."
```

#### Task 2.2: Link routing flowchart from routing spec
**File:** `g/docs/CODEX_CLC_ROUTING_SPEC.md`  
**Issue:** Flowchart not referenced in spec  
**Fix:** Add reference to `g/docs/CODEX_ROUTING_FLOWCHART.md`  
**Priority:** P3  
**Engine:** Codex (interactive)  
**Command:**
```bash
codex-task "Update g/docs/CODEX_CLC_ROUTING_SPEC.md: Add a short note linking to g/docs/CODEX_ROUTING_FLOWCHART.md in the Routing Decision Flow section."
```

#### Task 2.3: Update GG Orchestrator contract with routing gate
**File:** `g/docs/GG_ORCHESTRATOR_CONTRACT.md`  
**Issue:** Orchestrator should apply flowchart + quota guard  
**Fix:** Add routing gate section for Codex vs CLC  
**Priority:** P2  
**Engine:** CLC (protocol/governance)

#### Task 2.4: Deduplicate jq patterns across tools
**Files:** `tools/*.zsh` (multi-file)  
**Issue:** Repeated jq filters; hard to maintain  
**Fix:** Extract common jq helpers or shared functions  
**Priority:** P4  
**Engine:** CLC (multi-file design)  
**Note:** Consider deferring to Week 3+ unless it blocks active work

---

### Bucket 3: Docs + Reporting (Codex)

#### Task 3.1: Create Week 1 routing report
**File:** `g/reports/feature-dev/codex_enhancement/WEEK1_ROUTING_REPORT.md`  
**Issue:** Week 1 results not captured in a standalone report  
**Fix:** Summarize tasks, metrics, issues, lessons learned  
**Priority:** P2  
**Command:**
```bash
codex-task "Create g/reports/feature-dev/codex_enhancement/WEEK1_ROUTING_REPORT.md: Summarize Week 1 tasks, metrics, issues, lessons learned, and recommendations for Week 2."
```

#### Task 3.2: Update sandbox strategy with Week 1 results
**File:** `g/docs/CODEX_SANDBOX_STRATEGY.md`  
**Issue:** Document still reflects pre-Week 1 expectations  
**Fix:** Add Week 1 outcomes and Week 2 targets  
**Priority:** P3  
**Command:**
```bash
codex-task "Update g/docs/CODEX_SANDBOX_STRATEGY.md: Add a short Week 1 Results section (tasks, quality, savings) and Week 2 targets aligned to the routing flowchart."
```

---

## Execution Strategy

- Execute by priority (P2 → P3 → P4), then by dependency and risk.  
- Prefer completing single-file Codex tasks before multi-file CLC tasks.  
- If scope expands mid-task, split or reroute per flowchart.

---

## Success Metrics (Week 2)

- **Tasks completed:** 15-25  
- **Success rate:** 95%+  
- **Average quality:** 9.0+  
- **CLC quota saved:** 70-80%+  
- **Rollbacks:** <10%

---

## Logging

Log every task:
```bash
zsh ~/02luka/tools/log_codex_task.zsh \
  "<task_type>" \
  "<codex command>" \
  <quality_score>
```

View metrics:
```bash
zsh ~/02luka/tools/codex_metrics_summary.zsh
```
