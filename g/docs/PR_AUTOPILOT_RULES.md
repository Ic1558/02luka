# PR_AUTOPILOT_RULES.md
**Status:** ACTIVE  
**Owner:** Boss (final) / CLS (operator)  
**Scope:** PR management (analyze → decide → resolve → merge → verify → cleanup)  
**SOT:** /Users/icmini/02luka

---

## 0) One-line Mission
CLS must handle PRs end-to-end with **minimum interruption**, following governance + safety gates, and only escalate when risk is real.

---

## 1) Two Worlds + Authority (hard rule)
- **World 1 (CLI / Interactive):** Boss/CLS can act directly.
- **World 2 (Background):** strict (WO/automation lanes apply).

**Boss is final authority.**  
CLS may proceed without asking only when below rules say "AUTO".

---

## 2) Zone Classification (Gate A)
Classify PR by highest-risk file touched:

- **GOVERNANCE (HIGH):** `g/docs/(GOVERNANCE*|AI_OP_001*|PERSONA_MODEL*)`
- **LOCKED_CORE (HIGH):** `core/**`, `bridge/core/**`
- **AUTO_GENERATED (SPECIAL):** `hub/index.json`, `hub/README.md`, generated health/json
- **DOCS (LOW):** `g/docs/**`, `g/reports/**`, `g/manuals/**`, `personas/**`
- **OPEN (MED):** `tools/**`, `tests/**`, `apps/**`, `agents/**` (non-core)

**Rule:** If mixed → take highest risk zone.

---

## 3) Merge Order (Gate B)
Priority order:
1) GOVERNANCE before anything else  
2) Schema/contract before code using it  
3) Core before extensions/tools  
4) AUTO_GENERATED handled by policy (don't "hand-merge")

If any open PR is GOVERNANCE and current PR is not → **WAIT**.

---

## 4) Mergeability & Divergence (Gate C)
CLS checks:
- `mergeable`: MERGEABLE / CONFLICTING / UNKNOWN
- branch behind main: if significantly behind → **REBASE first**
- conflict file types: auto-generated vs core vs docs

---

## 5) Conflict Policy (non-negotiable)
### 5.1 AUTO_GENERATED conflicts
Always prefer `origin/main` version:
- `hub/index.json`, `hub/README.md`, generated outputs

Rationale: will be regenerated; manual merge wastes time and adds risk.

### 5.2 DOCS conflicts
Choose the version that aligns with:
1) `GOVERNANCE_UNIFIED_v5.md` (SOT)
2) newer timestamp / clearer wording
If unclear → ask Boss (brief, evidence-based)

### 5.3 LOCKED_CORE / GOVERNANCE conflicts
**STOP. Escalate to Boss.** No guessing.

---

## 6) Allowed Automation Outcomes
CLS may do without Boss approval:

### AUTO: Merge Now
Only if ALL true:
- Zone = DOCS or OPEN
- mergeable = MERGEABLE
- no blockers (Gate B clear)
- change scope small/focused

**Default merge strategy:** For DOCS/OPEN PRs, CLS MUST use squash merge (1 PR = 1 commit). Use merge commit only when Boss explicitly requests preserving commit history.

### AUTO: Resolve Conflicts (policy-only)
Only if conflict files are strictly AUTO_GENERATED (or trivial docs formatting) and policy is clear.

### AUTO: Rebase
If behind main and conflicts are minor (DOCS/OPEN only). Use force-with-lease only.

---

## 7) When CLS MUST Ask Boss (hard gate)
Any of these triggers:
- Zone = GOVERNANCE or LOCKED_CORE
- Conflicts in core/bridge/governance
- Any destructive action on main history (force push to main, rewriting remote)
- Unclear policy choice / first-time pattern
- **Direct push to main (forbidden unless Boss explicitly orders)**

Escalation format (short):
- PR #: title
- zone + files
- risk
- recommendation
- exact commands CLS will run after approval

---

## 8) Post-merge Verification (must do)
**Minimum verify (3 steps):**
1. `git pull origin main` (sync local)
2. `pr-check <merged_pr>` (optional, verify decision was correct)
3. Run relevant verify scripts if available

**Full verify:**
- Confirm files exist where expected
- Regenerate auto-generated artifacts if the system expects it
- Summarize: what changed, what verified, remaining risks

---

## 9) Cleanup
After merge:
- sync local main
- delete local branch (safe)
- delete remote branch (if not auto)
- update any checklist/log (optional)

---

## 10) Default Tools
- Advisory: `tools/pr_decision_advisory.zsh` (pr-check)
- Governance: `g/docs/PR_MANAGEMENT_DECISION_FRAMEWORK_v1.md`
- Worlds: `g/docs/HOWTO_TWO_WORLDS_v2.md`
