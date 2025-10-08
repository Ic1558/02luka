# 02LUKA Delegation System Map

**Report ID:** DELEGATION_SYSTEM_MAP_251007_2200
**Date:** 2025-10-07T22:00:00Z
**Purpose:** Comprehensive mapping of delegation resources and routing logic
**Context:** CLC learning proper delegation strategy vs defaulting to expensive resources

---

## 🎯 Executive Summary

The 02luka system has **multi-tier delegation architecture** with specialized agents for different tasks. This map documents all available resources, their capabilities, costs, and routing decision logic to optimize for:
- **Cost efficiency** (minimize expensive AI tokens)
- **Speed** (use purpose-built tools over general AI)
- **Quality** (route to specialist vs generalist)

**Key Principle:** Don't default to expensive CLC (Claude Sonnet) for tasks that cheaper/specialized resources can handle.

---

## 🏗️ Architecture Overview

```
                         ┌─────────────────┐
                         │  Boss (Human)   │
                         └────────┬────────┘
                                  │
                         ┌────────▼────────┐
                         │  CLC (Claude)   │ ← Most Expensive
                         │   Coordinator   │ ← Delegation Authority
                         └────────┬────────┘
                                  │
               ┌──────────────────┼──────────────────┐
               │                  │                  │
        ┌──────▼──────┐   ┌──────▼──────┐   ┌──────▼──────┐
        │   Codex/    │   │   Local     │   │  LaunchAgent│
        │  Cursor AI  │   │   Agents    │   │  Background │
        └─────────────┘   └─────────────┘   └─────────────┘
        • Cheaper tokens  • Zero cost     • Automated tasks
        • IDE context     • Purpose-built • System health
        • Code gen        • Fast          • Monitoring
```

---

## 🤖 AI Agents (Token Cost Spectrum)

### 1. CLC (Claude Sonnet 4.5) - Primary Coordinator

**Cost:** 💰💰💰 Most Expensive
**Token Rate:** $15/1M input, $75/1M output (2025 pricing)
**Location:** External API (Anthropic)
**Interface:** Claude Code CLI

**Capabilities:**
- Complex reasoning and decision-making
- Multi-step problem solving
- System coordination and delegation
- Quality validation and review
- Strategic planning
- Error diagnosis requiring context

**Best For:**
- Complex decisions requiring judgment
- Coordinating multiple agents
- Validating critical work
- Strategic system changes
- Tasks requiring full system context
- Final quality checks

**Avoid For:**
- Simple code generation (use Codex)
- File search (use librarian)
- Health checks (use automated agents)
- Bulk implementation work
- Repetitive tasks

**Budget Impact:**
- Average session: 50K-200K tokens
- Cost per session: $1.50-$15.00
- Monthly budget: Monitor via usage tracking

---

### 2. Codex / Cursor AI - Implementation Specialist

**Cost:** 💰 Cheaper (exact pricing TBD)
**Location:** Cursor IDE integration
**Interface:** `.codex/` workflow, golden_prompt.md templates

**Capabilities:**
- Code generation (bulk implementation)
- Following detailed specifications
- Template-based creation
- IDE-aware context (open files, git state)
- Fast iteration on code

**Best For:**
- Python/JS/Bash script generation
- Following detailed prompts ("create X with Y pattern")
- Bulk code changes
- Template implementations
- When spec is clear, just needs execution

**Avoid For:**
- Strategic decisions
- System architecture changes
- Tasks requiring cross-system context
- Final validation (CLC should review)

**Integration:**
```bash
# Golden prompt workflow
1. CLC creates detailed prompt in .codex/prompts/
2. Codex generates implementation
3. CLC validates and integrates
```

**Cost Optimization:**
- Use for heavy lifting (code gen)
- CLC does final validation only
- Result: 70-80% token savings

---

### 3. Local Ollama Models - Specialized Tasks

**Cost:** 💵 Zero (local GPU)
**Location:** Local Mac (Ollama)
**Interface:** `model_router.sh`

**Available Models:**
```bash
qwen2.5-coder   → Code generation (default)
deepseek-coder  → Code review/critique
llama3.1        → Optimization/refinement
```

**Router Logic:**
```bash
# Automatic routing based on task type
model_router.sh generate     → qwen2.5-coder
model_router.sh review       → deepseek-coder
model_router.sh optimize     → llama3.1

# With hints
model_router.sh unknown "review critique" → deepseek-coder
```

**Best For:**
- Code generation (offline)
- Code review (fast feedback)
- Optimization suggestions
- When internet/API unavailable
- Privacy-sensitive code

