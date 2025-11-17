# Context Engineering Protocol v3.2
**Version:** 3.2.0
**Status:** PROTOCOL (Single Source of Truth)
**Last Updated:** 2025-11-17
**Supersedes:** CONTEXT_ENGINEERING_GLOBAL.md v1.0.0-DRAFT
**Maintainer:** Gemini (as Protocol Maintainer)

---

## 1. Scope & Purpose

This protocol defines the **context engineering architecture** for the 02luka system. It answers the following core questions:
1.  **Reasoning:** Which agents can think and make decisions?
2.  **Writing:** Which agents can write to the Source of Truth (SOT) repositories?
3.  **Fallback:** What is the fallback ladder when primary agents are unavailable?
4.  **Flow:** How does context and work flow between agents?

The goal is to prevent context chaos, define clear ownership, ensure graceful degradation, and maintain a complete audit trail.

---

## 2. Agent Layer Hierarchy (กฎ Mandatory)

### 2.1 Layer Definition

This is a **conceptual hierarchy of authority and capability**, not a strict linear data flow.

- **GG and GC** sit at the **governance layers**.
- **Gemini** is the **primary operational writer** for most development tasks.
- **CLC** is a **privileged writer**, focused on locked zones.
- **Codex/Liam** are **consultative assistants** and emergency writers.
- **LPE** is a **dumb fallback writer** when CLC is unavailable.
- **Kim** is an **orchestrator/gateway** that can route tasks to GG/GC/CLC.

**Typical flow for code changes:**
- GG/GC decide → Gemini implements → Codex/Liam assists inside the IDE.

**Fallback flow:**
- If a smart writer (Gemini/CLC) is unavailable → Boss may use LPE or activate Emergency Override Mode for an IDE Agent (see 4.5).


### 2.2 Agent Capabilities (Formal Rules)

#### Layer 1: GG (Governance Gate)

**Thinking Capability:**
- **CAN** perform strategic reasoning
- **CAN** make governance decisions
- **CAN** perform risk/value analysis

**Writing Capability:**
- **MUST ONLY** write governance documents
- **MUST ONLY** write policy files
- **MUST NOT** write operational code
- **MUST** delegate code writing to GC or CLC

**Authorization:**
- Self-approval for governance docs (Boss oversight)
- Boss approval for system-wide policy changes

**Example Decision:**
> "Should we adopt feature X based on risk/value analysis?"

---

#### Layer 2: GC (Governance Copilot)

**Thinking Capability:**
- **CAN** perform tactical reasoning
- **CAN** create implementation plans
- **CAN** review code for governance compliance

**Writing Capability:**
- **CAN** write specs, PRPs, review reports
- **CAN** write governance documentation
- **MUST NOT** write operational code without GG approval
- **MUST** delegate implementation to CLC

**Authorization:**
- GG approval required for governance decisions
- Self-approved for tactical specs

**Example Decision:**
> "How do we implement GG decision Y safely?"

---

#### Layer 3: CLC (Claude Code)

**Thinking Capability:**
- **CAN** perform operational reasoning
- **CAN** plan code implementations
- **CAN** debug and troubleshoot

**Writing Capability:**
- **CAN** write code, configs, scripts, reports
- **CAN** commit to SOT repositories
- **MUST** validate all writes via pre-commit hooks
- **MUST** log all SOT writes to MLS

**Token Budget:**
- **MUST NOT** exceed 200K tokens/session
- **MUST** trigger fallback at 190K tokens
- **MUST** monitor token usage via health check
- **MUST** respect the configured token budget (e.g., 200K tokens/session; see current CLC settings).
- **MUST** trigger fallback when approaching the critical limit (e.g., 190K tokens).
- **MUST** monitor token usage via health check.

**Authorization:**
- Self-approved for operational code
- Boss approval for architecture changes

**Example Decision:**
> "What's the best way to fix this LaunchAgent path issue?"

---

#### Layer 4: Codex (Cursor AI / VSCode Extension)

**Thinking Capability:**
- **CAN** analyze code
- **CAN** suggest solutions
- **CAN** explore codebase

