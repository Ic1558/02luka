# Feature Development Plan: Opal Architect & Senior Nodes (Step 1)

**Feature:** Architect Node + Senior Reviewer Node for Opal  
**Status:** 📋 **SPEC - Ready for Implementation**  
**Created:** 2025-12-05  
**Author:** CLS  
**Priority:** **HIGHEST (B → A → C Priority Order)**

---

## 🎯 **EXECUTIVE SUMMARY**

### **Problem Statement**

Current Opal flow generates Work Orders directly without:
- ❌ **Planning phase** - No breakdown of complex tasks
- ❌ **Review phase** - No validation before execution
- ❌ **Lane selection** - No intelligent routing (free LAC / paid API / Hybrid GUI)
- ❌ **Difficulty assessment** - No risk evaluation
- ❌ **Reality check** - No validation against 02luka constraints

**Result:** Complex tasks fail, wrong lanes selected, wasted resources.

---

### **Solution Overview**

Add **2 AI nodes** to Opal flow before Work Order generation:

1. **Architect Node (GG/GC role)**
   - Analyzes objective
   - Breaks down into actionable steps
   - Selects optimal lane (free LAC / paid API / Hybrid GUI)
   - Assesses difficulty and risk
   - Creates executable plan

2. **Senior Reviewer Node (GC role)**
   - Reviews architect's plan
   - Identifies failure points
   - Adjusts plan for 02luka reality
   - Validates lane selection
   - Reduces errors before execution

**Flow:**
```
User Input → Architect Node → Senior Reviewer Node → Generate WO → Send to Gateway
```

---

## 📋 **CURRENT STATE ANALYSIS**

### **Existing Opal Flow**

**Current Nodes:**
1. User Input (captures objective, mode, files)
2. System Data Generator (UUID, timestamp)
3. Generate JSON Work Order (AI prompt)
4. Send to 02luka Gateway (HTTP POST)

**Current WO Generator Prompt:**
- Located in: `apps/opal_gateway/OPAL_CONFIG.md`
- Generates JSON with: `wo_id`, `app_mode`, `objective`, `priority`, `lane`, etc.
- **Limitation:** No planning or review before generation

**Gateway Integration:**
- ✅ `POST /api/wo` endpoint operational
- ✅ Saves to `bridge/inbox/LIAM/{wo_id}.json`
- ✅ Atomic writes, security validated

---

### **Gap Analysis**

**Missing Components:**
1. ❌ **Planning Layer** - No task breakdown before WO generation
2. ❌ **Review Layer** - No validation of plan feasibility
3. ❌ **Lane Intelligence** - No smart routing logic
4. ❌ **Difficulty Assessment** - No risk evaluation
5. ❌ **02luka Reality Check** - No validation against system constraints

**Impact:**
- Complex tasks fail at execution
- Wrong lanes selected (e.g., paid API for simple tasks)
- Wasted resources on impossible tasks
- No learning from failures

---

## 🎯 **FEATURE OBJECTIVES**

### **Primary Goals**

1. **Enable Planning Before Execution**
   - Break complex objectives into steps
   - Identify dependencies
   - Estimate effort and difficulty

2. **Enable Review Before Execution**
   - Validate plan feasibility
   - Check against 02luka constraints
   - Identify failure points early

3. **Enable Smart Lane Selection**
   - Choose optimal execution path
   - Balance cost vs. capability
   - Match task to appropriate agent

4. **Enable Risk Assessment**
   - Evaluate difficulty
   - Identify blockers
   - Suggest mitigations

### **Success Criteria**

✅ **Architect Node:**
- Produces structured plan with steps
- Selects appropriate lane
- Assesses difficulty accurately
- Identifies dependencies

✅ **Senior Reviewer Node:**
- Catches 80%+ of failure points
- Adjusts plans to be executable
- Validates lane selection
- Reduces execution errors by 50%+

✅ **Integration:**
- Seamlessly fits into existing Opal flow
- Outputs compatible with current WO generator
- No breaking changes to gateway

