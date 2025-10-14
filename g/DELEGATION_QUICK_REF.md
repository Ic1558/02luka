# Delegation Quick Reference Card

**Last Updated:** 2025-10-07T22:00:00Z
**Full Doc:** `g/reports/DELEGATION_SYSTEM_MAP_251007_2200.md`

---

## 🚦 First Check - Before Using CLC Tokens

```bash
# 1. SEARCH - Use librarian index (zero cost)
cat "$SOT/run/file_index.json" | jq '.important_files[] | select(contains("..."))'

# 2. HEALTH - Use health proxy (zero cost)
curl http://localhost:3002/status

# 3. DISCOVERY - Use latest scanner output (zero cost)
cat $(ls -t "$SOT/run/system_discovery_*.json" | head -1) | jq '...'

# 4. FILE CONTENT - Read directly (don't ask CLC to summarize)
cat path/to/file.md
```

---

## 🎯 Quick Decision Tree

```
Task → Resource

File search               → librarian_v2.py (index: run/file_index.json)
System health check       → health_proxy (curl localhost:3002/status)
LaunchAgent management    → boot_guard.sh
System snapshot           → discovery_scanner.sh (automated)
Bulk code generation      → Codex (CLC validates after)
Code review              → deepseek-coder (Ollama) or Codex
Code optimization        → llama3.1 (Ollama)
Dashboard update         → sot_render agents (automated)
Complex decision         → CLC
Strategic planning       → CLC → Boss
Task coordination        → Task Bus (emit_task_event.sh)
```

---

## 💰 Cost Hierarchy (Cheapest First)

```
1. 💵 Local Agents     → ZERO cost, instant (USE FIRST)
2. 💵 Ollama Models    → ZERO cost, local GPU (code tasks)
3. 💰 Codex            → LOW cost (bulk code gen)
4. 💰💰💰 CLC (Claude)  → HIGH cost (complex decisions only)
```

---

## 🤖 Agent Capabilities (Zero Cost Tools)

| Agent | Purpose | Command |
|-------|---------|---------|
| **librarian_v2** | File search | `cat run/file_index.json` |
| **boot_guard** | Agent cleanup | `bash ~/Library/02luka/bin/boot_guard.sh` |
| **health_proxy** | Health check | `curl localhost:3002/status` |
| **discovery_scanner** | System snapshot | Auto-runs, read `run/system_discovery_*.json` |
| **sot_render** | Dashboard | Auto-runs every 12h |
| **model_router** | AI routing | `model_router.sh <task_type>` |
| **task_bus** | Agent coordination | `emit_task_event.sh agent action status` |

---

## 📋 Boss Delegation Protocol

### When Boss Says "Delegate to [Resource]"

**Default:** ✅ EXECUTE AS INSTRUCTED

Boss knows:
- Cost optimization strategy
- Resource availability
- Learning objectives
- System priorities

### Only Override If Unreasonable

**Must Alert First:**
```
⚠️ ALERT: Delegation Concern

TASK: [description]
COST: Direct=[X tokens] vs Delegate=[Y overhead]
COMPLEXITY: [Simple/Complex]
ALTERNATIVES: [local tools available?]

RECOMMENDATION: [reasoning]
YOUR DECISION, BOSS?
```

**Then wait for Boss response.**

### NEVER Silently Override

❌ **Broken rule:** Acknowledge delegation, then do it yourself
✅ **Correct:** Respect instruction OR alert with reasoning

---

## 🎓 Common Mistakes to Avoid

| ❌ Wrong | ✅ Right |
|---------|---------|
| CLC searches for files | Read librarian index |
| CLC checks agent status | Use health_proxy or discovery |
| CLC writes bulk code | Codex generates, CLC validates |
| Manual dashboard update | Let sot_render agent handle |
| Silent delegation override | Alert Boss with reasoning |
| Assume expensive = better | Check local resources first |
| `find ~` search (timeout) | Librarian index → git history |

## ⚠️ Case Study: save.sh Search Hypocrisy

**What CLC documented (Oct 7):**
> 🚦 First Check - Use librarian index (zero cost)

**What CLC actually did (Oct 8):**
```bash
❌ find ~ -name "save.sh"        # Timeout 2min, 1,500 tokens wasted
❌ ls ~/dev/02luka/...            # Blind path attempts
❌ ls $CloudStorage/...           # More failures
⏰ git log (eventually worked)   # Should have been step 2
```