**Writing Capability:**
- **SHOULD NOT** write to SOT repositories หรือสร้าง commits ในกรณีปกติ
- **MAY** เขียนลง SOT และสร้าง commits เมื่อ:
  - Boss ให้คำสั่ง override ชัดเจนใน session ปัจจุบัน (ดู 2.3)
  - หรือ task ถูก tag ว่าเป็น `REVISION-PROTOCOL` / `LOCAL-ONLY` และทำงานอยู่ภายใต้ `$SOT`
- **MUST** สรุปรายการไฟล์ที่แก้ไขให้ Boss หลังจบ task
- **SHOULD** แนบ context สำหรับ MLS ถ้ามี (เหตุผล, scope, hash คร่าว ๆ)

**Constraint:**
- ในโหมดปกติ (ไม่มี Boss override):
  - Codex / Liam / Andy **MUST** ถือว่า read-only ต่อ SOT
  - **MUST** delegate medium/large changes ให้ CLC
- ในโหมด Boss override:
  - ข้อจำกัด read-only ถูกยกเลิกเฉพาะ scope ของ task ที่ Boss สั่ง
  - Codex / Liam / Andy **MAY**:
    - ใช้ CLI tools มาตรฐาน (grep, sed, ls, npm, node, python ฯลฯ)
    - แก้ไขไฟล์โค้ด / docs ภายใต้ `$SOT`
    - รัน `git add`, `git commit`, `git status` ภายใน `$SOT/g`
  - การเปลี่ยนแปลงทั้งหมด **SHOULD** ถูกบันทึกใน MLS ใน session ถัดไปของ CLC หรือ LPE

**Enforcement:**
- Git pre-commit hook **MUST NOT** hard-block commits ที่ระบุว่าเป็น Codex/Liam/Andy อีกต่อไป
- ระบบ monitoring / MLS **SHOULD** tag commits ที่มาจาก Codex/Liam/Andy เพื่อการ audit (เช่น `producer: "Codex-override"`)
- Codex / Liam / Andy **SHOULD** แจ้ง Boss เสมอเมื่อกำลังทำงานในโหมด override

**Example Decision:**
> "Boss explicitly asked me to apply this patch in Cursor; I'll edit the files under `$SOT` and summarize what changed."

---

#### Layer 4.5: Gemini (Versatile Compute Agent)

**Thinking Capability:**
- **CAN** perform heavy compute tasks.
- **CAN** execute bulk operations and scripts.
- **CAN** run complex tests and analysis.

**Writing Capability:**
- **SHOULD NOT** write to SOT repositories or create commits in normal operation.
- **MAY** write to SOT under the same Boss override rules as Codex/Liam.
- **MUST** delegate final SOT writes to CLC unless in an emergency override mode.

**Authorization:**
- Activated via explicit routing from Boss, GG, or Liam.
- Not an automatic replacement for other agents.
- Boss override required for direct SOT writes.

**Example Task:**
> "Analyze performance logs from the last 24 hours and generate a summary report."

---

#### Layer 5: LPE (Local Prompt Executor)

**Thinking Capability:**
- **MUST NOT** perform reasoning
- **MUST** execute Boss instructions exactly
- **MUST NOT** make decisions autonomously

**Writing Capability:**
- **CAN** write any file Boss specifies
- **MUST** require Boss approval for all writes
- **MUST** log all writes to MLS
- **CAN ONLY** be used as fallback when CLC unavailable

**Trigger Conditions:**
- CLC session reaches token limit (>190K tokens)
- CLC session reaches its configured token limit (e.g., >190K tokens)
- CLC session unavailable
- Boss requires urgent change

**Authorization:**
- Boss approval **REQUIRED** for every write
- MLS logging **REQUIRED** with Boss message ID
- Next CLC session **MUST** review all LPE writes

**Example Operation:**
> Boss: "Write this code to file X" → LPE: *writes without reasoning*

---

#### Layer 6: Kim (API Gateway / Orchestrator)

**Thinking Capability:**
- **CAN** perform routing decisions
- **CAN** prioritize task queues
- **CAN** analyze task requirements

**Writing Capability:**
- **MUST NOT** write to SOT
- **MUST** delegate all writes to CLC or LPE
- **CAN ONLY** coordinate between agents

**Authorization:**
- No direct write permissions
- Delegates to authorized writers only

**Example Decision:**
> "This task should go to CLC, that one to GC"

---

### 2.3 Boss Override & Cursor/Liam Mode

