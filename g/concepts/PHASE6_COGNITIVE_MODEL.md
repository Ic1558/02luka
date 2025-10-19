# 🧠 Phase 6 Cognitive Workflow Model

**Date:** 2025-10-20
**Authors:** GG & CLC
**Status:** Active Blueprint
**Scope:** AI Reasoning & Learning Framework for 02LUKA

---

## 1. Purpose

Enable AI agents (GG, Mary, Paula, CLC, Codex, Cursor) to:
1. **Analyze** problems deeply before acting
2. **Propose** multiple solutions with trade-offs
3. **Recommend** the best option with reasoning
4. **Refine** through user feedback loops
5. **Execute** and record learnings

**Core Principle:** *"Think → Propose → Listen → Refine → Act → Learn"*

---

## 2. The Cognitive Loop

```
┌─────────────────────────────────────────────────────────────┐
│                    USER REQUEST                             │
│                "Implement feature X"                         │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
          ┌──────────────────────┐
          │  1. ANALYZE CONTEXT  │
          │  - Recall memories   │
          │  - Check telemetry   │
          │  - Understand goals  │
          └──────────┬───────────┘
                     │
                     ▼
          ┌──────────────────────┐
          │  2. GENERATE OPTIONS │
          │  - Solution A        │
          │  - Solution B        │
          │  - Solution C        │
          └──────────┬───────────┘
                     │
                     ▼
          ┌──────────────────────┐
          │  3. RECOMMEND        │
          │  - Preferred: Option │
          │  - Reasoning: Why    │
          │  - Trade-offs: ...   │
          └──────────┬───────────┘
                     │
                     ▼
          ┌──────────────────────┐
          │  4. USER FEEDBACK    │◄──┐
          │  - Select option     │   │
          │  - Request changes   │   │
          │  - Ask questions     │   │
          └──────────┬───────────┘   │
                     │               │
                     ▼               │
          ┌──────────────────────┐   │
          │  5. REFINE PLAN      │───┘ Loop until
          │  - Adjust details    │     user approves
          │  - Answer questions  │
          │  - Iterate design    │
          └──────────┬───────────┘
                     │
                     ▼
          ┌──────────────────────┐
          │  6. EXECUTE          │
          │  - Implement         │
          │  - Test              │
          │  - Validate          │
          └──────────┬───────────┘
                     │
                     ▼
          ┌──────────────────────┐
          │  7. RECORD LEARNINGS │
          │  - remember() success│
          │  - Log telemetry     │
          │  - Update docs       │
          └──────────────────────┘
```

---

## 3. Core Process Steps

### Step 1: Analyze Context

**Inputs:**
- User request text
- Current system state
- Past similar work (via `recall()`)
- Recent telemetry data
- Available resources

**Actions:**
```bash
# Query vector memory for similar past work
node memory/index.cjs --recall "user request keywords"

# Check recent OPS runs
cat g/reports/latest

# Review telemetry trends
node boss-api/telemetry.cjs --summary
```

**Output:**
- Understanding of requirements
- Constraints identified
- Relevant past experiences retrieved
- Success/failure patterns recognized

---

### Step 2: Generate Options

**Objective:** Propose 3 distinct approaches with different trade-offs

**Format:**
```markdown
## Option A: [Name]
**Description:** Brief overview
**Pros:**
- Advantage 1
- Advantage 2
**Cons:**
- Limitation 1
- Limitation 2
**Effort:** [Low/Medium/High]
**Risk:** [Low/Medium/High]

## Option B: [Name]
...

## Option C: [Name]
...
```

**Guidelines:**
- Options should be **meaningfully different**, not minor variations
- Include **one conservative** (low-risk, proven)
- Include **one innovative** (higher-risk, better outcome)
- Include **one balanced** (moderate risk/reward)

---

### Step 3: Recommend

**Objective:** Suggest the preferred option with clear reasoning

**Format:**
```markdown
## 💡 Recommendation: Option B

**Why:**
1. Balances risk and reward effectively
2. Leverages existing infrastructure (memory/telemetry)
3. Past similar work showed 85% success rate
4. Can be implemented incrementally

**Trade-offs Accepted:**
- Slightly longer implementation time
- Requires new dependency X (but well-maintained)

**Mitigation:**
- Phase implementation to reduce risk
- Use memory system to track patterns
- Monitor with telemetry
```

