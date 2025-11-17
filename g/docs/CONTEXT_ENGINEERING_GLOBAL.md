# Context Engineering Global Specification
**Version:** 1.0.0-DRAFT
**Status:** ⚠️ SUPERSEDED - Refer to v3 Protocol
**Last Updated:** 2025-11-17
**Maintainer:** Boss (ittipong.c@gmail.com)

---

## ⚠️ DEPRECATION NOTICE

**This document has been superseded by formal RFC-style protocols:**

| Protocol | Purpose | Path |
|----------|---------|------|
| **Context Engineering Protocol v3** | Agent capabilities, fallback procedures, enforcement | `CONTEXT_ENGINEERING_PROTOCOL_v3.md` |
| **Path and Tool Protocol** | Path usage rules, tool registry, validation gates | `PATH_AND_TOOL_PROTOCOL.md` |
| **Multi-Agent PR Contract** | PR routing, governance, agent coordination | `MULTI_AGENT_PR_CONTRACT.md` |

**Migration Status:**
- ✅ RFC-style protocols created (MUST/SHALL/MAY language)
- ✅ Enforcement mechanisms defined (git hooks, validation gates)
- ✅ Formal capability matrices established
- ⚠️ This document retained for REFERENCE ONLY

**When to use this document:**
- Quick overview of context architecture (diagrams, tables)
- FAQ-style questions about agent behavior
- Understanding layer model and flow patterns

**When to use v3 protocols:**
- Authoritative rules for agent capabilities
- Enforcement and validation requirements
- Compliance checking and pre-commit hooks
- Making architectural decisions

---

## Purpose (Original)

This document defines the **global context engineering architecture** for the 02luka system. It answers:

1. **Who can think?** (which agents can reason and make decisions)
2. **Who can write?** (which agents can commit to SOT repositories)
3. **What is the fallback ladder?** (when primary writers fail)
4. **How do contexts flow?** (from GG → GC → CLC → Codex → LPE → Kim)

**Why this matters:**
- Prevents context chaos (multiple agents writing to same files)
- Enables clear ownership (who owns which layer)
- Defines graceful degradation (what happens when CLC is out of tokens)
- Establishes audit trails (who wrote what, when, why)

---

## Context Layers & Ownership

### Layer Model

```
┌─────────────────────────────────────────────────────────────┐
│ Layer 1: GG (Governance Gate)                               │
│ - Role: Strategic oversight, policy decisions               │
│ - Can Think: ✅ Yes (strategic reasoning)                   │
│ - Can Write: ✅ Yes (via GC delegation)                     │
│ - Primary Output: Governance reports, policy docs           │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│ Layer 2: GC (Governance Copilot)                            │
│ - Role: Tactical execution of GG decisions                  │
│ - Can Think: ✅ Yes (tactical reasoning)                    │
│ - Can Write: ✅ Yes (governance docs, PRPs, specs)          │
│ - Primary Output: Implementation specs, review reports      │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│ Layer 3: CLC (Claude Code)                                  │
│ - Role: Operational execution, code writing                 │
│ - Can Think: ✅ Yes (operational reasoning)                 │
│ - Can Write: ✅ Yes (code, configs, scripts, reports)       │
│ - Primary Output: Code commits, operational reports         │
│ - Token Limit: 200K/session (monitored)                     │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│ Layer 4: Codex (Cursor AI / VSCode Extension)               │
│ - Role: Development assistant, code exploration             │
│ - Can Think: ✅ Yes (code understanding, suggestions)       │
│ - Can Write: ❌ NO (cannot commit to SOT)                   │
│ - Primary Output: Code suggestions, analysis (ephemeral)    │
│ - Constraint: Cannot push to git, cannot modify SOT files   │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│ Layer 5: LPE (Local Prompt Executor)                        │
│ - Role: Fallback writer when CLC is unavailable             │
│ - Can Think: ❌ NO (executes Boss instructions only)        │
│ - Can Write: ✅ Yes (via Boss approval + MLS logging)       │
│ - Primary Output: Emergency writes, Boss-dictated changes   │
│ - Trigger: CLC out-of-tokens OR CLC session unavailable     │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│ Layer 6: Kim (API Gateway / Orchestrator)                   │
│ - Role: External API coordination, multi-agent dispatch     │
│ - Can Think: ✅ Yes (routing decisions, priority queuing)   │
│ - Can Write: ❌ NO (delegates to CLC or LPE)                │
│ - Primary Output: Task delegation, API responses            │
└─────────────────────────────────────────────────────────────┘
```

---

## Who Can Do What

### Thinking Capability