**Purpose:**
กำหนดกฎพิเศษเมื่อ Boss สั่งตรง ว่า Codex / Liam / Andy สามารถทำงานแบบ "ลงมือเขียนจริง" ได้ แม้ปกติจะเป็น read-only

**2.3.1 Trigger (เงื่อนไขเริ่มใช้ Override)**

Boss ถือสิทธิ์ override เต็มรูปแบบ:

- **WHEN** Boss พูดหรือพิมพ์คำสั่งชัดเจน เช่น:
  - `"Use Cursor to apply this patch now."`
  - `"REVISION-PROTOCOL > I run or use Liam do"`
  - หรือข้อความที่ระบุชัดว่าให้ Liam/Andy แก้ไฟล์ใน SOT
- **THEN** ข้อจำกัด read-only ของ Codex-family tools (Cursor, Liam, Andy)
  **ถูกยกเลิกชั่วคราว** สำหรับ task นั้น ๆ

**2.3.2 Capabilities under Boss Override**

ในช่วงที่ Boss override มีผล:

- Codex / Liam / Andy **MAY**:
  - แก้ไขไฟล์ใด ๆ ภายใน `$SOT` และ subdirectories (ยกเว้น zone อันตรายที่ AI:OP-001 ห้าม)
  - เรียกใช้คำสั่ง dev พื้นฐาน:
    - `grep`, `rg`, `sed`, `ls`, `cat`, `npm`, `node`, `python`, ฯลฯ
  - รัน `git add`, `git commit`, และ `git status` ภายใต้ repo `$SOT/g`
- พวกเขา **SHOULD**:
  - สรุปรายการไฟล์ที่แตะ + เหตุผลให้ Boss ทุกครั้ง
  - ถ้า MLS ใช้งานได้ ให้แนบข้อความว่า:
    - `"producer": "Codex-override"` หรือ `"producer": "Liam-override"`

**2.3.3 Scope & Safety**

- Boss override **ไม่ยกเลิก** ข้อห้ามระดับระบบใน AI:OP-001 (เช่น การลบ data zone ผิดที่)
- Override นี้ออกแบบมาเพื่อ:
  - ลดการพึ่งพา CLC เมื่อ token ใกล้หมด
  - ให้ Cursor/Liam ทำ "local dev work" ได้เต็มที่
- เมื่อ task เสร็จ:
  - Liam / Andy **SHOULD** กลับไปเคารพ capability table ปกติ

---

## 3. Capability Matrix (Reference Table)

| Agent | Think | Write SOT | Scope | Approval | Token Limit |
|-------|-------|-----------|-------|----------|-------------|
| **GG** | ✅ MUST (strategic) | ✅ CAN (governance only) | Governance docs, policy | Self (Boss oversight) | N/A |
| **GC** | ✅ MUST (tactical) | ✅ CAN (specs, PRPs) | Implementation specs | GG approval | N/A |
| **CLC** | ✅ MUST (operational) | ✅ CAN (code, configs) | Operational code | Self-approved | 200K/session |
| **Codex** | ✅ CAN (analysis) | ⚠️ MAY (override/local-only) | Code suggestions + local edits | Boss override for writes | N/A |
| **Codex** | ✅ CAN (analysis) | ⚠️ MAY (override/local-only) | Code suggestions, local edits | Boss override for writes | N/A |
| **Gemini**| ✅ CAN (compute) | ⚠️ MAY (override) | Bulk ops, scripts, analysis | Boss override for writes | Subscription Quota |
| **LPE** | ❌ MUST NOT | ✅ CAN (fallback only) | Boss-dictated writes | Boss approval | N/A |
| **Kim** | ✅ CAN (routing) | ❌ MUST NOT | Task coordination | N/A | N/A |

---

## 4. Fallback Ladder Protocol

### 4.1 Decision Tree: When CLC Is Unavailable

```
┌─────────────────────────────────────┐
│ CLC reaches 200K tokens             │
│ OR CLC session not open             │
└──────────────┬──────────────────────┘
               ↓
     ┌─────────────────────┐
     │ Is this urgent?     │
     └─────┬───────────┬───┘
           │           │
          YES         NO
           │           │
           ↓           ↓
    ┌──────────┐  ┌────────────────┐
    │ Use LPE  │  │ Wait for new   │
    │ Fallback │  │ CLC session    │
    └──────────┘  └────────────────┘
           │
           ↓
    ┌──────────────────────────┐
    │ LPE Fallback Protocol:   │
    │ 1. Boss dictates change  │
    │ 2. LPE writes (no think) │
    │ 3. Log to MLS            │
    │ 4. Next CLC reviews      │
    └──────────────────────────┘
```