---

## 🏗️ **ARCHITECTURE DESIGN**

### **Node Flow Diagram**

```
┌─────────────┐
│ User Input  │
│ (Objective) │
└─────┬───────┘
      │
      ▼
┌─────────────────────┐
│ Architect Node      │ ← NEW
│ (GG/GC Role)        │
│                     │
│ • Analyze objective │
│ • Break into steps  │
│ • Select lane       │
│ • Assess difficulty │
│ • Create plan       │
└─────┬───────────────┘
      │
      │ Plan JSON
      │
      ▼
┌─────────────────────┐
│ Senior Reviewer Node│ ← NEW
│ (GC Role)           │
│                     │
│ • Review plan       │
│ • Find failures     │
│ • Adjust for 02luka │
│ • Validate lane     │
│ • Finalize plan     │
└─────┬───────────────┘
      │
      │ Reviewed Plan
      │
      ▼
┌─────────────────────┐
│ Generate JSON WO    │
│ (Existing)          │
│                     │
│ Uses reviewed plan │
│ + original inputs   │
└─────┬───────────────┘
      │
      │ WO JSON
      │
      ▼
┌─────────────────────┐
│ Send to Gateway     │
│ (Existing)          │
└─────────────────────┘
```

---

### **Data Flow**

**Input to Architect Node:**
```json
{
  "objective": "User's objective text",
  "app_mode": "expense|trade|GuiAuto|DevTask",
  "priority": "high|medium|low",
  "files": ["file1.jpg", "file2.pdf"],
  "context": "Additional context from user"
}
```

**Output from Architect Node:**
```json
{
  "plan": {
    "steps": [
      {
        "step_id": 1,
        "description": "Step description",
        "estimated_time": "5 minutes",
        "dependencies": [],
        "agent": "LAC|Gemini|Hybrid"
      }
    ],
    "total_steps": 3,
    "estimated_total_time": "15 minutes"
  },
  "lane_selection": {
    "primary_lane": "dev_oss|trader|ops",
    "reasoning": "Why this lane was selected",
    "alternatives": ["lane1", "lane2"],
    "cost_estimate": "free|low|medium|high"
  },
  "difficulty_assessment": {
    "level": "low|medium|high|critical",
    "risk_factors": ["factor1", "factor2"],
    "blockers": ["blocker1"],
    "mitigations": ["mitigation1"]
  },
  "execution_strategy": {
    "mode": "gui_automation|atg_pipeline|trade_analysis|code_generation",
    "requires_hybrid": true|false,
    "target_app": "Excel|TradingView|Browser|null"
  }
}
```

**Input to Senior Reviewer Node:**
```json
{
  "original_objective": "...",
  "architect_plan": { /* Architect output */ },
  "02luka_context": {
    "available_agents": ["LAC", "Gemini", "Hybrid"],
    "current_system_state": "...",
    "constraints": ["constraint1", "constraint2"]
  }
}
```

**Output from Senior Reviewer Node:**
```json
{
  "review_status": "approved|needs_revision|rejected",
  "reviewed_plan": {
    /* Adjusted plan based on review */
  },
  "issues_found": [
    {
      "severity": "critical|warning|info",
      "description": "Issue description",
      "suggestion": "How to fix"
    }
  ],
  "adjustments_made": [
    {
      "field": "lane_selection",
      "original": "...",
      "adjusted": "...",
      "reason": "Why changed"
    }
  ],
  "final_recommendation": {
    "lane": "final_lane",
    "strategy": "final_strategy",
    "confidence": "high|medium|low"
  }
}
```

**Input to Generate JSON WO (Enhanced):**
```json
{
  "original_input": { /* User input */ },
  "architect_plan": { /* Architect output */ },
  "senior_review": { /* Senior reviewer output */ },
  "final_plan": { /* Merged/approved plan */ }
}
```

---

## 📝 **COMPONENT SPECIFICATIONS**

### **Component 1: Architect Node**

