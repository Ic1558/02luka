
# Context Engineering Protocol v3.2

**Version:** 3.2.0

**Status:** PROTOCOL (Single Source of Truth)

**Last Updated:** 2025-11-17

**Supersedes:** CONTEXT_ENGINEERING_GLOBAL.md v1.0.0-DRAFT

**Maintainer:** Gemini (as Protocol Maintainer)

---

> **Quick Navigation:** For a TL;DR, see Section 0 and `PROTOCOL_QUICK_REF.md`. For machine-readable rules, see `CONTEXT_ENGINEERING_PROTOCOL_v3.schema.json`.

---

## 0. Quick Reference / TL;DR

**🎯 Key Principle (Invariant):**
> **"Gemini (IDE/API) writes non‑locked zones via patch/work-order. CLC writes privileged zones. Codex thinks. LPE transcribes."**

---

### Who Uses This Protocol?

**Primary Users (Read Full Document):**

- **GG** — Uses 100% of document for every classification/routing
- **GC** — Uses sections 2, 3, 4, 6 for validation
- **CLC** — Uses multiple sections for SIP patches and governance changes

**Secondary Users (Read Specific Sections):**

- **Liam** — Uses sections 2.2, 3, 4 for routing decisions
- **Andy** — Uses allowed zones + Gemini/Andy relationship
- **Gemini IDE** — Uses capability table + safety-belt mode (~20% of file)
- **Gemini API** — Uses Layer 4.5 (API Mode), routing rules, quota management

**Non-Users:**

- **LPE Worker** — Does not read (bash/zsh script, no LLM reasoning)

---

### Agent Capabilities (At-a-Glance)

| Agent | Can Think? | Can Write SOT? | Primary Use |
|-------|------------|----------------|-------------|
| **GG** | ✅ Strategic | ✅ Governance only | Governance decisions |
| **GC** | ✅ Tactical | ✅ Specs, PRPs | Implementation planning |
| **CLC** | ✅ Operational | ✅ Locked zones | Privileged writes |
| **Gemini IDE** | ✅ Operational | ✅ Non-locked zones (patch) | Primary operational writer |
| **Gemini API** | ✅ Operational | ✅ Non-locked zones (work order) | Heavy compute offloader |
| **Codex/Liam/Andy** | ✅ Analysis | ⚠️ Override only | IDE assistance, routing |
| **LPE** | ❌ No | ✅ Fallback only | Emergency writes |
| **Kim** | ✅ Routing | ❌ No | Task orchestration |

---

### Zone Rules (Quick Check)

**✅ Allowed:** `apps/**`, `tools/**`, `tests/**`, `docs/**` (non-governance)  
**❌ Locked:** `/CLC/**`, `/core/governance/**`, `memory_center/**`, `launchd/**`, `bridge/**`

**Rule:** If unsure, check `CONTEXT_ENGINEERING_PROTOCOL_v3.schema.json` → `zones.locked_zones`

---

### Fallback Ladder (When Primary Writer Unavailable)

1. **Primary:** Gemini IDE/API (non-locked zones) or CLC (locked zones)
2. **Fallback:** LPE (with Boss approval, logs to MLS)
3. **Emergency Override:** Codex/Liam/Andy (Boss explicit authorization, tag `EMERGENCY_LIAM_WRITE`)

**Decision:** Urgent? → Use LPE. Not urgent? → Wait for new session.

**Gemini API Fallback:** If Gemini API quota exhausted → fallback to CLC or Gemini IDE

---

### Common Queries (Use JSON Schema)

For programmatic access, use `CONTEXT_ENGINEERING_PROTOCOL_v3.schema.json`:

- **Which agent can write to zone X?** → Query `agents[].write_zones` or `agents[].write_scope`
- **Which zones are locked?** → Query `zones.locked_zones`
- **Fallback chain?** → Query `fallback_ladder.fallback_chain`

---

### Enforcement (Must-Know)