### 4.2 Scenario 1: CLC Out of Tokens

**Trigger:**
- CLC session reaches 190K+ tokens

**Decision Rule:**

**IF** urgent change required:
- **THEN** use LPE fallback
- **ELSE** wait for new CLC session

**LPE Fallback Procedure:**
1. Boss **MUST** dictate exact changes to LPE
2. LPE **MUST** execute writes without reasoning
3. LPE **MUST** log to MLS:
   - Timestamp
   - Producer: LPE
   - Action: Write file X
   - Reason: CLC out of tokens
   - Boss approval: [message ID]
4. Next CLC session **MUST** review LPE changes
5. CLC **MUST** validate correctness
6. CLC **MUST** fix if issues found

**MLS Log Format (Required):**
```json
{
  "timestamp": "2025-11-17T06:00:00",
  "producer": "LPE",
  "type": "emergency_write",
  "file": "g/tools/script.zsh",
  "reason": "CLC token limit exceeded",
  "approval": "Boss message 2025-11-17T05:59:00",
  "content_hash": "a1b2c3d4..."
}
```

### 4.3 Scenario 2: CLC Session Unavailable

**Trigger:**
- Boss needs change but no CLC session open
- Urgent operational requirement

**Procedure:**
1. Boss **MAY** use LPE as fallback writer
2. Boss **MUST** approve each write explicitly
3. LPE **MUST** log to MLS (same format as 4.2)
4. Next CLC session **MUST** review all LPE writes

### 4.4 Scenario 3: Codex Suggests Change

**Trigger:**
- Codex provides code suggestion
- Boss wants to apply suggestion

**Decision Rule:**

**IF** CLC session available:
- **THEN** Boss delegates to CLC
- CLC writes + commits
- MLS logs: "Codex suggestion implemented by CLC"

**ELSE IF** CLC unavailable:
- **THEN** Boss uses LPE fallback
- Boss dictates Codex suggestion to LPE
- LPE writes + logs to MLS
- MLS logs: "Codex suggestion via LPE (CLC unavailable)"

**Codex Constraint (Enforced):**
- Codex **MUST NOT** write to SOT directly
- Codex **MUST** inform Boss: "I cannot write to git. Please use CLC or LPE."
- Git hook **MUST** reject any commits with author="Codex"

---

### 4.5 Emergency Codex/Liam Write Mode (CLC Outage)

**Trigger Conditions:**
- CLC session is unavailable or out of tokens
- Boss issues an explicit command such as:
  - "REVISION-PROTOCOL → Liam do"
  - "Use Cursor to apply this patch now"
- Scope is **limited** to:
  - Protocol/documentation updates
  - Small, localized code/script fixes
  - Non-destructive config changes

**Decision Rule:**

- **IF** CLC is unavailable AND Boss explicitly authorizes Codex/Liam:
  - **THEN** Codex/Liam **MAY**:
    - run CLI commands inside the SOT workspace
    - edit protocol/docs files (e.g. `CONTEXT_ENGINEERING_PROTOCOL_v3.md`)
    - apply small, reviewed patches to tools/scripts
  - All such edits **MUST** be:
    - clearly marked as **EMERGENCY_LIAM_WRITE** in commit messages
    - logged to MLS as an emergency write with:
      - `producer: "Liam"` or `"Andy"`
      - `reason: "CLC unavailable / out of tokens"`
      - `approval: "Boss <timestamp or message id>"`

**Limits:**

- Codex/Liam **MUST NOT**:
  - perform large-scale refactors
  - delete SOT directories or core protocols
  - modify AI:OP-001 content without an explicit Boss-written spec
- When CLC becomes available again:
  - CLC **MUST** review all `EMERGENCY_LIAM_WRITE` commits
  - CLC **MUST** validate correctness and update protocols if needed