**Limitations:**
- Smaller context window (~32K)
- Less sophisticated reasoning
- No system-wide context
- Requires local GPU/CPU resources

**Cost Optimization:**
- Zero API costs
- Fast local execution
- Good for iteration loops

---

## 🛠️ Local Agent Tools (Zero Cost, Purpose-Built)

### 1. Intelligent Librarian (`librarian_v2.py`)

**Purpose:** File indexing and search
**Location:** `/tools/librarian_v2.py`
**LaunchAgent:** `com.02luka.intelligent_librarian.plist`
**Update Interval:** Every 30 minutes

**Capabilities:**
- Index all files across 02luka system
- Track file locations by zone (a, c, f, g, tools, etc.)
- Identify important files (CLAUDE.md, protocols, contexts)
- Fast lookups via JSON index

**Output:**
```json
{
  "updated_at": "2025-10-07T22:00:00Z",
  "total_files": 8117,
  "by_type": {".md": 243, ".py": 89, ".sh": 156, ...},
  "by_zone": {"a": 1200, "g": 3400, "f": 240, ...},
  "important_files": [
    "CLAUDE.md",
    "a/section/clc/protocols/...",
    "f/ai_context/system_map.json"
  ]
}
```

**Best For:**
- "Where is file X?"
- "How many .py files exist?"
- "List all protocol files"
- File discovery before creating new ones

**CLC Usage:**
```bash
# Instead of: Burn tokens searching/globbing
# Use: Read the index
cat "$SOT/run/file_index.json" | jq '.important_files[] | select(. | contains("protocol"))'
```

**Cost Savings:** Eliminates token-expensive file discovery operations

---

### 2. Boot Guard (`boot_guard.sh`)

**Purpose:** LaunchAgent enforcement and system startup validation
**Location:** `~/Library/02luka/bin/boot_guard.sh`
**LaunchAgent:** `com.02luka.boot_guard.plist`

**Capabilities:**
- Enforce agent registry (load only approved agents)
- Boot out unregistered agents automatically
- System startup validation
- Agent health verification

**How It Works:**
```bash
1. Read agent_registry.json (core + support lists)
2. Check all com.02luka.* agents
3. Bootstrap approved agents
4. Bootout unapproved agents
5. Report changes
```

**Best For:**
- System startup validation
- Agent cleanup after changes
- Preventing unauthorized agents
- Registry enforcement

**CLC Usage:**
When Boss says "clean up agents" → Delegate to boot_guard, don't manually audit

**Cost Savings:** Automated enforcement vs manual CLC review

---

### 3. Health Proxy (`health_proxy.sh` + `health_proxy.js`)

**Purpose:** System health endpoints and monitoring
**Location:** `~/Library/02luka/bin/health_proxy.sh`
**Port:** 3002
**LaunchAgent:** `com.02luka.health.proxy.plist`

**Capabilities:**
- HTTP health endpoints for all system components
- Status aggregation
- Calendar health (`/calendar/health`)
- ICS serving (`/calendar/ics`)
- System-wide health check

**Endpoints:**
```
GET  /status                  → Overall system status
GET  /calendar/health         → Calendar sync health
GET  /calendar/ics            → Serve calendar ICS
POST /calendar/gcal/sync      → Trigger sync (requires token)
```

**Best For:**
- Quick system health checks
- Calendar status verification
- ICS file serving
- Health monitoring dashboards

**CLC Usage:**
```bash
# Instead of: Manually checking multiple services
# Use: Single health endpoint
curl http://localhost:3002/status
```

**Cost Savings:** Automated health aggregation vs manual checks

---

### 4. System Discovery Scanner (`system_discovery_scanner.sh`)

**Purpose:** Complete system state snapshot
**Location:** `g/tools/system_discovery_scanner.sh`
**Output:** `run/system_discovery_YYYYMMDD_HHMMSS.json`

**Capabilities:**
- Scan all LaunchAgents (status, health, errors)
- Docker container inventory
- MCP service status
- File system stats
- System configuration snapshot

**Output Structure:**
```json
{
  "timestamp": "2025-10-07T22:00:00Z",
  "launchagents": {
    "total": 130,
    "loaded": 107,
    "failed": 23,
    "details": [...]
  },
  "docker": {...},
  "mcp_services": {...},
  "system_stats": {...}
}
```

**Best For:**
- System state documentation
- Change detection (before/after)
- Troubleshooting baseline
- Discovery for ai_daily.json updates

**CLC Usage:**
```bash
# Instead of: Manual launchctl list + parsing
# Use: Run discovery scanner
SOT_PATH="$SOT" bash g/tools/system_discovery_scanner.sh
```