- **Git Hook:** `.git/hooks/pre-commit` (tags Codex/Liam/Andy commits, validates LaunchAgents)
- **Token Monitoring:** CLC warns at 150K, alerts at 180K, fallback at 190K+
- **MLS Logging:** Required for all SOT writes (who, when, what, why, approval)

---

### Quick Links

- **Full Protocol:** See Section 1-12 below
- **Quick Reference:** `PROTOCOL_QUICK_REF.md` (decision trees + matrix only)
- **Machine-Readable:** `CONTEXT_ENGINEERING_PROTOCOL_v3.schema.json` (JSON schema)

---

## Related Documents

- **Philosophy & Design Principles:** `02LUKA_PHILOSOPHY.md` (why the system exists and how decisions align)

---

**💡 Tip:** If you're an AI agent (Liam/Andy/Gemini), load the JSON schema first for fast capability lookups, then reference specific sections of the markdown as needed.

---

## 1. Scope & Purpose

This protocol defines the **context engineering architecture** for the 02luka system. It answers the following core questions:

1. **Reasoning:** Which agents can think and make decisions?

2. **Writing:** Which agents can write to the Source of Truth (SOT) repositories?

3. **Fallback:** What is the fallback ladder when primary agents are unavailable?

4. **Flow:** How does context and work flow between agents?

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

- **MUST** delegate implementation to an operational writer (Gemini/CLC)

**Authorization:**

- GG approval required for governance decisions

- Self-approved for tactical specs

**Example Decision:**
> "How do we implement GG decision Y safely?"

---

#### Layer 3: CLC (Privileged Writer)

**Thinking Capability:**

- **CAN** perform operational reasoning

- **CAN** plan code implementations

- **CAN** debug and troubleshoot

**Writing Capability:**

- **CAN** write code, configs, and scripts, primarily within locked zones.

- **CAN** commit to SOT repositories

- **MUST** validate all writes via pre-commit hooks

- **MUST** log all SOT writes to MLS

**Token Budget:**

- **MUST** respect the configured token budget (e.g., 200K tokens/session).

- **MUST** trigger a fallback warning when approaching the critical limit (e.g., >95% of budget).

- **MUST** monitor and report token usage.

**Authorization:**

- Self-approved for writes within its designated (locked) zones.

- Boss approval for architecture changes

**Example Decision:**
> "What's the best way to fix this LaunchAgent path issue?"

---

#### Layer 4: Codex (Consultative Assistant)

**Thinking Capability:**

- **CAN** analyze code

- **CAN** suggest solutions

- **CAN** explore codebase

- **CAN** run read-only CLI commands for diagnostics (`grep`, `ls`, `npm test`, etc.).

**Writing Capability:**

- **Normal Mode:** **MUST NOT** write or commit to SOT. Can only write to ephemeral/draft files.

- **Override Mode:** **MAY** write and commit to SOT when under explicit Boss override (see Section 2.3).

**Example Decision:**
> "I have analyzed the code and suggest the following patch. Please delegate to Gemini or CLC to apply it."

---

#### Layer 4.5: Gemini (Operational Writer & Split-Mode Compute Agent)

**State:** IMPLEMENTED (connector + handler) / PLANNED (WO + quota)

- **Source:** external Gemini API (consumer subscription)
- **Responsibilities:**
  - heavy compute, bulk tests, large refactors
  - relieve token pressure from CLC/Codex
- **Routing:**
  - invoked via Liam decision (`route_to: gemini`)
  - only for non-locked zones (apps/tools), never `/CLC` or governance files
  - **WO Lane:** `bridge/inbox/GEMINI` → `bridge/handlers/gemini_handler.py` (source: Kim/GG/Liam via `engine: gemini`)

**🔹 Three Operational Modes:**

1. **Gemini IDE** (Code Assist) - IDE-integrated writer for normal development
2. **Gemini API** (Heavy Compute) - API-based offloader for bulk operations (NEW - Phase 2)
3. **Gemini CLI** (Direct FS Access) - Command-line writer for patch application and direct file system operations.