> **Note:**  
> Running CLI commands for diagnostics (e.g. `grep`, `ls`, `npm test`, `pytest`, `launchctl list`, `curl localhost:...`) is considered **read-only with respect to SOT**, even if it produces temporary files (`logs/`, `.cache/`, `node_modules/`, `dist/`).  
> Such commands are **allowed** for Codex/Liam under normal operation.

---

## 5. Context Flow Patterns

### 5.1 Pattern: Normal Operation (CLC Active)

**Flow:**
```
Boss request
    ↓
CLC receives + validates
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

**Rules:**
- CLC **MUST** use all available tools (Read, Write, Edit, Bash, Git)
- CLC **MUST** validate via pre-commit hooks
- CLC **MUST** log all SOT writes to MLS

### 5.2 Pattern: CLC + Codex Collaboration

**Flow:**
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
    ↓
MLS logs: "Codex suggestion implemented by CLC"
```

**Rules:**
- Codex **MUST** be read-only
- CLC **MUST** execute all writes
- MLS **MUST** log Codex → CLC handoff

### 5.3 Pattern: GG → GC → CLC Cascade

**Flow:**
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

**Rules:**
- Each layer **MUST** add detail
- Each layer **MUST** delegate down hierarchy
- Review **MUST** flow back up hierarchy

### 5.4 Pattern: LPE Emergency Fallback

**Flow:**
```
CLC hits token limit mid-task
    ↓
Boss: "I need this file updated NOW"
    ↓
Boss → LPE: "Write this content to file Y"
    ↓
LPE writes (no thinking)
    ↓
LPE logs to MLS: "Emergency write by LPE, Boss approval [ID]"
    ↓
Next CLC session: Review MLS log
    ↓
CLC validates LPE changes
    ↓
IF issues found: CLC fixes + reports
```

**Rules:**
- All LPE writes **MUST** be logged for CLC review
- Boss approval **REQUIRED** for each write
- CLC **MUST** validate all LPE writes in next session

### 5.5 Pattern: Kim Multi-Agent Orchestration

**Flow:**
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

**Rules:**
- Kim **MUST NOT** write to SOT
- Kim **MUST** delegate to appropriate agents
- Kim **MAY** coordinate parallel execution

---

## 6. Enforcement Mechanisms (Mandatory)

### 6.1 Git Pre-Commit Hook

**Purpose:** Prevent protocol violations before commit

**Location:** `.git/hooks/pre-commit`

**Required Checks:**

```bash
#!/bin/bash
# .git/hooks/pre-commit

# Check 1: Tag Codex/Liam/Andy commits (no hard block; Boss override allowed)
if git log -1 --pretty='%an' | grep -Ei 'codex|liam|andy' >/dev/null 2>&1; then
  echo "⚠️  NOTICE: Codex/Liam/Andy-authored commit detected."
  echo "    → Ensure this commit was done under Boss override or local-only work."
fi

# Check 2: Validate LaunchAgent scripts exist
if ! bash ~/02luka/g/tools/check_launchagent_scripts.sh; then
  echo "❌ PROTOCOL VIOLATION: LaunchAgent validation failed"
  exit 1
fi

# Check 3: Verify MLS logging for SOT writes (if applicable)
# (Optional: check if MLS entry exists for this commit)

exit 0
```

**Installation:**
```bash
chmod +x .git/hooks/pre-commit
```

### 6.2 Token Budget Monitoring

**Purpose:** Prevent CLC token exhaustion without fallback

**Monitoring Points:**

| Tokens Used | Action | Rule |
|-------------|--------|------|
| < 150K | Normal operation | CLC **MAY** continue |
| 150K - 180K | Warning | CLC **SHOULD** warn Boss |
| 180K - 190K | Alert | CLC **MUST** alert Boss |
| 190K+ | Fallback trigger | CLC **MUST** prepare LPE fallback |

**Implementation:**
- CLC **MUST** report token usage in responses
- Health check **MAY** monitor token usage
- Boss **MUST** decide: continue with LPE or new session

### 6.3 MLS Audit Trail

**Purpose:** Track all SOT writes for accountability

**Required Logging:**

Every SOT write **MUST** log:
- **Who:** Agent that wrote (GG/GC/CLC/LPE)
- **When:** Timestamp (ISO 8601)
- **What:** File path + content hash
- **Why:** Reason/context
- **Approval:** Boss approval (if LPE)