| Agent | Can Think? | Reasoning Scope | Example |
|-------|------------|-----------------|---------|
| GG | ✅ Yes | Strategic governance | "Should we adopt feature X based on risk/value analysis?" |
| GC | ✅ Yes | Tactical execution | "How do we implement GG decision Y safely?" |
| CLC | ✅ Yes | Operational coding | "What's the best way to fix this LaunchAgent path issue?" |
| Codex | ✅ Yes | Code exploration | "This function looks like it handles authentication..." |
| LPE | ❌ NO | (Executes Boss orders) | Boss: "Write this code to file X" → LPE: *writes without reasoning* |
| Kim | ✅ Yes | Routing/orchestration | "This task should go to CLC, that one to GC" |

### Writing Capability (Commit to SOT)

| Agent | Can Write? | Where Can Write | Approval Required |
|-------|------------|-----------------|-------------------|
| GG | ✅ Yes | Governance docs, policy | GG self-approval (Boss oversight) |
| GC | ✅ Yes | Specs, PRPs, reviews | GG approval |
| CLC | ✅ Yes | Code, configs, scripts, reports | Self-approved (operational) |
| Codex | ❌ NO | (Cannot commit) | N/A |
| LPE | ✅ Yes | Any file Boss specifies | Boss approval + MLS log |
| Kim | ❌ NO | (Delegates to others) | N/A |

**Key Constraint:**
- **Codex cannot write to SOT** because it runs in Cursor IDE without git commit permissions
- **Codex can help CLC think** but CLC must execute the actual commits
- **LPE is the emergency backup** when CLC is unavailable

---

## Fallback Ladder: When CLC Is Unavailable

### Scenario 1: CLC Out of Tokens

```
CLC session reaches 200K tokens → Cannot continue
           ↓
Boss decides: Continue with LPE or wait for new CLC session?
           ↓
Option A: LPE Fallback
  - Boss dictates changes to LPE
  - LPE executes writes (no thinking, just Boss orders)
  - All LPE actions logged to MLS (who, what, why, when)
  - Next CLC session reviews LPE changes

Option B: Wait for New Session
  - Boss opens new CLC session
  - Continue work with fresh 200K budget
```

### Scenario 2: CLC Session Unavailable

```
Boss needs urgent change but CLC session not open
           ↓
Boss uses LPE as fallback writer
           ↓
LPE writes file per Boss instruction
           ↓
LPE logs to MLS:
  - Timestamp: 2025-11-17T06:00:00
  - Producer: LPE
  - Action: Write file X
  - Reason: CLC unavailable, Boss urgent request
  - Boss approval: [Boss message ID]
           ↓
Next CLC session sees MLS log
           ↓
CLC reviews change, validates correctness
```

### Scenario 3: Codex Wants to Help

```
Boss asks Codex: "How do I fix this bug?"
           ↓
Codex analyzes code, suggests solution
           ↓
Boss: "Looks good, write it"
           ↓
Codex: "I cannot write to git. Please use CLC or LPE."
           ↓
Boss opens CLC session OR uses LPE
           ↓
Change committed via authorized writer
```

**Rule:** Codex is **read-only** for SOT. It can suggest, but not execute SOT changes.

---

## Context Flow Patterns

### Pattern 1: Normal Operation (CLC Active)

```
Boss request → CLC receives
           ↓
CLC thinks + plans
           ↓
CLC writes code/docs
           ↓
CLC commits to git
           ↓
CLC reports to Boss
           ↓
MLS captures learnings
```

**Tools:** CLC uses all available tools (Read, Write, Edit, Bash, Git)

### Pattern 2: CLC + Codex Collaboration

```
Boss: "Help me understand this codebase"
           ↓
CLC explores with Task tool
           ↓
Boss opens Cursor (Codex active)
           ↓
Codex provides IDE-based suggestions
           ↓
Boss decides what to implement
           ↓
Boss → CLC: "Implement solution X"
           ↓
CLC writes + commits
```

**Handoff:** Codex thinks → CLC writes

### Pattern 3: GG → GC → CLC Cascade

```
GG decides: "We need feature X for governance"
           ↓
GG → GC: "Create implementation spec for X"
           ↓
GC writes spec + PRP
           ↓
GC → CLC: "Implement according to spec"
           ↓
CLC executes implementation
           ↓
CLC → GC: "Implementation complete, ready for review"
           ↓
GC reviews + approves
           ↓
GG validates governance compliance
```

**Delegation Chain:** GG → GC → CLC (each layer adds detail)

### Pattern 4: LPE Emergency Fallback