**Node Type:** AI Prompt / Text Generation  
**Node Name:** `Architect - Plan & Route`  
**Position:** After "User Input", before "Senior Reviewer"

**Responsibilities:**
1. **Analyze Objective**
   - Parse user intent
   - Identify task type (expense, trade, automation, dev)
   - Extract key requirements

2. **Break Down Tasks**
   - Split complex objectives into steps
   - Identify dependencies between steps
   - Estimate effort per step

3. **Select Lane**
   - Evaluate: free LAC vs. paid API vs. Hybrid GUI
   - Consider: cost, capability, speed
   - Choose optimal path

4. **Assess Difficulty**
   - Evaluate complexity level
   - Identify risk factors
   - Find potential blockers

5. **Create Execution Strategy**
   - Determine execution mode
   - Select target apps/systems
   - Decide if hybrid agent needed

**Prompt Structure:**
- System role: "You are the 02luka Architect (GG/GC role)"
- Input: User objective, app_mode, priority, files
- Output: Structured plan JSON
- Constraints: 02luka system capabilities, lane availability

**Integration:**
- Input: Connects to "User Input" node
- Output: Connects to "Senior Reviewer" node
- Variable: `{{ArchitectPlan}}`

---

### **Component 2: Senior Reviewer Node**

**Node Type:** AI Prompt / Text Generation  
**Node Name:** `Senior Reviewer - Validate & Adjust`  
**Position:** After "Architect", before "Generate JSON WO"

**Responsibilities:**
1. **Review Architect Plan**
   - Validate plan structure
   - Check step feasibility
   - Verify lane selection

2. **Find Failure Points**
   - Identify impossible steps
   - Find missing dependencies
   - Detect unrealistic estimates

3. **Adjust for 02luka Reality**
   - Match plan to actual system capabilities
   - Correct lane selection if wrong
   - Add missing steps if needed

4. **Validate Against Constraints**
   - Check 02luka governance rules
   - Verify agent availability
   - Ensure resource limits

5. **Finalize Plan**
   - Merge adjustments
   - Provide final recommendation
   - Set confidence level

**Prompt Structure:**
- System role: "You are the 02luka Senior Reviewer (GC role)"
- Input: Architect plan + 02luka context
- Output: Reviewed/adjusted plan JSON
- Knowledge: 02luka system constraints, agent capabilities, governance rules

**Integration:**
- Input: Connects to "Architect" node
- Output: Connects to "Generate JSON WO" node
- Variable: `{{ReviewedPlan}}`

---

### **Component 3: Enhanced WO Generator**

**Node Type:** AI Prompt / Text Generation (Modified)  
**Node Name:** `Generate JSON Work Order` (Existing, Enhanced)

**Changes:**
- Accept `{{ReviewedPlan}}` as input
- Use reviewed plan to populate WO fields
- Merge original user input with reviewed plan
- Generate WO JSON with plan embedded

**Enhanced Output:**
```json
{
  "wo_id": "...",
  "app_mode": "...",
  "objective": "...",
  "priority": "...",
  "lane": "...", // From reviewed plan
  "execution": {
    "mode": "...", // From reviewed plan
    "strategy": "...", // From reviewed plan
    "steps": [...] // From reviewed plan
  },
  "plan": {
    "architect_plan": {...},
    "senior_review": {...},
    "final_plan": {...}
  },
  // ... rest of existing fields
}
```

---

## 🔧 **IMPLEMENTATION TASKS**

### **Phase 1: Architect Node (Priority 1)**

**Task 1.1: Create Architect Node Prompt**
- **File:** `apps/opal_gateway/OPAL_ARCHITECT_NODE_PROMPT.md`
- **Content:**
  - System role definition
  - Input/output schema
  - Lane selection logic
  - Difficulty assessment criteria
  - Example outputs
- **Time:** 2-3 hours
- **Dependencies:** None