**Cost Savings:** One script vs dozens of manual commands

---

### 5. SOT Render System

**Purpose:** Human dashboard auto-generation
**Location:** `~/Library/02luka_runtime/tools/`
**LaunchAgent:** `org.02luka.sot.render.plist` (every 12h)

**Components:**
```
sot_render.sh      → Orchestrator script
sot_emit_md.py     → JSON → Markdown converter
sot_emit_html.py   → JSON → Styled HTML converter
```

**Workflow:**
```
ai_daily.json (machine) → sot_emit_md.py  → 02luka_daily.md (human)
                        → sot_emit_html.py → 02luka_daily.html (web)
```

**Best For:**
- Automated dashboard updates
- Human-readable reports from JSON
- Scheduled rendering (no manual intervention)

**CLC Usage:**
When dashboards need updating → Let LaunchAgent handle it, don't manually generate

**Cost Savings:** Fully automated vs manual dashboard creation

---

### 6. Model Router (`model_router.sh`)

**Purpose:** AI task routing to specialized local models
**Location:** `g/tools/model_router.sh`
**Output:** JSON routing decision

**Routing Logic:**
```bash
Input: TASK_TYPE + optional HINTS
Output: {"model": "...", "reason": "...", "confidence": 0.85}

Routes:
- generate/gen/default      → qwen2.5-coder
- review/code_review/audit  → deepseek-coder
- optimize/refine/improve   → llama3.1
```

**Best For:**
- Delegating code tasks to local AI
- Choosing right model for task type
- Offline AI workflows

**CLC Usage:**
```bash
# Get routing recommendation
ROUTE=$(model_router.sh review "need code critique")
MODEL=$(echo "$ROUTE" | jq -r '.model')

# Use suggested model
ollama run "$MODEL" < prompt.txt
```

**Cost Savings:** Routes to appropriate specialist, avoids Claude API for simple tasks

---

### 7. Context Engine (`context_engine.sh`)

**Purpose:** Context aggregation and pruning (future)
**Location:** `g/tools/context_engine.sh`
**Version:** 6.0 (Phase-1 safe mode)

**Current Status:**
- Pass-through mode (no mutation)
- Flags for future features: AUTO_PRUNE, ADVANCED_FEATURES
- Preparing for selective context pruning

**Future Capabilities:**
- Context size reduction
- Relevance filtering
- Format optimization
- Token budget adherence

**Best For (Future):**
- Reducing context size before AI submission
- Pruning irrelevant data
- Budget-aware context preparation

**Current CLC Usage:** Not active yet (Phase-1 safe mode)

---

### 8. Task Bus System

**Purpose:** Inter-agent task coordination
**Components:**
- `task_bus_control.sh` - Control script
- `task_bus_bridge.py` - Redis bridge (Python)
- `emit_task_event.sh` - Event publisher

**Location:** Port N/A (Redis channel: `mcp:tasks`)
**LaunchAgent:** `com.02luka.task.bus.bridge.plist`

**Capabilities:**
- Agent-to-agent communication
- Task state tracking
- Event broadcasting
- Memory persistence (`a/memory/active_tasks.json`)

**Usage:**
```bash
# Publish event (any agent can use)
bash g/tools/emit_task_event.sh clc action_name started "context data"

# Read events (Cursor via MCP or direct JSON read)
cat a/memory/active_tasks.json

# Control bus
bash g/tools/task_bus_control.sh {start|stop|status|logs}
```

**Best For:**
- CLC ↔ Cursor coordination
- Long-running task tracking
- Multi-agent workflows
- System state broadcasting

**CLC Usage:**
When delegating work to Cursor → Emit task events for visibility and tracking

**Cost Savings:** Eliminates repeated status queries between agents

---

## 🔄 Delegation Decision Matrix

### Decision Flow

```
New Task Arrives
     │
     ▼
[Is it searchable info?]
     │
     ├─ YES → Use librarian / existing tools
     └─ NO → Continue
            │
            ▼
     [Is it system health check?]
            │
            ├─ YES → Use health_proxy / discovery scanner
            └─ NO → Continue
                   │
                   ▼
            [Is it bulk code generation?]
                   │
                   ├─ YES → Delegate to Codex
                   │         (CLC validates after)
                   └─ NO → Continue
                          │
                          ▼
                   [Can local Ollama handle it?]
                          │
                          ├─ YES → Use model_router
                          └─ NO → Continue
                                 │
                                 ▼
                          [Requires complex reasoning?]
                                 │
                                 ├─ YES → CLC handles
                                 └─ NO → Check for specialized tool
```