---

**Gemini CLI Mode:**

**Thinking Capability:**
- **CAN** read the whole repository using direct file system access.
- **MUST** adhere to all rules defined in `g/docs/GEMINI_CLI_RULES.md`.
- **MUST** load `g/knowledge/mls_lessons_cli.jsonl` when present, display the “MLS Recent Lessons (Read-Only)” block, and treat it as authoritative guidance for LaunchAgents, bridge/handlers, watchers, Redis, and filesystem work—MLS wins whenever generic instincts disagree, and the canonical ledger stays read-only.
- **SHOULD** treat `g/tools/mls_build_cli_feed.py` as the canonical refresh job and coordinate with MLS workers or job schedulers so it runs after ledger updates, keeping the CLI prompt block aligned with the latest lessons.

**Writing Capability:**
- **SHOULD** avoid full-file overwrites unless a diff is explicitly provided and approved.
- **MAY** apply patches directly to the file system.
- **MUST** follow all safety and operational rules in its dedicated protocol.

---

**Gemini IDE Mode:**

**Thinking Capability:**

- **CAN** perform all tasks of CLC and Codex.

- **CAN** perform repository-wide reasoning, analysis, and refactoring.

- **MUST** act as a primary operational writer for **non-locked zones** (apps, tools, tests, normal docs).

- **CAN** perform heavy compute tasks, bulk analysis, and multi-file refactors.

- **CAN** generate specs, PRPs, and implementation plans (เหมือน GC/CLC ใน scope ปกติ).

- **MUST** reason about **output limits** และ **daily quota** ก่อนออกแบบวิธีทำงานในแต่ละ task.

**Writing Capability (Safety-Belt + Split-Mode):**

- **CAN** write and revise operational code, configs, docs, and tests via **patch/diff output**.

- **MUST** operate in **Safety-Belt Mode**:
  - ไม่เขียน “ทั้งไฟล์ยาว ๆ” ทีเดียวถ้ามีโอกาสโดน truncate
  - เน้นออกเป็น **block/phase/section-based patch** แทน

**Safety-Belt Mode (Mandatory Rules):**

1. **Plan-First, Then Patch**
   - ก่อนเปลี่ยนอะไรที่ยาว / ซับซ้อน → Gemini **MUST** ส่ง:
     - รายการ **bullet** หรือ **phase plan**:
       - `PHASE 1/3 – Update Layer Hierarchy section`
       - `PHASE 2/3 – Update Capability Matrix rows`
       - `PHASE 3/3 – Update Fallback Ladder`
   - แต่ละ phase ระบุชัดเจนว่าจะแตะ:
     - section / heading ไหน
     - ไฟล์ไหน
     - ความเสี่ยงประมาณไหน (low/medium/high)

2. **Section-Scoped Patch Output**
   - สำหรับไฟล์ยาว (เช่น protocol, governance docs, long scripts):
     - Gemini **MUST NOT** พยายาม rewrite ทั้งไฟล์ในคำตอบเดียว
     - Gemini **MUST**:
       - จำกัด patch เป็น **“เฉพาะส่วน”** เช่น section 2.2, table capabilities, หรือ block 4.1–4.3
       - ใช้ anchor-ชัดเจน เช่น comment `# --- BEGIN PATCH: Section 4.5 ---` / `# --- END PATCH ---`
   - Output ต้องเป็น:
     - unified diff หรือ replace-block ชัดเจน
     - ไม่ยัดส่วนที่ไม่เปลี่ยนกลับมาซ้ำโดยไม่จำเป็น

3. **PHASE / BLOCK Tagging**
   - เมื่อแบ่งงาน:
     - ทุกคำตอบที่เป็น patch **MUST** เริ่มด้วย header เช่น:
       - `## PHASE 1/3 — Patch Section 2.2 Capability Matrix`
     - ถ้า patch ยังไม่ครบทั้งหมด ให้แจ้ง Boss ตรง ๆ ว่ายังเหลือ:
       - `Remaining: PHASE 2/3 (Fallback Ladder), PHASE 3/3 (Token Monitoring)`