**Task 1.2: Test Architect Node in Opal**
- Add node to Opal flow
- Test with various objectives
- Verify output structure
- Validate lane selection
- **Time:** 1-2 hours
- **Dependencies:** Task 1.1

---

### **Phase 2: Senior Reviewer Node (Priority 1)**

**Task 2.1: Create Senior Reviewer Node Prompt**
- **File:** `apps/opal_gateway/OPAL_SENIOR_REVIEWER_NODE_PROMPT.md`
- **Content:**
  - System role definition
  - Review criteria
  - 02luka constraints knowledge
  - Adjustment logic
  - Example outputs
- **Time:** 2-3 hours
- **Dependencies:** Task 1.1 (needs architect output format)

**Task 2.2: Test Senior Reviewer Node in Opal**
- Add node to Opal flow
- Test with architect outputs
- Verify review catches issues
- Validate adjustments
- **Time:** 1-2 hours
- **Dependencies:** Task 2.1, Task 1.2

---

### **Phase 3: Integration (Priority 1)**

**Task 3.1: Enhance WO Generator**
- **File:** `apps/opal_gateway/OPAL_CONFIG.md` (update existing prompt)
- **Changes:**
  - Accept `{{ReviewedPlan}}` input
  - Merge plan into WO JSON
  - Preserve existing fields
- **Time:** 1-2 hours
- **Dependencies:** Task 2.1

**Task 3.2: Wire Nodes Together**
- Connect: User Input → Architect → Senior → WO Generator → Gateway
- Test end-to-end flow
- Verify data passes correctly
- **Time:** 1 hour
- **Dependencies:** Task 3.1, Task 1.2, Task 2.2

---

### **Phase 4: Testing & Validation (Priority 2)**

**Task 4.1: Create Test Cases**
- **File:** `apps/opal_gateway/test_architect_senior_nodes.md`
- **Test Scenarios:**
  - Simple task (expense entry)
  - Complex task (multi-step automation)
  - Trade analysis
  - Dev task
  - Invalid/unrealistic task
- **Time:** 1-2 hours
- **Dependencies:** Task 3.2

**Task 4.2: Run Integration Tests**
- Execute test cases
- Verify plan quality
- Check lane selection accuracy
- Validate error reduction
- **Time:** 2-3 hours
- **Dependencies:** Task 4.1

---

## 📊 **TESTING STRATEGY**

### **Unit Tests (Node-Level)**

**Architect Node Tests:**
- ✅ Simple objective → 1-step plan
- ✅ Complex objective → Multi-step plan with dependencies
- ✅ Trade task → Correct lane selection (trader)
- ✅ Expense task → Correct lane selection (dev_oss)
- ✅ Automation task → Hybrid agent selection
- ✅ Invalid task → Error handling

**Senior Reviewer Node Tests:**
- ✅ Valid plan → Approval
- ✅ Invalid lane → Correction
- ✅ Missing steps → Addition
- ✅ Unrealistic estimate → Adjustment
- ✅ Impossible task → Rejection with reason

---

### **Integration Tests (Flow-Level)**

**End-to-End Tests:**
1. **Simple Expense Entry**
   - Input: "บันทึกค่าใช้จ่าย 350 บาท"
   - Expected: 1-step plan, lane=dev_oss, approved
   - Verify: WO generated correctly

2. **Complex Trade Analysis**
   - Input: "วิเคราะห์กราฟ SET50 H1, หาจุดเข้า-ออก, ส่ง Telegram"
   - Expected: Multi-step plan, lane=trader, hybrid agent
   - Verify: Plan includes all steps

3. **GUI Automation Task**
   - Input: "เปิด Excel, คัดลอกข้อมูลจาก Sheet1 ไป Sheet2"
   - Expected: Plan with GUI steps, lane=dev_oss, hybrid agent
   - Verify: Execution mode set correctly

4. **Invalid/Impossible Task**
   - Input: "สร้าง AI ที่คิดได้เหมือนมนุษย์"
   - Expected: Rejection or significant adjustment
   - Verify: Senior reviewer catches issue

---