```
CLC hits token limit mid-task
           ↓
Boss: "I need this file updated NOW"
           ↓
Boss → LPE: "Write this content to file Y"
           ↓
LPE writes (no thinking, just execute)
           ↓
LPE logs to MLS: "Emergency write by LPE, Boss approval [ID]"
           ↓
Next CLC session: Review MLS log
           ↓
CLC validates LPE changes
           ↓
If issues found: CLC fixes + reports
```

**Safety:** All LPE writes logged for CLC review

### Pattern 5: Kim Multi-Agent Orchestration

```
External request → Kim API
           ↓
Kim analyzes: "This needs code change + governance review"
           ↓
Kim → CLC: "Implement change"
           ↓
Kim → GC: "Review for governance compliance"
           ↓
Both complete → Kim aggregates results
           ↓
Kim → External caller: "Task complete with governance approval"
```

**Orchestration:** Kim routes to appropriate agents but doesn't write itself

---

## Integration with MLS (Multi-Loop Learning System)

### MLS Capture Points

1. **CLC writes code** → MLS captures:
   - What was written
   - Why (context from conversation)
   - Outcome (success/failure)

2. **LPE fallback write** → MLS captures:
   - Timestamp
   - Producer: LPE
   - Boss approval reference
   - Reason for LPE use (CLC unavailable)

3. **GC governance decision** → MLS captures:
   - Decision made
   - Rationale
   - GG approval status

4. **Codex suggestion accepted** → MLS captures:
   - Suggestion content
   - Who accepted (Boss)
   - Final implementation (by CLC)

### MLS Query Examples

```bash
# Find all LPE writes
node ~/02luka/knowledge/index.cjs --hybrid "LPE emergency write"

# Find CLC token limit incidents
node ~/02luka/knowledge/index.cjs --hybrid "token limit fallback"

# Find Codex suggestions that became implementations
node ~/02luka/knowledge/index.cjs --hybrid "Codex suggestion implemented"
```

---

## Integration with LaunchAgents

### Agent-Triggered Workflows

**LaunchAgent** → **Which Context Layer?**

| Agent | Triggers | Context Layer | Example |
|-------|----------|---------------|---------|
| mls.cursor.watcher | Cursor prompt capture | → MLS | Captures Codex interactions for learning |
| mary.dispatcher | Work order routing | → Kim → CLC/GC | Routes tasks to appropriate agent |
| backup.gdrive | Data sync | → Local script (no AI) | No context layer (pure automation) |
| health.dashboard | Status generation | → Local script | Generates JSON without AI reasoning |
| gg.nlp-bridge | Governance routing | → GG/GC | Routes governance decisions |

**Rule:** LaunchAgents can trigger AI agents but don't think themselves

---

## Prevention Mechanisms

### 1. Pre-Commit Validation

**Who can commit?** Only authorized writers (GG, GC, CLC, LPE)

**How to prevent unauthorized writes?**

```bash
# Git pre-commit hook
if [[ $COMMITTER == "Codex" ]]; then
  echo "❌ Codex cannot commit to SOT"
  echo "Use CLC or LPE as fallback writer"
  exit 1
fi
```

### 2. MLS Audit Trail

**Every SOT write must log:**
- Who wrote (GG/GC/CLC/LPE)
- When (timestamp)
- Why (context/reason)
- Boss approval (if LPE)

**Example MLS entry:**
```json
{
  "timestamp": "2025-11-17T06:00:00",
  "producer": "LPE",
  "type": "emergency_write",
  "file": "g/tools/script.zsh",
  "reason": "CLC out of tokens, Boss urgent request",
  "approval": "Boss message 2025-11-17T05:59:00",
  "content_hash": "a1b2c3d4..."
}
```

### 3. Token Budget Monitoring

**CLC token usage:**
- Warning at 150K tokens
- Alert at 180K tokens
- Fallback to LPE at 190K+ tokens

**Monitoring:**
```bash
# Check current CLC session token usage
# (CLC provides this in responses)
echo "Tokens used: 88,000 / 200,000"
```

### 4. Codex Constraints

**Codex capabilities:**
- ✅ Can read all files
- ✅ Can suggest changes
- ✅ Can analyze code
- ❌ Cannot commit to git
- ❌ Cannot write to SOT directly

**Enforcement:**
- Cursor runs in IDE without git push permissions
- Boss manually copies Codex suggestions to CLC
- Or Boss dictates to LPE if CLC unavailable

---

## Common Scenarios & Resolutions

### Q1: Codex suggests a code change. How do I apply it?

**Answer:**

Option A (CLC available):
```
1. Codex provides suggestion
2. Boss → CLC: "Implement this change: [paste suggestion]"
3. CLC writes code + commits
4. MLS logs: "Codex suggestion implemented by CLC"
```