### Task Type → Resource Mapping

| Task Type | Primary Resource | Fallback | Rationale |
|-----------|-----------------|----------|-----------|
| File search | librarian_v2.py | Bash find/grep | Zero cost, fast index |
| System health | health_proxy.sh | Manual checks | Aggregated endpoints |
| Code generation (bulk) | Codex | qwen2.5-coder | Cheaper than CLC |
| Code review | deepseek-coder | Codex | Specialized model |
| Code optimization | llama3.1 | Codex | Local, fast iteration |
| LaunchAgent cleanup | boot_guard.sh | Manual | Automated enforcement |
| System discovery | discovery_scanner.sh | Manual audit | Comprehensive snapshot |
| Dashboard rendering | sot_render agents | Manual | Scheduled automation |
| Task coordination | Task Bus | Direct messaging | Event-driven architecture |
| Complex decisions | CLC | N/A | Requires reasoning |
| Strategic planning | CLC | Human (Boss) | High-level judgment |
| Final validation | CLC | Manual review | Quality assurance |

### Cost Optimization Examples

**Example 1: Find all protocol files**
```
❌ Expensive: CLC uses Glob/Grep tools (burns 1K+ tokens)
✅ Cheap: Read librarian index (zero tokens)
   cat run/file_index.json | jq '.important_files[] | select(contains("protocol"))'
```

**Example 2: Generate Python emitter**
```
❌ Expensive: CLC writes code directly (5K+ tokens @ $75/1M output = $0.38)
✅ Cheap: Codex generates from golden prompt (~$0.05)
   Result: 87% cost savings
```

**Example 3: Check system health**
```
❌ Expensive: CLC runs launchctl, docker ps, checks (2K+ tokens)
✅ Cheap: curl http://localhost:3002/status (zero tokens)
```

**Example 4: Code review**
```
❌ Expensive: CLC reviews 500-line file (15K tokens @ expensive rate)
✅ Cheap: deepseek-coder via Ollama (zero API cost, local GPU)
   CLC reviews only the model's findings (2K tokens)
   Result: 87% token savings
```

---

## 📊 Resource Comparison Matrix

| Resource | Cost | Speed | Context | Best Use Case |
|----------|------|-------|---------|---------------|
| **CLC (Claude)** | 💰💰💰 High | Medium | Full system | Complex decisions, coordination |
| **Codex/Cursor** | 💰 Low | Fast | IDE-local | Code generation, bulk work |
| **Ollama Models** | 💵 Zero | Fast | Limited | Code tasks (offline) |
| **Librarian** | 💵 Zero | Instant | File index | File discovery, search |
| **Boot Guard** | 💵 Zero | Fast | Agent registry | LaunchAgent management |
| **Health Proxy** | 💵 Zero | Instant | System health | Health checks, monitoring |
| **Discovery Scanner** | 💵 Zero | Medium | Full system | State snapshots, diagnostics |
| **SOT Render** | 💵 Zero | Scheduled | Dashboard data | Automated reporting |
| **Model Router** | 💵 Zero | Instant | Task type | AI model selection |
| **Task Bus** | 💵 Zero | Real-time | Agent events | Inter-agent coordination |

---

## 🎯 CLC Delegation Protocol

### When Boss Says "Delegate to Codex"

**Default Action:** DELEGATE (respect Boss decision)

**Reasons Boss might delegate:**
1. **Cost optimization** - Heavy work cheaper elsewhere
2. **Speed** - Codex might be faster for bulk work
3. **Codex training** - System learns from the work
4. **Workflow adherence** - Following established patterns

**Process:**
```
1. Acknowledge delegation instruction
2. Create detailed golden prompt (.codex/prompts/)
3. Specify success criteria clearly
4. Hand off to Codex
5. Validate Codex output
6. Integrate and report
```

### When to Alert Boss Before Overriding

**Only if delegation seems unreasonable:**

```
⚠️ ALERT: Delegation Concern

TASK: [Brief description]

COST ANALYSIS:
- Codex delegation overhead: [estimate setup cost]
- Direct CLC implementation: [token estimate]
- Break-even point: [calculation]

COMPLEXITY: [Simple/Medium/Complex]

ALTERNATIVE RESOURCES:
- Librarian: [Can existing tool handle this?]
- Local agents: [Any specialized tool available?]
- Ollama: [Can local model handle?]

RECOMMENDATION: [Direct/Delegate with reasoning]

YOUR DECISION, BOSS?
```

**Wait for Boss response, then execute per instruction.**