### **Success Metrics**

**Quantitative:**
- ✅ Plan accuracy: 80%+ of plans executable without major changes
- ✅ Lane selection accuracy: 90%+ correct lane chosen
- ✅ Error reduction: 50%+ reduction in execution failures
- ✅ Review effectiveness: 80%+ of failure points caught

**Qualitative:**
- ✅ Plans are clear and actionable
- ✅ Lane selection is logical
- ✅ Reviews catch real issues
- ✅ Adjustments improve plans

---

## 🎯 **LANE SELECTION LOGIC**

### **Lane Options**

1. **`dev_oss` (Free LAC)**
   - Simple tasks
   - File operations
   - Code generation
   - Low complexity

2. **`trader` (Trade Analysis)**
   - Chart analysis
   - Trading signals
   - Market data
   - Trade execution

3. **`ops` (Operations)**
   - System monitoring
   - Automation
   - Maintenance
   - Infrastructure

### **Selection Criteria**

**Choose `dev_oss` when:**
- Task is simple (1-3 steps)
- No GUI automation needed
- File/code operations
- Low cost priority

**Choose `trader` when:**
- Task involves trading/charts
- Market analysis needed
- Trading signals required

**Choose `ops` when:**
- System operations
- Monitoring/alerting
- Infrastructure tasks

**Choose Hybrid Agent when:**
- GUI automation needed
- Multiple apps involved
- Complex interactions

**Choose Paid API (Gemini) when:**
- Heavy computation needed
- Bulk operations
- Complex analysis
- Free LAC insufficient

---

## 🔍 **DIFFICULTY ASSESSMENT CRITERIA**

### **Difficulty Levels**

**Low:**
- Single step
- No dependencies
- Standard operations
- Clear requirements

**Medium:**
- Multiple steps
- Some dependencies
- Standard tools
- Moderate complexity

**High:**
- Many steps
- Complex dependencies
- Custom solutions
- High complexity

**Critical:**
- Very complex
- Many dependencies
- High risk
- Requires careful planning

### **Risk Factors**

- Missing information
- Ambiguous requirements
- External dependencies
- System constraints
- Resource limitations
- Time pressure

### **Blockers**

- Impossible requirements
- Missing tools/access
- System unavailable
- Insufficient permissions
- Data not available

---

## 📚 **KNOWLEDGE BASE FOR NODES**

### **Architect Node Knowledge**

**02luka System Capabilities:**
- LAC (Local Auto-Coder) - Free, file/code operations
- Gemini API - Paid, heavy computation
- Hybrid Agent - GUI automation
- Trade Agent - Trading operations
- WO Pipeline - Work order processing

**Lane Characteristics:**
- `dev_oss`: Fast, free, simple tasks
- `trader`: Specialized, trading focus
- `ops`: System operations, monitoring

**Execution Modes:**
- `gui_automation`: GUI interactions
- `atg_pipeline`: Antigravity core
- `trade_analysis`: Trading analysis
- `code_generation`: Code writing

---

### **Senior Reviewer Node Knowledge**

**02luka Constraints:**
- Governance rules (from `GG_ORCHESTRATOR_CONTRACT.md`)
- Locked zones (from `CONTEXT_ENGINEERING_PROTOCOL_v4.md`)
- Agent capabilities (from system docs)
- Resource limits (API quotas, etc.)

**Common Failure Patterns:**
- Wrong lane selection
- Missing steps
- Unrealistic estimates
- Impossible requirements
- Missing dependencies

**Adjustment Strategies:**
- Correct lane if wrong
- Add missing steps
- Adjust estimates
- Break down complex steps
- Suggest alternatives

---

## 🚀 **DEPLOYMENT PLAN**

### **Step 1: Create Prompts (Day 1)**

1. Create `OPAL_ARCHITECT_NODE_PROMPT.md`
2. Create `OPAL_SENIOR_REVIEWER_NODE_PROMPT.md`
3. Review with Boss
4. Refine based on feedback

