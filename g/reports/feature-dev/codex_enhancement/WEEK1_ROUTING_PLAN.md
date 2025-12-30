# Week 1 Codex Routing Plan
**Period:** Week 1 post-Codex Enhancement Phase
**Goal:** Route 10-20 tasks to Codex, measure CLC quota savings 40%+
**Status:** Ready for execution

---

## Routing Rules v1.0 (Production)

### Use Codex (Interactive) When:
✅ **Zone:** tools/, apps/, g/ (non-locked)
✅ **Scope:** Single file or 2-3 related files
✅ **Type:** Patch ชัด ๆ (add check, fix bug, refactor function)
✅ **Risk:** Low-Medium (can rollback easily)
✅ **Pattern:** Similar to Issues #3-#4 (reliability, refactor, docs)

**Command:**
```bash
cd ~/02luka
codex-task "<clear instruction with file + line numbers>"
```

### Use CLC When:
❌ **Zone:** Locked zones (/CLC, /core/governance, launchd/, memory_center/)
❌ **Security:** Critical security fixes (git operations, credentials, access control)
❌ **Multi-file:** Changes across 4+ files with complex dependencies
❌ **Design:** Tasks requiring "think-plan-design" phase
❌ **High-risk:** Can break system if wrong

---

## Task Buckets (15 Tasks Total)

### Bucket 1: Reliability Improvements (5 tasks)