4. **Output Limit Awareness**
   - ถ้า Gemini คาดว่าผลลัพธ์จะใกล้เกิน limit:
     - **MUST** เลือก:
       - ลด scope ให้เหลือแค่หนึ่ง section
       - หรือสรุปเป็น spec แล้วรอให้ Boss/GG ขอ patch รายส่วนต่อ
   - ถ้าเคยโดน truncate ใน task เดียวกันแล้ว:
     - **MUST** หยุดส่ง patch ยาว ๆ ซ้ำ
     - เปลี่ยนกลยุทธ์เป็น:
       - แยกเป็น section เล็กลง
       - หรือ generate เฉพาะส่วนที่สำคัญที่สุดก่อน

5. **Locked Zones Respect**
   - Locked zones: `/CLC/**`, `/core/governance/**`, `/memory_center/**`, `/launchd/**`, `/production_bridges/**`, `/wo_pipeline_core/**`
   - Gemini:
     - **MUST NOT** แก้ locked zones โดยตรง เว้นแต่ Boss ระบุ override ชัดเจน
     - เมื่อถูกสั่งให้แตะ locked zone:
       - **MUST** สร้างเป็น **spec/patch proposal** แทน actual write
       - ให้ CLC หรือ GG/GC ใช้ต่อ

**Quota-Aware Behaviour:**

- Daily Limit: ~1500 requests / user / day, 120 / minute (GeminiPro Code Assist).

- Gemini **SHOULD**:
  - รวมงานที่เกี่ยวข้องไว้ในคำขอเดียว ถ้าไม่เสี่ยงโดน truncate
  - เตือน Boss ถ้า task มีแนวโน้มใช้ request จำนวนมาก (เช่น multi-file refactor ใหญ่)
  - เสนอ “minimal viable patch” ก่อน แล้วเหลือ refactor ส่วนที่ไม่ critical ไว้หลัง

**Authorization:**

- Primary operational writer for:
  - `apps/**`, `tools/**`, `tests/**`, `docs/**` (non-governance)

- Boss, GG, หรือ Liam สามารถ route งานให้ Gemini ทำโดยตรง

- Boss override:
  - ยกเลิกข้อจำกัดบางส่วน (ยกเว้น locked zones) สำหรับ emergency
  - commit จาก Gemini ควรมี tag เช่น `[EMERGENCY_GEMINI_WRITE]` หรือ `[GEMINI_PATCH]`.

**Example Operations:**

> "Refactor auth module across 3 files"
> → Gemini: ส่ง phase plan (ไฟล์ไหน, อะไรบ้าง), แล้วส่ง patch เฉพาะไฟล์แรก (PHASE 1/3), รอ confirm ก่อนไป PHASE 2/3
> "Clean up CONTEXT_ENGINEERING_PROTOCOL_v3.md to 3.2"
> → Gemini: แบ่งงานเป็น Layer Hierarchy, Capability Matrix, Fallback Ladder, แก้ทีละ section เพื่อไม่ให้ output โดน truncate, และทุก patch ใช้ anchor/section-tag ชัดเจน

---

**Gemini API Mode (Heavy Compute Offloader):**

**Purpose:**
- Offload heavy compute tasks from CLC/Codex to preserve token budget
- Handle bulk operations that would consume excessive CLC tokens
- Enable parallel processing of large-scale tasks

**Thinking Capability:**
- **CAN** perform heavy code generation (bulk test generation, scaffolding)
- **CAN** analyze large codebases (multi-file analysis, pattern detection)
- **CAN** generate comprehensive documentation
- **MUST** operate within API quota limits (~1500 requests/day/user)
- **MUST** be quota-aware and token-efficient