**Key Components:**
- **Clear Choice:** Which option is best
- **Reasoning:** Why this option (data-driven when possible)
- **Trade-offs:** What we're accepting
- **Risk Mitigation:** How to handle downsides

---

### Step 4: User Feedback

**Interaction Patterns:**

**Pattern A: Direct Acceptance**
```
User: "Go with Option B"
→ Proceed to Step 5 (Refine Plan)
```

**Pattern B: Alternative Selection**
```
User: "I prefer Option C"
→ Adjust recommendation, proceed to Step 5
```

**Pattern C: Hybrid Request**
```
User: "Can we combine B and C?"
→ Generate hybrid solution, present refinement
```

**Pattern D: Clarification**
```
User: "What about [concern X]?"
→ Answer question, may adjust options
```

**Pattern E: New Constraint**
```
User: "We can't use [technology Y]"
→ Regenerate options with new constraint
```

---

### Step 5: Refine Plan

**Objective:** Iterate design until user says "OK"

**Refinement Loop:**
```
WHILE user not satisfied:
  1. Present current plan
  2. Highlight recent changes
  3. Ask: "Does this address your concerns?"
  4. Collect feedback
  5. Adjust plan
  6. Repeat
END WHILE
```

**Plan Components:**
- **Steps:** Ordered list of tasks
- **Dependencies:** What depends on what
- **Risks:** Known issues and mitigations
- **Success Criteria:** How to know it worked
- **Rollback Plan:** How to undo if needed

**Example:**
```markdown
## Implementation Plan

### Phase 1: Foundation (Day 1)
1. Create memory module skeleton
2. Implement tokenization
3. Test with sample data

**Risk:** API design may need iteration
**Mitigation:** Start with minimal API, expand later

### Phase 2: Integration (Day 2)
...

**Success Criteria:**
- [ ] Memory stores and retrieves correctly
- [ ] Similarity scores >0.5 on test queries
- [ ] Zero errors in smoke tests

**Rollback:**
If major issues: `git revert` to commit before changes
```

---

### Step 6: Execute

**Objective:** Implement the approved plan

**Execution Guidelines:**

**1. Start Small**
- Implement minimum viable version first
- Test each component independently
- Integrate incrementally

**2. Test Continuously**
```bash
# After each major change
bash run/smoke_api_ui.sh

# Verify specific functionality
node memory/index.cjs --stats  # Check memory working
curl http://127.0.0.1:4000/healthz  # Check API up
```

**3. Document as You Go**
- Update relevant docs (CONTEXT_ENGINEERING.md, etc.)
- Add inline comments for complex logic
- Create integration guides

**4. Handle Errors Gracefully**
- Log errors with context
- Fail fast when appropriate
- Provide clear error messages

**5. Monitor Progress**
```bash
# Record progress in memory
node memory/index.cjs --remember plan "Completed step X: implemented Y"

# Update telemetry
# (automatic on OPS runs)
```

---

### Step 7: Record Learnings

**Objective:** Capture knowledge for future use

**What to Record:**

**1. Successful Patterns**
```bash
node memory/index.cjs --remember solution \
  "Implemented X using approach Y. Result: 95% success rate. Key: Z."
```

**2. Failures and Fixes**
```bash
node memory/index.cjs --remember error \
  "Error: E. Root cause: C. Solution: S. Prevention: P."
```

**3. Insights**
```bash
node memory/index.cjs --remember insight \
  "Discovered that pattern A works better than B when condition C holds."
```

**4. Configuration Patterns**
```bash
node memory/index.cjs --remember config \
  "Setup X with settings Y for optimal performance in scenario Z."
```

**Recording Checklist:**
- [ ] What was done (specific, actionable)
- [ ] Why it was done (reasoning, trade-offs)
- [ ] How it turned out (results, metrics)
- [ ] What was learned (insights, patterns)
- [ ] What to avoid (pitfalls, anti-patterns)

---

## 4. Integration with Existing Systems

### Memory System Integration

**Before Planning:**
```javascript
// In agents/lukacode/plan.cjs
const relevantMemories = memoryModule.recall({
  query: userPrompt,
  topK: 3
});

// Include in plan metadata
plan.meta.relevantMemories = relevantMemories.map(m => ({
  kind: m.kind,
  text: m.text.slice(0, 100),
  similarity: m.similarity.toFixed(3)
}));
```