### **Step 2: Add Nodes to Opal (Day 1-2)**

1. Add Architect node to flow
2. Configure prompt
3. Test with sample objectives
4. Add Senior Reviewer node
5. Configure prompt
6. Test review functionality

### **Step 3: Enhance WO Generator (Day 2)**

1. Update WO generator prompt
2. Add plan merging logic
3. Test with reviewed plans
4. Verify WO JSON structure

### **Step 4: Integration Testing (Day 2-3)**

1. Wire all nodes together
2. Run test cases
3. Verify end-to-end flow
4. Measure success metrics

### **Step 5: Production Deployment (Day 3)**

1. Final review
2. Deploy to production Opal
3. Monitor initial usage
4. Collect feedback
5. Iterate improvements

---

## ⚠️ **RISKS & MITIGATIONS**

### **Risk 1: Prompts Too Complex**

**Risk:** Nodes produce inconsistent output  
**Mitigation:**
- Start with simple prompts
- Add complexity gradually
- Test extensively
- Provide clear examples

### **Risk 2: Lane Selection Wrong**

**Risk:** Architect selects wrong lane  
**Mitigation:**
- Clear selection criteria
- Senior reviewer validates
- Learn from failures
- Update criteria

### **Risk 3: Review Misses Issues**

**Risk:** Senior reviewer doesn't catch problems  
**Mitigation:**
- Comprehensive review criteria
- Learn from execution failures
- Update review logic
- Add more checks

### **Risk 4: Breaking Existing Flow**

**Risk:** Changes break current Opal integration  
**Mitigation:**
- Maintain backward compatibility
- Test existing flows
- Gradual rollout
- Rollback plan

---

## 📈 **SUCCESS METRICS & MONITORING**

### **Key Metrics**

1. **Plan Quality:**
   - Steps are clear and actionable
   - Dependencies identified
   - Estimates reasonable

2. **Lane Selection:**
   - Correct lane chosen
   - Cost-effective selection
   - Appropriate for task

3. **Error Reduction:**
   - Fewer execution failures
   - Fewer wrong lanes
   - Better task completion

4. **Review Effectiveness:**
   - Issues caught before execution
   - Plans improved by review
   - Adjustments are helpful

### **Monitoring**

- Track plan success rate
- Monitor lane selection accuracy
- Measure error reduction
- Collect user feedback
- Iterate based on data

---

## ✅ **ACCEPTANCE CRITERIA**

**Feature is complete when:**

1. ✅ Architect node produces structured plans
2. ✅ Senior reviewer validates and adjusts plans
3. ✅ Lane selection is accurate (90%+)
4. ✅ Plans are executable (80%+ without major changes)
5. ✅ Error reduction achieved (50%+)
6. ✅ Integration works end-to-end
7. ✅ No breaking changes to existing flow
8. ✅ Documentation complete
9. ✅ Test cases pass
10. ✅ Production deployment successful

---

## 📅 **TIMELINE**

**Total Estimated Time:** 10-15 hours

**Day 1 (4-6 hours):**
- Task 1.1: Create Architect prompt (2-3h)
- Task 1.2: Test Architect node (1-2h)
- Task 2.1: Create Senior Reviewer prompt (2-3h)

**Day 2 (4-6 hours):**
- Task 2.2: Test Senior Reviewer node (1-2h)
- Task 3.1: Enhance WO generator (1-2h)
- Task 3.2: Wire nodes together (1h)
- Task 4.1: Create test cases (1-2h)

**Day 3 (2-3 hours):**
- Task 4.2: Run integration tests (2-3h)
- Final review and deployment

---

## 🎯 **NEXT STEPS (After Step 1)**

**Step 2: LAC Team v1.0 (Future)**
- 4-layer team architecture
- Blueprint and prompts
- Communication patterns

**Step 3: Personal Assistant Dashboard (Future)**
- Inbox/Outbox/Drafts
- Custom GPT UI
- Notification view
- WO timeline

---

**End of Feature Plan**