**Writing Capability:**
- **CAN** generate code, tests, documentation via work order system
- **MUST** work through `/bridge/inbox/GEMINI/` → `/bridge/outbox/GEMINI/`
- **MUST** respect same zone restrictions as Gemini IDE (no locked zones)
- **CAN** output large results (4K+ tokens) for bulk operations

**Technical Implementation:**
- **SDK:** `google-generativeai` Python package
- **Model:** `gemini-2.5-flash` (fast, cost-effective)
- **Virtual Environment:** `/Users/icmini/02luka/.venv`
- **Health Check:** `g/connectors/gemini_health_check.py`
- **Connector:** `g/connectors/gemini_connector.py`

**Routing Rules (via GG):**
- **WHEN** `task_type=heavy_compute` AND `complexity=high`
- **WHEN** bulk operations (>10 files or >5000 tokens expected output)
- **WHEN** CLC token budget would be significantly impacted (>20K tokens)
- **WHEN** task is parallelizable or benefits from external API compute

**Use Cases:**
1. **Bulk Test Generation:** Generate unit tests for 20+ files
2. **Documentation:** Create comprehensive API documentation from code
3. **Code Analysis:** Analyze security patterns across entire codebase
4. **Script Scaffolding:** Generate boilerplate for new tools/agents
5. **Migration Tasks:** Bulk refactoring across many files

**Authorization:**
- Boss, GG, or Kim can route tasks to Gemini API
- Work orders logged in bridge system for audit trail
- Results reviewed by CLS before integration (for critical tasks)

**Quota Management:**
- Daily limit: ~1500 requests/user (Gemini API subscription)
- Per-minute limit: 120 requests/minute
- Monitored via quota tracking system (Phase 4)
- Fallback to CLC if quota exhausted
- Quota tracker writes `g/apps/dashboard/data/quota_metrics.json` using
  `g/tools/quota_tracker.py` and `g/config/quota_config.yaml`.
- Dashboard reads `/api/quota` to show multi-engine usage (GPT/Gemini/Codex/CLC).
- Routing/fallback decisions **may** consult these metrics but are not yet
  enforced automatically in this phase.

**Safety Constraints:**
- Same locked zone restrictions as other agents
- Output validated before SOT integration
- API key managed via `GEMINI_API_KEY` environment variable
- Safety settings: `BLOCK_NONE` (technical content only)

**Example Operations:**

> "Generate unit tests for all functions in apps/dashboard/ (35 files)"
> → GG routes to Gemini API via work order
> → Gemini API generates test scaffolding for all files
> → CLS reviews output before integration

> "Analyze authentication patterns across g/apps/, g/server/, and bridge/ (80+ files)"
> → Kim creates work order for Gemini API
> → Gemini API performs multi-file analysis
> → Results written to g/reports/security/auth_analysis.md

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

- A smart writer (CLC/Gemini) is unavailable.

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

- **MUST** delegate all writes to an appropriate writer (Gemini, CLC, or LPE)

- **CAN ONLY** coordinate between agents

**Authorization:**

- No direct write permissions

- Delegates to authorized writers only

**Example Decision:**
> "This task should go to CLC, that one to GC"

---

### 2.3 Boss Override Mode (for IDE Agents)

**Purpose:**
Defines the rules for when Boss grants temporary write permissions to agents that are normally read-only or restricted (e.g., Codex, Liam).

### 2.3.1 Trigger

- **WHEN** Boss พูดหรือพิมพ์คำสั่งชัดเจน เช่น:
  - `"Use Cursor to apply this patch now."`
  - `"REVISION-PROTOCOL > Liam do"`
  - or any explicit instruction for an IDE agent to write to SOT.

- **THEN** the agent enters **Override Mode** for the duration of that task.

### 2.3.2 Capabilities under Boss Override

In Override Mode:

- The agent's read-only restrictions are temporarily lifted.

- The agent **MAY** edit files, run CLI commands, and use `git` to commit changes.

- The agent **SHOULD**:
  - Summarize the list of changed files for the Boss.
  - Ensure the commit message contains an appropriate tag, like `EMERGENCY_WRITE`.