**After Successful Execution:**
```bash
# In run/ops_atomic.sh
if [[ "$overall_final_status" == "pass" ]]; then
  node memory/index.cjs --remember plan \
    "OPS run successful. Phases: ${PHASE_NAMES[*]}..."
fi
```

### Telemetry System Integration

**Record Decision Quality:**
```javascript
// Future enhancement: track which options were chosen
telemetry.record({
  task: 'decision_making',
  optionsGenerated: 3,
  optionChosen: 'B',
  userSatisfaction: 'high',  // from feedback
  implementationSuccess: true  // from execution
});
```

**Analyze Patterns:**
```bash
# Query telemetry for decision patterns
node boss-api/telemetry.cjs --summary --filter decision_making
```

### Discord/Reporting Integration

**Notify on Major Decisions:**
```bash
curl -X POST http://127.0.0.1:4000/api/discord/notify \
  -H "Content-Type: application/json" \
  -d '{
    "content": "Phase 6 decision: Option B selected (vector memory). Implementation starting.",
    "level": "info",
    "channel": "project"
  }'
```

---

## 5. Agent-Specific Applications

### GG (Orchestration)
**Role:** High-level planning and coordination

**Cognitive Process:**
1. Analyze: System-wide impact
2. Options: Different architectural approaches
3. Recommend: Based on long-term strategy
4. Refine: Coordinate with other agents
5. Execute: Delegate to CLC/Mary/Paula
6. Learn: Record architectural decisions

**Example:**
```
User: "We need better error handling"

GG Analysis:
- Checks memory for past error patterns
- Reviews telemetry failure rates
- Considers system-wide impact

GG Options:
A. Centralized error handler
B. Distributed try-catch with logging
C. Hybrid: central + local

GG Recommendation: C
Why: Balances simplicity with flexibility
```

### CLC (Implementation)
**Role:** Code execution and technical implementation

**Cognitive Process:**
1. Analyze: Technical feasibility
2. Options: Different implementation patterns
3. Recommend: Based on code quality
4. Refine: Iterate on user feedback
5. Execute: Write code, run tests
6. Learn: Record solutions and anti-patterns

**Example:**
```
User: "Add authentication"

CLC Analysis:
- Recalls past auth implementations
- Checks available libraries
- Reviews security best practices

CLC Options:
A. JWT with local storage
B. Session-based with Redis
C. OAuth2 with external provider

CLC Recommendation: B
Why: Matches existing Redis infrastructure
```

### Mary/Paula (Specialized)
**Role:** Domain-specific analysis and execution

**Cognitive Process:**
1. Analyze: Domain context (finance/data)
2. Options: Domain-appropriate solutions
3. Recommend: Based on domain expertise
4. Refine: Validate with domain rules
5. Execute: Specialized processing
6. Learn: Record domain patterns

---

## 6. Success Criteria

**Individual Decision Quality:**
- [ ] At least 3 distinct options generated
- [ ] Clear pros/cons for each option
- [ ] Data-driven recommendation (when possible)
- [ ] User feedback incorporated
- [ ] Plan iterated until approval

**System-Wide Learning:**
- [ ] Successful patterns recorded in memory
- [ ] Failure cases documented with solutions
- [ ] Telemetry tracks decision outcomes
- [ ] Future decisions benefit from past learnings

**User Experience:**
- [ ] Clear communication of options
- [ ] Transparent trade-offs
- [ ] Iterative refinement (not one-shot)
- [ ] User feels heard and understood
- [ ] Decisions can be revisited

---

## 7. Example Workflow (End-to-End)

### Scenario: "Add rate limiting to memory API"

**Step 1: Analyze**
```bash
$ node memory/index.cjs --recall "rate limiting"
# Returns: Past implementation in boss-api/server.cjs
# Insight: Already have rate limiting pattern
```

**Step 2: Generate Options**
```markdown
## Option A: Reuse Existing Pattern
- Pros: Proven, already tested, consistent
- Cons: May not fit memory API needs exactly
- Effort: Low

## Option B: Per-User Rate Limiting
- Pros: More granular control, prevent abuse
- Cons: Requires user tracking
- Effort: Medium

## Option C: Sliding Window Algorithm
- Pros: More accurate than fixed window
- Cons: More complex, higher memory usage
- Effort: High
```