Option B (CLC unavailable):
```
1. Codex provides suggestion
2. Boss → LPE: "Write this code to file X: [paste code]"
3. LPE writes + logs to MLS
4. Next CLC session reviews LPE write
```

### Q2: CLC is out of tokens mid-task. What now?

**Answer:**

```
1. Boss checks: Is this urgent?

   If YES:
     → Use LPE fallback
     → Boss dictates remaining changes
     → LPE writes + logs to MLS
     → Task continues

   If NO:
     → Open new CLC session
     → Continue with fresh 200K budget
     → Previous session context via MLS
```

### Q3: Who decides when to use GG vs. GC vs. CLC?

**Answer:**

```
Use GG when:
  - Strategic policy decisions
  - Governance compliance questions
  - Risk/value assessments

Use GC when:
  - Tactical implementation planning
  - Code review for governance
  - Spec/PRP creation

Use CLC when:
  - Operational code writing
  - Bug fixes
  - Script creation
  - Day-to-day development
```

**Rule of thumb:**
- Strategy → GG
- Planning → GC
- Execution → CLC

### Q4: Can Kim write code directly?

**Answer:**

❌ **NO**. Kim is an **orchestrator**, not a writer.

```
Kim's role:
  ✅ Receive external requests
  ✅ Route to appropriate agent (GC/CLC)
  ✅ Aggregate results
  ✅ Return to caller
  ❌ Write code itself

If Kim needs code written:
  Kim → CLC: "Write this code"
  CLC writes + commits
  CLC → Kim: "Done"
  Kim → Caller: "Task complete"
```

### Q5: What if LPE makes a mistake?

**Answer:**

```
1. LPE writes file (Boss-dictated)
2. LPE logs to MLS
3. Next CLC session opens
4. CLC reads MLS log: "LPE wrote file X on 2025-11-17"
5. CLC reviews file X
6. If incorrect:
     CLC fixes + commits correction
     CLC logs to MLS: "Fixed LPE error in file X"
7. If correct:
     CLC validates + moves on
```

**Safety net:** CLC always reviews LPE writes

---

## Glossary

**SOT (Single Source of Truth):**
- Git repositories containing authoritative code/docs
- Only authorized writers can commit
- All changes tracked via git + MLS

**Context Layer:**
- Hierarchical level in the 02luka agent system
- Each layer has specific capabilities and constraints

**Authorized Writer:**
- Agent that can commit to SOT repos
- Currently: GG, GC, CLC, LPE (with Boss approval)

**Read-Only Agent:**
- Agent that can analyze but not write to SOT
- Currently: Codex, Kim (delegates writes to others)

**Token Budget:**
- Maximum tokens per CLC session (200K)
- Monitored to prevent mid-task failures

**MLS (Multi-Loop Learning System):**
- Knowledge base capturing decisions, learnings, patterns
- Searchable via `knowledge/index.cjs`
- Used for context persistence across sessions

**PRP (Problem-Requirements-Plan):**
- Structured workflow for feature planning
- Created by GC, executed by CLC

---

## Maintenance

**This document should be updated when:**

1. New agent added to system
2. Capabilities change (e.g., Codex gains write permission)
3. Token budgets change
4. Fallback procedures evolve
5. Integration points added (new LaunchAgents, etc.)

**Update process:**
```
1. Boss identifies change needed
2. Boss → CLC: "Update CONTEXT_ENGINEERING_GLOBAL.md section X"
3. CLC updates + commits
4. CLC logs to MLS: "Updated context spec section X"
5. CLC notifies relevant agents (GG, GC) of changes
```

**Version control:**
- Bump version number on major changes
- Document changes in git commit messages
- Reference in MLS for future lookup

---

## Related Documentation

- **LaunchAgent Registry:** `g/docs/LAUNCHAGENT_REGISTRY.md`
- **MLS Guide:** `manuals/MLS_SYSTEM_GUIDE.md`
- **Phase Reports:** `g/reports/system/PHASE3_COMPLETION_REPORT_20251117.md`
- **Delegation Quick Ref:** `g/DELEGATION_QUICK_REF.md`

---

**Document Status:** ✅ DRAFT - Ready for Boss Review

**Next Steps:**
1. Boss reviews this spec
2. Boss approves or requests changes
3. CLC incorporates feedback
4. Document becomes official SOT
5. All agents (GG, GC, Kim, etc.) reference this as authoritative

---

**🎯 Key Takeaway:**

**Codex can think. CLC can write. When CLC is unavailable, LPE writes (but doesn't think).**

**This spec ensures clarity, prevents conflicts, and enables graceful degradation.**