**MLS Entry Format:**
```json
{
  "timestamp": "2025-11-17T06:00:00",
  "producer": "CLC",
  "type": "sot_write",
  "file": "g/tools/script.zsh",
  "reason": "Fix LaunchAgent path issue",
  "content_hash": "sha256:a1b2c3d4...",
  "approval": null
}
```

**Query Examples:**
```bash
# Find all LPE writes
node ~/02luka/knowledge/index.cjs --hybrid "LPE emergency write"

# Find CLC token limit incidents
node ~/02luka/knowledge/index.cjs --hybrid "token limit fallback"

# Find Codex suggestions implemented
node ~/02luka/knowledge/index.cjs --hybrid "Codex suggestion implemented"
```

---

## 7. Integration with LaunchAgents

### 7.1 Agent-Triggered Workflows

**Mapping Table:**

| LaunchAgent | Triggers | Context Layer | Action |
|-------------|----------|---------------|--------|
| `mls.cursor.watcher` | Cursor prompt capture | → MLS | Captures Codex interactions for learning |
| `mary.dispatcher` | Work order routing | → Kim → CLC/GC | Routes tasks to appropriate agent |
| `backup.gdrive` | Data sync | → Local script | No context layer (pure automation) |
| `health.dashboard` | Status generation | → Local script | Generates JSON without AI reasoning |
| `gg.nlp-bridge` | Governance routing | → GG/GC | Routes governance decisions |

**Rule:**
- LaunchAgents **MAY** trigger AI agents
- LaunchAgents **MUST NOT** perform reasoning themselves
- LaunchAgents **MUST** be deterministic automation only

### 7.2 Context Layer Selection

**Decision Tree:**

```
LaunchAgent event occurs
    ↓
Does it require governance decision?
    ├─ YES → Route to GG/GC
    └─ NO → Continue
               ↓
Does it require code changes?
    ├─ YES → Route to CLC
    └─ NO → Continue
               ↓
Is it pure automation?
    ├─ YES → Execute local script
    └─ NO → Route to Kim for orchestration
```

---

## 8. Validation & Compliance

### 8.1 Pre-Commit Validation (Required)

**Who:** CLC, LPE (before any SOT write)

**What to validate:**
```bash
# 1. LaunchAgent script existence
bash ~/02luka/g/tools/check_launchagent_scripts.sh

# 2. No hardcoded paths (if applicable)
bash ~/02luka/g/tools/check_hardcoded_paths.sh

# 3. MLS compliance (if applicable)
bash ~/02luka/g/tools/check_mls_compliance.sh
```

**Rule:**
- All checks **MUST** pass before commit
- Failed validation **MUST** block commit
- Boss **MAY** override for emergency

### 8.2 Runtime Validation (Monitoring)

**Who:** Health dashboard, monitoring LaunchAgents

**What to monitor:**
- CLC token usage (warn at 150K, alert at 180K)
- LPE fallback usage (count + frequency)
- Codex violation attempts (should be zero)
- MLS logging compliance (100% for SOT writes)

**Alert Thresholds:**

| Metric | Warning | Critical | Action |
|--------|---------|----------|--------|
| CLC tokens | 150K | 190K | Prepare LPE fallback |
| LPE usage | 5/day | 10/day | Investigate why CLC unavailable |
| Codex violations | 1/week | 1/day | Review git hooks |
| MLS missing logs | 1% | 5% | Audit SOT writes |

### 8.3 Periodic Audit (Weekly)

**Who:** Boss or GG

**What to check:**
- Review MLS logs for all LPE writes
- Verify CLC token usage patterns
- Check for any Codex violation attempts
- Validate enforcement mechanisms still active

**Report:**
- Weekly compliance report to MLS
- List any protocol violations
- Recommend adjustments if needed

---

## 9. Maintenance Protocol

### 9.1 Adding New Agent/Layer

**Procedure:**

1. **Define capabilities:**
   - Can think? (Yes/No)
   - Can write SOT? (Yes/No, where?)
   - Authorization required? (Who approves?)
   - Token limits? (If applicable)

2. **Update this protocol:**
   - Add to Section 2.2 (Agent Capabilities)
   - Add to Section 3 (Capability Matrix)
   - Add to relevant flow patterns (Section 5)