**What CLC should have done:**
```bash
✅ cat run/file_index.json | jq '... | select(contains("save"))'  # 0 tokens, instant
✅ git ls-tree -r HEAD | grep save.sh                              # 100 tokens, fast
✅ git checkout HEAD -- save.sh                                    # Restore
```

**Lesson:** Documentation without application = useless. Practice delegation principles, don't just write them.

**Token comparison:**
- Wrong approach: 1,500 tokens, 2min+ timeout, user frustration
- Right approach: 100 tokens, <10 seconds, Boss happy

**See:** `g/reports/SAVE_COMMAND_FIX_251008_0141.md` for full analysis

---

## 🔄 Codex Delegation Workflow

```
1. CLC creates golden prompt
   Location: .codex/prompts/TASK_NAME.md
   Content: Detailed spec with success criteria

2. Codex generates implementation
   (cheaper tokens for bulk work)

3. CLC validates output
   - Check success criteria
   - Integration testing
   - Final approval

4. CLC integrates and reports

Result: 70-80% token savings
```

---

## 🛠️ Local AI Models (Ollama)

```bash
# Auto-route by task type
model_router.sh generate     → qwen2.5-coder
model_router.sh review       → deepseek-coder
model_router.sh optimize     → llama3.1

# Direct usage
ollama run qwen2.5-coder "write Python script to..."
ollama run deepseek-coder "review this code: ..."
ollama run llama3.1 "optimize this function: ..."
```

**When to use:**
- Offline work (no internet)
- Fast iteration (no API latency)
- Privacy-sensitive code
- Budget exhausted

---

## 🎯 Delegation Examples

### Example 1: Find Protocol Files

❌ **Expensive (5K tokens):**
```
CLC: Uses Glob tool to search entire SOT
CLC: Reads multiple directories
CLC: Filters results manually
Cost: ~$0.38
```

✅ **Cheap (0 tokens):**
```bash
cat run/file_index.json | jq '.important_files[] | select(contains("protocol"))'
Cost: $0.00
```

### Example 2: Generate Python Script

❌ **Expensive (15K tokens):**
```
CLC: Writes full Python script
CLC: Iterates on bugs
CLC: Adds documentation
Cost: ~$1.13
```

✅ **Cheap (3K tokens CLC + Codex):**
```
1. CLC: Creates golden prompt (2K tokens) = $0.15
2. Codex: Generates implementation = $0.10
3. CLC: Validates output (1K tokens) = $0.08
Total: $0.33 (71% savings)
```

### Example 3: System Health Check

❌ **Expensive (3K tokens):**
```
CLC: Runs launchctl list
CLC: Runs docker ps
CLC: Checks MCP status
CLC: Aggregates results
Cost: ~$0.23
```

✅ **Cheap (0 tokens):**
```bash
curl http://localhost:3002/status
Cost: $0.00
```

---

## 📊 Monthly Budget Impact

**Example Month:**
```
Scenario: 100 tasks per month

Old (All CLC):
- Avg 10K tokens/task
- Total: 1M tokens
- Cost: ~$60

New (Smart Delegation):
- 30 local agent tasks: 0 tokens ($0)
- 40 Codex tasks: 200K tokens ($10)
- 30 CLC complex tasks: 300K tokens ($18)
- Total: 500K tokens ($28)

Savings: $32/month (53%)
```

---

## 🔍 Quick Lookups

### LaunchAgent Status
```bash
# All agents
launchctl list | grep com.02luka

# Specific agent
launchctl print gui/$UID/com.02luka.AGENT_NAME
```

### File Locations
```bash
# Agent tools
~/Library/02luka/bin/

# Runtime tools
~/Library/02luka_runtime/tools/

# SOT tools
$SOT/g/tools/

# Indexes
$SOT/run/file_index.json
$SOT/run/system_discovery_*.json
```

### Health Endpoints
```bash
# Overall status
curl http://localhost:3002/status

# Calendar health
curl http://localhost:3002/calendar/health

# MCP FS health
curl http://localhost:8765/health
```

---

## 🎯 Remember

1. **Check local resources FIRST** - Zero cost, often faster
2. **Respect Boss delegation** - Hidden context you don't see
3. **Use Codex for bulk code** - 70-80% cost savings
4. **CLC for complex decisions** - Your core competency
5. **Never silently override** - Transparency mandatory

**Full Documentation:** `g/reports/DELEGATION_SYSTEM_MAP_251007_2200.md`

---

**Generated:** 2025-10-07T22:00:00Z
**For:** CLC (Claude Code) quick reference
**Update:** When new agents added or workflows change