#### Task 1.1: Add jq check to mls_search.zsh
**File:** `tools/mls_search.zsh`
**Issue:** Uses jq without availability check (same pattern as Issue #3)
**Fix:** Add preflight check at script start
**Engine:** Codex (interactive)
**Priority:** P2
**Estimated:** 5 minutes

**Command:**
```bash
codex-task "Add jq availability check to tools/mls_search.zsh: Add preflight check after shebang that verifies jq is installed. If not found, print clear error message 'Error: jq is required but not installed' and 'Install: brew install jq', then exit 1."
```

---

#### Task 1.2: Add error handling to solution_collector.zsh
**File:** `tools/solution_collector.zsh`
**Issue:** No error handling for file operations
**Fix:** Add directory creation checks, writability validation
**Engine:** Codex (interactive)
**Priority:** P2
**Estimated:** 10 minutes

**Command:**
```bash
codex-task "Add error handling to tools/solution_collector.zsh: Add checks for (1) directory creation with mkdir -p || die, (2) file writability before writing, (3) jq availability if used. Use die() and warn() functions for errors."
```

---

#### Task 1.3: Validate JSON in codex_metrics_summary.zsh
**File:** `tools/codex_metrics_summary.zsh`
**Issue:** Reads JSONL without validating format
**Fix:** Add jq validation before processing
**Engine:** Codex (interactive)
**Priority:** P3
**Estimated:** 10 minutes

**Command:**
```bash
codex-task "Add JSON validation to tools/codex_metrics_summary.zsh: Before processing codex_routing_log.jsonl, validate each line is valid JSON with jq. Skip invalid lines with warning instead of crashing."
```

---

#### Task 1.4: Add atomic write to save.sh
**File:** `tools/save.sh`
**Issue:** Writes directly without temp file (risk of corruption)
**Fix:** Use temp file + atomic rename pattern
**Engine:** Codex (interactive)
**Priority:** P2
**Estimated:** 15 minutes

**Command:**
```bash
codex-task "Add atomic write pattern to tools/save.sh: When writing output files, use temp file (mktemp) + atomic rename to prevent corruption if interrupted. Pattern: write to temp, validate, then mv to final location."
```

---

#### Task 1.5: Improve error messages in mary_preflight.zsh
**File:** `tools/mary_preflight.zsh`
**Issue:** Error messages unclear
**Fix:** Add actionable guidance to error messages
**Engine:** Codex (interactive)
**Priority:** P3
**Estimated:** 10 minutes

**Command:**
```bash
codex-task "Improve error messages in tools/mary_preflight.zsh: Make all error messages actionable - include what went wrong, why it matters, and how to fix it. Pattern: 'Error: X failed. Impact: Y. Fix: Z.'"
```

---

### Bucket 2: Refactor Small-Scope (5 tasks)

#### Task 2.1: Extract function in session_save.zsh (MLS parsing)
**File:** `tools/session_save.zsh`
**Issue:** MLS parsing logic inline (lines ~150-220), hard to test
**Fix:** Extract to `parse_mls_data()` function
**Engine:** Codex (interactive)
**Priority:** P3
**Estimated:** 15 minutes

**Command:**
```bash
codex-task "Refactor tools/session_save.zsh lines 150-220: Extract MLS data parsing logic into separate function 'parse_mls_data()'. Function should take MLS_DATA as input and return parsed stats. Keep error handling."
```

---

#### Task 2.2: Deduplicate jq patterns in tools/
**File:** `tools/*.zsh` (multiple)
**Issue:** Same jq patterns repeated (e.g., jq -r '.entries[] | ...')
**Fix:** Create common jq pattern functions
**Engine:** CLC (multi-file, requires design)
**Priority:** P4
**Estimated:** 30 minutes

---

#### Task 2.3: Improve path handling in log_codex_task.zsh
**File:** `tools/log_codex_task.zsh`
**Issue:** Hardcoded paths, no variable expansion
**Fix:** Use $HOME/02luka pattern consistently
**Engine:** Codex (interactive)
**Priority:** P3
**Estimated:** 10 minutes

**Command:**
```bash
codex-task "Improve path handling in tools/log_codex_task.zsh: Replace hardcoded paths with \$HOME/02luka pattern. Use repo_root variable for flexibility. Ensure all paths work if script run from any directory."
```

---

#### Task 2.4: Remove duplication in git checkpoint scripts
**File:** `tools/codex-task` wrapper
**Issue:** Pre/post codex logic duplicated
**Fix:** Extract to shared checkpoint functions
**Engine:** Codex (interactive)
**Priority:** P3
**Estimated:** 15 minutes

**Command:**
```bash
codex-task "Refactor codex-task wrapper: Extract git checkpoint creation (pre-codex commit) and rollback logic into reusable functions create_checkpoint() and rollback_checkpoint(). Reduce duplication in wrapper script."
```

---

#### Task 2.5: Standardize quoting in zsh scripts
**File:** `tools/session_save.zsh`, `tools/save.sh`
**Issue:** Inconsistent quoting ("$var" vs $var vs '$var')
**Fix:** Follow zsh best practices consistently
**Engine:** Codex (interactive)
**Priority:** P4
**Estimated:** 10 minutes

**Command:**
```bash
codex-task "Standardize quoting in tools/session_save.zsh and tools/save.sh: Use double quotes for variable expansion (\"\$var\"), single quotes for literals. Fix unquoted variables in conditionals and assignments."
```

---

### Bucket 3: Docs + Spec Hygiene (5 tasks)

#### Task 3.1: Update CODEX_FINDINGS_ACTION_PLAN.md final status
**File:** `g/reports/feature-dev/codex_enhancement/CODEX_FINDINGS_ACTION_PLAN.md`
**Issue:** Missing final summary section
**Fix:** Add "Phase Complete" summary at top
**Engine:** Codex (interactive)
**Priority:** P2
**Estimated:** 10 minutes

**Command:**
```bash
codex-task "Add Phase Complete summary to g/reports/feature-dev/codex_enhancement/CODEX_FINDINGS_ACTION_PLAN.md: At top of file, add '## Phase Complete Summary' section with: 4/4 issues resolved, commits, quality scores, key insights, next steps."
```

---

#### Task 3.2: Create Codex Quick Reference
**File:** `g/manuals/codex_quick_reference.md` (new)
**Issue:** No quick guide for using codex-task/codex-system
**Fix:** Create 1-page cheatsheet
**Engine:** Codex (interactive)
**Priority:** P2
**Estimated:** 15 minutes

**Command:**
```bash
codex-task "Create g/manuals/codex_quick_reference.md: Write 1-page guide with sections: (1) When to use Codex vs CLC, (2) codex-task command format, (3) Common patterns (add check, fix bug, refactor), (4) Validation steps, (5) Rollback if needed. Keep under 100 lines."
```

---

#### Task 3.3: Document Tier 2 setup in README
**File:** `tools/README.md` or `CODEX_SETUP.md`
**Issue:** Tier 2 setup not documented for new users
**Fix:** Add Tier 2 configuration guide
**Engine:** Codex (interactive)
**Priority:** P3
**Estimated:** 15 minutes

**Command:**
```bash
codex-task "Document Tier 2 setup: Create tools/CODEX_SETUP.md with (1) Prerequisites (Codex CLI 0.77.0+), (2) Tier 2 config (~/.codex/config.toml), (3) Permissions (read anywhere, write to workspace), (4) Safety settings, (5) Testing. Include copy-paste config."
```

---

#### Task 3.4: Update session_save.zsh inline comments
**File:** `tools/session_save.zsh`
**Issue:** Comments don't reflect jq fixes (still say "manual escaping")
**Fix:** Update comments to reflect new jq -nc approach
**Engine:** Codex (interactive)
**Priority:** P4
**Estimated:** 5 minutes

**Command:**
```bash
codex-task "Update comments in tools/session_save.zsh: Update telemetry section comments (lines 58-70) to reflect new jq -nc approach instead of old 'manual escaping' language. Be accurate about auto-escaping and type preservation."
```

---

#### Task 3.5: Create routing decision flowchart
**File:** `g/docs/CODEX_ROUTING_FLOWCHART.md`
**Issue:** No visual guide for "CLC or Codex?" decision
**Fix:** Create text-based flowchart
**Engine:** Codex (interactive)
**Priority:** P3
**Estimated:** 10 minutes

**Command:**
```bash
codex-task "Create g/docs/CODEX_ROUTING_FLOWCHART.md: Text-based decision flowchart for routing tasks. Start with question 'Is it in locked zone?' → Yes = CLC. No → 'Is it security-critical?' → Yes = CLC. Continue with file count, complexity, etc. End with clear CLC or Codex decision."
```

---

## Execution Strategy

### Week 1 Timeline

**Day 1-2: Reliability (Bucket 1)**
- Task 1.1: jq check in mls_search.zsh
- Task 1.3: JSON validation in metrics summary
- Task 1.5: Error messages in mary_preflight

**Day 3-4: Refactor (Bucket 2)**
- Task 2.1: Extract MLS parsing function
- Task 2.3: Path handling in log_codex_task
- Task 2.4: Git checkpoint refactor

**Day 5-7: Docs (Bucket 3)**
- Task 3.1: Action plan final summary
- Task 3.2: Codex quick reference
- Task 3.3: Tier 2 setup docs

**Deferred (P4 priority):**
- Task 1.4: Atomic write (needs more design)
- Task 2.2: Deduplicate jq (multi-file, needs CLC)
- Task 2.5: Standardize quoting (low impact)
- Task 3.4: Update comments (cosmetic)
- Task 3.5: Routing flowchart (optional)

---

## Success Metrics

### Primary Goals
- **Tasks routed to Codex:** 10+ tasks
- **CLC quota saved:** 40%+ (vs doing all with CLC)
- **Quality maintained:** Average 8/10+
- **Zero regressions:** All fixes validated

### Tracking
**Log every task:**
```bash
zsh ~/02luka/tools/log_codex_task.zsh \
  "<task_type>" \
  "<codex command>" \
  <quality_score>
```

**View metrics:**
```bash
zsh ~/02luka/tools/codex_metrics_summary.zsh
```

### Week 1 Report Checklist
- [ ] Total tasks routed: __/10
- [ ] Average quality: __/10
- [ ] CLC quota saved: __%
- [ ] Issues encountered: __
- [ ] Rollbacks needed: __
- [ ] Lessons learned: __

---

## Risk Mitigation

### Before Each Task
1. ✅ Git checkpoint exists (codex-task wrapper does this)
2. ✅ Task matches Codex criteria (not locked zone, clear scope)
3. ✅ Validation plan ready (how to test the fix)

### After Each Task
1. ✅ Review diff (`git diff <file>`)
2. ✅ Test functionality (run the script/command)
3. ✅ Validate edge cases if applicable
4. ✅ Log quality score
5. ✅ Commit or rollback

### If Quality < 7/10
- Don't commit
- Rollback: `git reset --hard HEAD~1`
- Route to CLC instead
- Document why Codex struggled

---

## Codex TTY Workaround

**Issue:** `codex-task` fails with "stdin is not a terminal"

**Workaround Options:**

**Option A: Boss runs interactively** (current approach)
```bash
# Boss opens terminal and runs:
cd ~/02luka
codex-task "<instruction>"
```

**Option B: CLC prepares task specs** (Issue #3 pattern)
1. CLC creates task spec in `tmp/codex_task_NNN.md`
2. Boss runs command from spec
3. CLC validates result

**Option C: Fix codex-task wrapper** (future)
- Investigate TTY requirement
- May need to spawn interactive shell
- Test with `script` command or similar

**Current Status:** Using Option A (Boss runs interactively)

---

## Notes from Phase Testing

### What Worked Well
✅ Codex identified real issues (4/4 findings valid)
✅ Interactive mode works when Boss runs
✅ Quality 9-10/10 for targeted fixes
✅ Git checkpoint provides safety net

### What Needs Attention
⚠️ Codex doesn't test by default (must request)
⚠️ TTY limitation blocks automation
⚠️ Multi-file changes risky for Codex
⚠️ Boss must validate all changes

### Recommendations
1. Start with P2-P3 tasks (low risk)
2. Validate every fix before committing
3. Log quality scores honestly
4. Don't force Codex for complex tasks
5. Use CLC when uncertain

---

## Contact Points

**Questions/Blockers:** Ask Boss
**Codex Issues:** Document in WEEK1_ROUTING_REPORT.md
**Quality Issues:** Rollback and route to CLC

---

**Created:** 2025-12-31
**Status:** Ready for Week 1 execution
**Goal:** Prove Codex can handle 40%+ of non-locked tasks with 8+ quality

**Let's validate the Codex enhancement investment!** 🚀