3. **Add enforcement:**
   - Update git pre-commit hook if needed
   - Add monitoring to health dashboard
   - Add MLS logging requirements

4. **Test compliance:**
   - Verify new agent follows rules
   - Validate enforcement mechanisms work
   - Document in MLS

5. **Boss approval:**
   - Required for new agent
   - Version bump this protocol

### 9.2 Modifying Agent Capabilities

**Procedure:**

1. **Document change:**
   - What capability is changing?
   - Why is it changing?
   - What's the impact?

2. **Update protocol:**
   - Modify Section 2.2 (specific agent rules)
   - Update Section 3 (capability matrix)
   - Update enforcement mechanisms

3. **Test changes:**
   - Verify no protocol violations
   - Validate enforcement still works
   - Update MLS with learnings

4. **Boss approval:**
   - Required for capability changes
   - Version bump this protocol

### 9.3 Protocol Version Control

**Versioning:**
- Major version (X.0.0): Breaking changes (agent capabilities changed)
- Minor version (3.X.0): New agents/layers added
- Patch version (3.0.X): Documentation/clarification only

**Change Requirements:**
- Major/Minor changes **REQUIRE** Boss approval
- Patch changes **MAY** be self-approved by protocol maintainer
- All changes **MUST** be documented in MLS

---

## 10. Glossary

**SOT (Single Source of Truth):**
- Git repositories containing authoritative code/docs
- Only authorized writers can commit (GG, GC, CLC, LPE with approval)
- All changes tracked via git + MLS

**Context Layer:**
- Hierarchical level in 02luka agent system
- Each layer has specific capabilities and constraints
- Delegation flows down hierarchy, review flows up

**Authorized Writer:**
- Agent that can commit to SOT repos
- Currently: GG, GC, CLC, LPE (with Boss approval)
- Codex and Kim are NOT authorized writers

**Read-Only Agent:**
- Agent that can analyze but not write to SOT
- Currently: Codex, Kim
- Must delegate writes to authorized agents

**Token Budget:**
- Maximum tokens per CLC session (200K)
- Monitored to prevent mid-task failures
- Fallback triggers at 190K tokens

**MLS (Multi-Loop Learning System):**
- Knowledge base capturing decisions, learnings, patterns
- Searchable via `knowledge/index.cjs`
- Required for all LPE writes and protocol violations

**Fallback Ladder:**
- Sequence of alternative agents when primary unavailable
- CLC → LPE (when CLC out of tokens or unavailable)
- Codex → CLC/LPE (Codex cannot write)

**Enforcement Mechanism:**
- Automated check that prevents protocol violations
- Examples: Git pre-commit hook, token monitor, MLS validation
- Required for maintaining protocol compliance

---

## 11. References

**Related Protocols:**
- `MULTI_AGENT_PR_CONTRACT.md` - PR routing and classification
- `LAUNCHAGENT_REGISTRY.md` - LaunchAgent lifecycle management
- `AI:OP-001` - Operations protocol

**Related Documentation:**
- `CONTEXT_ENGINEERING_GLOBAL.md` (DEPRECATED - replaced by this protocol)
- `g/DELEGATION_QUICK_REF.md` - Quick reference for delegation
- `manuals/MLS_SYSTEM_GUIDE.md` - MLS usage guide

**Tools:**
- `check_launchagent_scripts.sh` - Validate LaunchAgent paths
- `validate_runtime_state.zsh` - Runtime validation
- `knowledge/index.cjs` - MLS search interface

---

## 12. Protocol Status

**Version:** 3.1.0-REV
**Status:** PROTOCOL (Effective immediately)
**Approved by:** Boss
**Supersedes:** CONTEXT_ENGINEERING_GLOBAL.md v1.0.0-DRAFT
**Next Review:** 2025-12-17 (30 days)

---

**🎯 Key Principle (Invariant):**

> **"Codex can think. CLC can write. When CLC unavailable, LPE writes (but doesn't think)."**

This protocol ensures:
- ✅ Clear agent authorization
- ✅ Graceful degradation (CLC → LPE)
- ✅ Audit trails (MLS logging)
- ✅ Enforcement mechanisms (git hooks, monitoring)
- ✅ Protocol compliance (validation gates)

**All agents MUST follow this protocol. No exceptions without Boss approval.**