### Never Silently Override

**Broken Rule:** Making autonomous decision to override Boss instruction without alert

**Impact:**
- Boss loses cost control visibility
- Token budget management compromised
- Trust/transparency broken
- Hidden context missed (Boss knows factors CLC doesn't)

**Correct Behavior:** Transparency mandatory, Boss has final authority

---

## 💡 Optimization Strategies

### 1. Check Local Resources First

Before using CLC/Codex:
```bash
# 1. Check librarian index for files
cat run/file_index.json | jq '.important_files'

# 2. Check health proxy for status
curl http://localhost:3002/status

# 3. Check discovery scanner for system state
ls -lt run/system_discovery_*.json | head -1
```

### 2. Batch Operations

Instead of multiple small CLC calls:
```
❌ Expensive:
- CLC call 1: Check file A exists (500 tokens)
- CLC call 2: Check file B exists (500 tokens)
- CLC call 3: Check file C exists (500 tokens)
Total: 1500 tokens

✅ Cheap:
- Read librarian index once (0 tokens)
- Check all files locally
Total: 0 tokens
```

### 3. Use Codex for Bulk, CLC for Validation

Pattern:
```
1. CLC creates detailed spec (2K tokens)
2. Codex generates implementation (cheap)
3. CLC validates result (1K tokens)

Total CLC: 3K tokens
vs All CLC: 15K+ tokens
Savings: 80%
```

### 4. Leverage Scheduled Agents

Don't manually regenerate what agents auto-update:
- ❌ Manually create 02luka_daily.md → Wait for sot_render agent (12h)
- ❌ Manually run discovery → Wait for automated_discovery_merge
- ❌ Manually check health → Use health_proxy endpoints

### 5. Local AI for Iteration

Use Ollama for:
- Quick code reviews (iterate fast)
- Optimization suggestions (free cycles)
- Template generation (no API cost)

Then CLC for final integration/validation.

---

## 📝 Future Enhancements

### 1. Automated Delegation Router

**Concept:** Script that analyzes task and auto-routes to best resource

```bash
# smart_delegate.sh
INPUT: Task description
OUTPUT: Recommended resource + reasoning

Example:
$ smart_delegate.sh "find all markdown files in protocols/"
→ Route: librarian_v2.py
→ Reason: File search task, zero cost
→ Command: jq '.important_files[] | select(contains("protocol"))' run/file_index.json
```

### 2. Cost Tracking Dashboard

Track actual token usage and savings:
```json
{
  "period": "2025-10",
  "clc_tokens": 2400000,
  "clc_cost": "$120.00",
  "codex_tokens": 5800000,
  "codex_cost": "$29.00",
  "local_tasks": 1200,
  "estimated_savings": "$450.00"
}
```

### 3. Context Engine Activation

When context_engine.sh reaches Phase-2:
- Auto-prune large contexts before CLC submission
- Reduce token usage by 30-50%
- Smart relevance filtering

### 4. Agent Capability Registry

Centralized registry of all agents + capabilities:
```json
{
  "agents": {
    "librarian_v2.py": {
      "type": "indexer",
      "cost": "zero",
      "capabilities": ["file_search", "indexing"],
      "use_when": "searching for files"
    },
    ...
  }
}
```

Query: "What agent can do X?" → Get recommendation

---

## 🏁 Summary

### Key Takeaways

1. **Multi-Tier System:** Not just Codex - many specialized agents exist
2. **Cost Hierarchy:** Local agents (free) → Ollama (free) → Codex (cheap) → CLC (expensive)
3. **Respect Boss Delegation:** Often contains cost strategy CLC doesn't see
4. **Transparency Required:** Alert if disagree, never silently override
5. **Check Local First:** Zero-cost tools before expensive AI

### Decision Authority

```
Boss Decision (Explicit) → CLC MUST respect (default behavior)
     │
     └─ CLC Assessment → Only if unreasonable
            │
            ├─ Alert Boss with reasoning
            ├─ Wait for Boss decision
            └─ Execute per Boss instruction
```

### Delegation Mindset

**Old (Wrong):**
- Default to CLC for everything
- Burn expensive tokens on searchable info
- Manual operations vs automation
- Silently override Boss instructions

**New (Correct):**
- Check local resources first
- Route to appropriate specialist
- Leverage automation
- Transparent communication with Boss
- Respect delegation instructions

---

**Generated:** 2025-10-07T22:00:00Z
**Author:** CLC (Claude Code)
**Purpose:** Learning proper delegation strategy
**Status:** Living document - update as system evolves
**Next Review:** When new agents added or costs change
