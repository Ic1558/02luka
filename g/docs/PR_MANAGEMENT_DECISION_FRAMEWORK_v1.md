# PR Management Decision Framework v1

**Status**: ACTIVE
**Version**: 1.0
**Last Updated**: 2025-12-19
**Reviewed After**: PR #407, #408
**Owner**: Boss + CLS

---

## Purpose

This framework provides systematic decision rules for PR management operations, transferring knowledge from:
- Governance documents (GOVERNANCE_UNIFIED_v5.md, AI_OP_001_v5.md)
- Recent experience (PR #407, #408 merge patterns)
- Boss's decision-making patterns

**Goal**: Enable CLS to handle PR decisions independently with clear rules and safety gates.

---

## 3 Gates (Classification System)

Every PR must pass through 3 gates to determine the correct action.

### Gate A: PR Zone Classification

Classify PR based on files touched:

| Zone | File Patterns | Risk Level | Examples |
|------|---------------|------------|----------|
| **GOVERNANCE** | `g/docs/GOVERNANCE*`, `g/docs/AI_OP_001*` | HIGH | Policy docs, operational protocols |
| **LOCKED_CORE** | `bridge/core/*`, `core/*` | HIGH | Router v5, SandboxGuard v5, WO Processor |
| **DOCS** | `g/docs/*`, `g/reports/*`, `g/manuals/*` | LOW | Documentation, reports, manuals |
| **OPEN** | `tools/*`, `tests/*`, `apps/*` | MEDIUM | Operational tools, test files, applications |
| **AUTO_GENERATED** | `hub/index.json`, `hub/README.md` | SPECIAL | Auto-generated catalog files |

**Rule**: Read PR file list → classify into ONE primary zone (if mixed, use highest risk zone)

**Example from PR #407, #408**:
- PR #408: Touches `g/docs/GOVERNANCE_UNIFIED_v5.md`, `g/docs/PERSONA_MODEL_v5.md` → **GOVERNANCE zone**
- PR #407: Touches `personas/GEMINI_PERSONA_v5.md` → **DOCS zone**

---

### Gate B: Dependency Order Rules

Determine if PR has merge dependencies on other PRs:

#### Priority Order (High to Low):
1. **Governance before implementation** - Governance PRs merge before feature PRs
2. **Schema/contract before code** - Contract/schema changes before code that uses them
3. **Core before extensions** - Router/SandboxGuard before tools that call them
4. **Auto-generated files handled separately** - Regenerate after merge, don't merge manually

#### Dependency Detection:

**Check if other open PRs might block this one**:
```bash
# Get all open PRs
gh pr list --state open --json number,title,files

# If any open PR is GOVERNANCE zone → non-governance PRs must wait
```

**Example from PR #407, #408**:
- PR #408 (GOVERNANCE) and PR #407 (DOCS) both open
- **Decision**: Merge PR #408 FIRST, then PR #407
- **Reason**: Governance defines rules that features/docs must follow

---

### Gate C: Mergeability Check

Check 3 values for each PR:

1. **PR mergeable status**:
   ```bash
   gh pr view <number> --json mergeable
   ```
   Result: `MERGEABLE`, `CONFLICTING`, or `UNKNOWN`

2. **Branch divergence**:
   ```bash
   gh pr view <number> --json commits
   ```
   Count commits - if >5 behind main, consider rebase

3. **Conflict file types**:
   - If conflicts exist, classify conflict files by zone
   - Auto-generated file conflicts = special handling
   - LOCKED/core conflicts = requires Boss review

**Decision Matrix**:
- **MERGEABLE + no blockers** → Proceed to Outcomes
- **CONFLICTING** → Check conflict resolution policy
- **Behind >5 commits** → Recommend rebase first

---

## 4 Outcomes (Decision Matrix)

After passing 3 gates, choose ONE outcome:

### Outcome 1: Merge Now

**Conditions** (ALL must be true):
- Zone is DOCS or OPEN (not GOVERNANCE/LOCKED_CORE)
- Mergeable status = MERGEABLE
- No dependency blockers (no governance PR waiting)
- Changes are small/focused

**Action**:
```bash
gh pr merge <number> --squash
```

**After merge**:
```bash
# For persona PRs
tools/verify_persona_v3.zsh

# For any PR that touches governance
git worktree add /tmp/verify-pr-<num> main
cd /tmp/verify-pr-<num>
# Verify docs are consistent
cd ~/02luka
git worktree remove /tmp/verify-pr-<num>
```

---

### Outcome 2: Rebase/Update Branch

**Conditions**:
- Behind main by >5 commits OR diverged significantly
- No complex conflicts (or conflicts are easily resolvable)
- Not blocked by dependencies

**Action**:
```bash
gh pr checkout <number>
git pull origin main --rebase
# Fix simple conflicts if any
git push --force-with-lease
```

**When to use this**:
- PR has fallen behind main
- Conflicts are minor (docs, formatting, etc.)
- Want to test against latest main before merging

---

### Outcome 3: Resolve Conflicts (Policy-Based)

**Conditions**:
- Mergeable status = CONFLICTING
- Conflicts can be resolved with clear policy

**Policy for auto-generated files**:
```bash
# ALWAYS use origin/main for auto-generated files
gh pr checkout <number>
git pull origin main

# For hub/index.json, hub/README.md
git checkout origin/main -- hub/index.json
git checkout origin/main -- hub/README.md

git add hub/index.json hub/README.md
git commit -m "resolve: use origin/main for auto-generated files (will regenerate)"
git push
```

**Rationale**: Auto-generated files will be regenerated after merge anyway, manual merge is wasted effort.

**Policy for docs conflicts**:
- Choose version that aligns with `GOVERNANCE_UNIFIED_v5.md`
- If both valid, prefer newer/more complete version
- If unclear, ask Boss

**Policy for code conflicts**:
- **LOCKED/core code** → ❌ BLOCK & Ask Boss (don't guess)
- **OPEN code** → Use context to decide, verify tests pass
- **When in doubt** → Ask Boss

**Example from PR #407**:
- Conflict file: `hub/index.json`
- Zone: AUTO_GENERATED
- **Decision**: Use `origin/main` version (policy-based)
- **Result**: Resolved automatically without Boss intervention ✅

---

### Outcome 4: Block & Ask Boss

**Conditions** (ANY one triggers this):
- LOCKED/core/bridge changes with high impact
- Governance law / routing logic conflicts
- Risk of changing semantics (not just merge)
- First-time pattern (not covered by framework)
- Complex conflict that doesn't match any policy

**Action**: Ask Boss with evidence:
```
PR #<X> touches [files].
Zone: <GOVERNANCE/LOCKED_CORE/etc.>
Impact: <HIGH/MEDIUM>
Conflict: <Yes/No>
Recommendation: <Merge/Wait/Resolve/Block>

Approve to proceed?
```

**When to use this**:
- Any uncertainty about safety
- High-risk changes that could break system
- New patterns not yet documented

---

## Auto-Generated Files List

These files should ALWAYS use `origin/main` version in conflicts:

```
hub/index.json
hub/README.md
g/reports/health/*.json (can be regenerated)
mls/adaptive/insights_*.json (MLS output)
```

**Why**: These files are generated by tools/scripts. Manual merge will be overwritten on next generation.

---

## Verification After Merge

### For Persona PRs:
```bash
tools/verify_persona_v3.zsh
```

### For Governance PRs:
```bash
git worktree add /tmp/verify-pr-<num> main
cd /tmp/verify-pr-<num>

# Verify governance docs are consistent
grep -E "^## " g/docs/GOVERNANCE_UNIFIED_v5.md
grep -E "^## " g/docs/AI_OP_001_v5.md

cd ~/02luka
git worktree remove /tmp/verify-pr-<num>
```

### For Core/Bridge PRs:
```bash
# Run v5 health checks
tools/monitor_v5_production.zsh
tools/system_health_check.zsh

# Check telemetry
tail -20 g/telemetry/gateway_v3_router.jsonl
```

---

## Case Studies (Learning from Experience)

### Case Study 1: PR #407 vs #408 (Merge Order)

**Context**:
- PR #408: Restore `GOVERNANCE_UNIFIED_v5.md`, `PERSONA_MODEL_v5.md` (GOVERNANCE zone)
- PR #407: Add `GEMINI_PERSONA_v5.md` (DOCS zone)
- Both open simultaneously
- PR #407 has conflict with main (`hub/index.json`)

**Gates Analysis**:
- **Gate A**: #408 = GOVERNANCE, #407 = DOCS
- **Gate B**: #408 blocks #407 (governance first rule)
- **Gate C**: #407 = CONFLICTING (hub/index.json), #408 = MERGEABLE

**Decision**:
1. Merge PR #408 first (governance priority)
2. Then resolve PR #407 conflicts (use origin/main for hub/index.json)
3. Then merge PR #407

**Outcome**: ✅ Success
- Governance rules established before persona docs
- Conflict resolved with policy (auto-generated file)
- No data loss, no rework needed

**Learning**: Governance-first rule prevents dependency issues

---

### Case Study 2: hub/index.json Conflict Resolution

**Context**:
- PR #407 conflicts with main on `hub/index.json`
- File is auto-generated by catalog tools

**Policy Applied**:
- AUTO_GENERATED zone → use origin/main version
- Don't manually merge → will regenerate anyway

**Action Taken**:
```bash
gh pr checkout 407
git pull origin main
git checkout origin/main -- hub/index.json
git add hub/index.json
git commit -m "resolve: use origin/main for auto-generated hub/index.json"
git push
```

**Outcome**: ✅ Success
- Conflict resolved in <1 minute
- No Boss intervention needed
- File regenerated correctly after merge

**Learning**: Auto-generated file policy saves time and prevents errors

---

## Quick Reference

### Decision Tree:

```
1. Is PR open?
   ├─ Yes → Continue to Gate A
   └─ No → Nothing to do

2. Gate A: What zone?
   ├─ GOVERNANCE → Gate B (high priority)
   ├─ LOCKED_CORE → Gate B (high priority)
   ├─ DOCS → Gate B (low priority)
   ├─ OPEN → Gate B (medium priority)
   └─ AUTO_GENERATED → Gate C (special handling)

3. Gate B: Any blockers?
   ├─ Yes (governance PR waiting) → Outcome 4 (WAIT)
   ├─ Yes (schema PR waiting) → Outcome 4 (WAIT)
   └─ No → Gate C

4. Gate C: Mergeable?
   ├─ MERGEABLE → Outcome 1 (MERGE NOW)
   ├─ CONFLICTING (auto-generated) → Outcome 3 (policy-based)
   ├─ CONFLICTING (LOCKED) → Outcome 4 (ASK BOSS)
   └─ Behind >5 commits → Outcome 2 (REBASE)
```

### Command Cheat Sheet:

```bash
# Analyze PR
pr-check <number>

# Analyze all open PRs
pr-check

# Merge (safe zones only)
gh pr merge <number> --squash

# Rebase
gh pr checkout <number>
git pull origin main --rebase
git push --force-with-lease

# Resolve auto-generated conflict
gh pr checkout <number>
git pull origin main
git checkout origin/main -- hub/index.json
git add hub/index.json
git commit -m "resolve: use origin/main for auto-generated files"
git push

# Verify after merge
tools/verify_persona_v3.zsh  # Persona PRs
git worktree add /tmp/verify main && cd /tmp/verify  # Governance PRs
```

---

## Framework Updates

This framework should be updated when:
1. New patterns emerge (document as case studies)
2. New zones are defined (update Gate A table)
3. New policies are established (update Outcome 3)
4. Mistakes happen (document what went wrong, add prevention rule)

**Update format**:
```markdown
### Case Study X: [Title]
Context: [What happened]
Gates Analysis: [How gates evaluated it]
Decision: [What was decided]
Outcome: [Success/Failure]
Learning: [What we learned]
```

**Version History**:
- v1.0 (2025-12-19): Initial framework based on PR #407, #408 experience

---

## Integration with seal-now

This framework is integrated with `seal-now` workflow via PR preflight check:

**seal-now behavior**:
- Runs PR preflight check BEFORE review step
- Blocks if: GOVERNANCE/LOCKED_CORE zone OR merge conflicts
- Safe zones (DOCS/OPEN) proceed automatically
- Override: `seal-now --skip-pr-check` (Boss approval)

See `tools/workflow_dev_review_save.py` for implementation.

---

## References

- `g/docs/GOVERNANCE_UNIFIED_v5.md` - Zone definitions, routing rules
- `g/docs/AI_OP_001_v5.md` - Lane system, SIP requirements
- `tools/pr_decision_advisory.zsh` - Advisory tool implementing this framework
- `tools/workflow_dev_review_save.py` - seal-now integration
- PR #407, #408 - Case studies

---

**Questions or updates**: Contact Boss or update this document with new learnings.