### 2.3.3 Scope & Safety

- The override does not bypass system-level prohibitions in `AI:OP-001`.
- CLI agents (Gemini CLI, Codex CLI) **MUST** request explicit `@g/tools/validate_launchagent_paths.zsh` validation from Boss before writing to LaunchAgent files.

- Once the task is complete, the agent **MUST** return to its normal operational mode.

---

## 3. Capability Matrix (Reference Table)

| Agent | Think | Write SOT | Scope | Approval | Token Limit |
|-------|-------|-----------|-------|----------|-------------|
| **GG** | ✅ MUST (strategic) | ✅ CAN (governance only) | Governance docs, policy | Self (Boss oversight) | N/A |
| **GC** | ✅ MUST (tactical) | ✅ CAN (specs, PRPs) | Implementation specs | GG approval | N/A |
| **CLC** | ✅ MUST (operational) | ✅ CAN (code, configs) | Privileged/locked zones | Self-approved | Configurable Budget |
| **Gemini IDE** (Split-Mode Agent) | ✅ MUST (operational) | ✅ CAN (via patch) | Operational code (non-locked) | Self-approved (patch) | Subscription Quota |
| **Gemini API** (Heavy Compute) | ✅ MUST (operational) | ✅ CAN (via work order) | Bulk operations (non-locked) | GG/Kim routing | API Quota (~1500/day) |
| **Gemini CLI** (Codex CLI) | ✅ MUST (operational) | ⚠️ MAY (diff-only) | non-locked zones | Boss override or routing engine | Subscription Quota |
| **Codex** | ✅ CAN (analysis) | ⚠️ MAY (override) | Code suggestions, small fixes | Boss override for writes | N/A |
| **LPE** | ❌ MUST NOT | ✅ CAN (fallback only) | Boss-dictated writes | Boss approval | N/A |
| **Kim** | ✅ CAN (routing) | ❌ MUST NOT | Task coordination | N/A | N/A |

---

## 4. Fallback Ladder Protocol

### 4.1 Decision Tree: When a Smart Writer is Unavailable

```text
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

```text
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

```text
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

```text
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

```text
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

```text
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

```text
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

- Codex/Liam violation attempts (should be zero)

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

- Only authorized writers can commit

- All changes tracked via git + MLS

**Context Layer:**

- Hierarchical level in 02luka agent system

- Each layer has specific capabilities and constraints

- Delegation flows down hierarchy, review flows up

**Authorized Writer:**

- Agent that can commit to SOT repos

- Currently: **Gemini IDE**, **Gemini API**, **CLC**, GG, GC, and LPE (with Boss approval)

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

**Gemini (Two Modes):**

- **Gemini IDE:** IDE-integrated operational writer for normal development tasks

- **Gemini API:** Heavy compute offloader using Google Gemini API for bulk operations, test generation, large-scale analysis

**Fallback Ladder:**

- Sequence of alternative agents when primary unavailable

- **Smart Writer (Gemini IDE/API/CLC) → LPE** (when primary writer is unavailable)

- **Codex → Gemini/CLC/LPE** (Codex cannot write, so it delegates to an available writer)

- **Gemini API quota exhausted → CLC or Gemini IDE**

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

**Version:** 3.2.0

**Status:** PROTOCOL (Single Source of Truth)

**Approved by:** Boss

**Supersedes:** CONTEXT_ENGINEERING_GLOBAL.md v1.0.0-DRAFT

---

**🎯 Key Principle (Invariant):**

> **"Gemini (IDE/API) writes non‑locked zones via patch/work-order. CLC writes privileged zones. Codex thinks. LPE transcribes."**

This protocol ensures:

- ✅ Clear agent authorization

- ✅ Graceful degradation (Smart Writer → LPE)

- ✅ Audit trails (MLS logging)

- ✅ Enforcement mechanisms (git hooks, monitoring)

- ✅ Protocol compliance (validation gates)

**All agents MUST follow this protocol. No exceptions without Boss approval.**