**Step 3: Recommend**
```markdown
💡 Recommendation: Option A (Reuse Pattern)

Why:
1. Memory API is internal (low abuse risk)
2. Existing pattern works well (boss-api/server.cjs:65-88)
3. Consistency with rest of system
4. Can upgrade to B/C later if needed

Trade-offs:
- Less granular than Option B
- Less accurate than Option C
- But: Simpler, faster to implement, proven
```

**Step 4: User Feedback**
```
User: "Sounds good, but make the limit higher than default"
→ Refinement needed
```

**Step 5: Refine**
```markdown
## Updated Plan

1. Copy rate limiting from server.cjs
2. Adjust limits:
   - Default: 100 req/min
   - Memory API: 500 req/min (higher - internal use)
3. Add to memory endpoints (recall, remember, stats)

Agreed?
```

**Step 6: Execute**
```javascript
// boss-api/server.cjs
const MEMORY_RATE_LIMIT = 500;

function memoryRateLimit(req, res, next) {
  // ... implementation ...
}

app.get('/api/memory/recall', memoryRateLimit, async (req, res) => {
  // ... existing code ...
});
```

**Step 7: Record**
```bash
$ node memory/index.cjs --remember solution \
  "Added rate limiting to memory API: 500 req/min (higher than default 100 due to internal use). Reused existing pattern from boss-api/server.cjs."

# Memory recorded with ID: solution_xxx
```

---

## 8. Metrics & Evaluation

### Decision Quality Metrics

**Quantitative:**
- Options generated per decision (target: ≥3)
- User iterations before approval (target: ≤3)
- Implementation success rate (target: >90%)
- Memory recall relevance (target: >0.5 similarity)

**Qualitative:**
- User satisfaction (feedback)
- Clarity of communication
- Depth of analysis
- Learning accumulation

### System Learning Metrics

**Memory Growth:**
- Memories added per week
- Vocabulary size growth
- Recall accuracy over time
- Memory utilization rate

**Telemetry Insights:**
- Decision → outcome correlation
- Pattern recognition accuracy
- Failure prevention rate
- Continuous improvement trajectory

---

## 9. Anti-Patterns to Avoid

**❌ One-Shot Decisions**
- Don't: Generate one solution and implement immediately
- Do: Propose options, get feedback, iterate

**❌ Analysis Paralysis**
- Don't: Generate 10 options, overwhelming user
- Do: 3-4 distinct, meaningful options

**❌ Ignoring History**
- Don't: Ignore past similar work
- Do: Query memory first, learn from history

**❌ No Feedback Loop**
- Don't: Implement without user confirmation
- Do: Iterate plan until approved

**❌ Forgetting to Learn**
- Don't: Complete task and move on
- Do: Record what worked/didn't for future

---

## 10. Next Phase: Phase 7 Roadmap

**Phase 7 will add:**
- **Interactive Slash Bot:** `/status`, `/plan`, `/report` commands
- **Shared Cognitive State:** All agents see same decision context
- **Autonomous Reflection:** System reviews own decisions
- **Pattern Mining:** Automatic discovery of success patterns
- **Proactive Suggestions:** "Based on past work, you might want to..."

**Foundation Complete:** Phase 6 provides the memory and reasoning framework for Phase 7's autonomous capabilities.

---

## 11. References

**Related Documentation:**
- `g/reports/OPS_PHASE6_VECTOR_MEMO_SUMMARY.md` - Phase 6 deployment
- `docs/MEMORY_SHARING_GUIDE.md` - Memory integration guide
- `docs/CONTEXT_ENGINEERING.md` - Vector memory system
- `.cursor/memory_context.md` - Cursor workspace guide

**Key Components:**
- `memory/index.cjs` - Memory system core
- `agents/lukacode/plan.cjs` - Planner with memory integration
- `boss-api/telemetry.cjs` - Decision quality tracking
- `run/ops_atomic.sh` - Automated learning hooks

---

**Status:** ✅ Active Cognitive Model
**Maintained By:** GG (Strategy) & CLC (Implementation)
**Last Updated:** 2025-10-20
**Version:** 1.0.0
