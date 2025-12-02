# Hybrid Router Spec (Local + GG + Alter)

**Code name:** HYBRID_ROUTER_V1  
**Date:** 2025-12-01  
**Owner:** Mary / AI Manager  
**Status:** 📋 **SPEC READY FOR REVIEW**  
**Authority:** AI:OP-001 v4.1 Governance Protocol  
**File:** `g/reports/feature-dev/hybrid_router/251201_hybrid_router_spec_v01.md`

---

## Executive Summary

**Goal:** Create a **Hybrid Router** that intelligently routes text tasks to the appropriate AI engine:
- **Local engines** (Ollama / LM Studio) for internal/sensitive/high-volume work
- **GG** (ChatGPT Plus) for general reasoning and orchestration
- **Alter** (Polish API) for client-facing polish/translation

**Key Principle:** Use **Local + GG as primary**, **Alter only when necessary** for presentation quality.

**Memory Contract:** 02luka = single source of truth for all memory. Alter = stateless polish engine only.

---

## 1. Goal

- Use **Local + GG as primary** engines
- Use **Alter only when necessary** for:
  - Client-facing content
  - Polish/translation needs
  - "Make it look good" tasks
- **Do not change memory model:**
  - **02luka = stores all memory** (MLS, ledger, session_save)
  - Alter = **polish engine only**, no memory

---

## 2. Scope / Non-goal

### In-Scope (V1)

- **Single router function:**
  ```python
  routed_text = route_and_execute(text, context: Dict) -> str
  ```
- **Decision based on:**
  - `context.sensitivity` (internal / client)
  - `context.client_facing` (True/False)
  - `context.project_id` (e.g., PD17)
  - `context.mode` (draft, analysis, polish, translate)
- **Use existing providers:**
  - Local: Ollama (via existing client)
  - GG: Currently used in system
  - Alter: Via `AlterPolishService` (from PR #389)

### Out-of-Scope (V1)

- ❌ No RL / learning / adaptive router
- ❌ No changes to MLS, session_save structure
- ❌ No new providers (Kimi, Gemini, etc.) in this phase

---

## 3. Architecture Overview

### 3.1 High-Level Flow

```
User / Agent
    │
    ▼
Hybrid Router (Mary / AI Manager)
    ├─ Local engines  (Ollama / others)
    ├─ GG core        (normal reasoning)
    └─ Alter Polish   (client-facing polish/translate)
```

### 3.2 Decision Rules (V1, Minimal)

#### Rule 1: Ultra-sensitive / Internal Draft
```
IF context.sensitivity == "high"
THEN use Local only
```

**Use case:** Internal analysis, sensitive data processing

#### Rule 2: Normal Internal Work
```
IF client_facing == False AND mode in ["draft", "analysis"]
THEN use GG (primary reasoning engine)
```

**Use case:** Daily work, general reasoning, orchestration

#### Rule 3: Client-Facing / Document / Proposal
```
IF client_facing == True OR mode in ["polish", "translate"]
THEN Flow:
  1. GG / Local creates draft first
  2. Router sends draft + context to AlterPolishService
  3. Returns polished text
  4. Quota / Error Handling:
     - If Alter quota warning / error:
       - Return draft from GG/Local
       - Add flag: alter_status: "skipped"
```

**Use case:** Client reports, proposals, bilingual content

---

## 4. Router Interface Contract

### 4.1 Context Structure (Minimal for V1)

```python
Context = Dict[str, Any]  # minimal fields for V1

# Example
context = {
    "project_id": "PD17",
    "client_facing": True,         # client will see or not
    "sensitivity": "normal",       # "high" | "normal" | "low"
    "mode": "polish",              # "draft" | "analysis" | "polish" | "translate"
    "language": "th-en",           # th, en, th-en
    "source_agent": "docs_worker",  # who is calling
}
```

### 4.2 Public API (Within 02luka)

```python
def hybrid_route_text(text: str, context: Dict) -> str:
    """
    Decide engine and execute:
      - Local (Ollama) for high-sensitivity / some drafts
      - GG for general reasoning
      - AlterPolishService for polish/translate when client_facing
    
    Returns final text (never raises hard error).
    
    Returns:
        str: Final processed text
        Dict: Metadata (optional, for telemetry)
            {
                "engine_used": "local" | "gg" | "alter",
                "alter_status": "used" | "skipped" | "error",
                "fallback": True/False
            }
    """
```

### 4.3 Engine Slots (Config-based)

**File:** `g/config/ai_providers.yaml` (or existing config)

```yaml
providers:
  local_general:
    type: "local"
    engine: "ollama"
    model: "llama3"
    base_url: "http://localhost:11434/v1"
  
  gg_core:
    type: "remote"
    engine: "openai"
    model: "gpt-4.1"  # or actual model in use
    api_key_env: "OPENAI_API_KEY"
  
  alter_polish:
    type: "remote"
    engine: "alter"
    model: "Claude#claude-3-haiku-20240307"
    base_url: "https://alterhq.com/api/v1"
    api_key_env: "ALTER_API_KEY"
```

**Router uses logical names** like `"local_general"`, `"gg_core"`, `"alter_polish"` - **no hard-coded base_url or api_key**.

---

## 5. Memory & History Contract

### ⚠️ Critical: Alter Has No Memory

- **Router must NOT assume Alter remembers anything:**
  - Projects (e.g., PD17)
  - Users (Boss)
  - Past conversations

### ✅ Memory Lives in 02luka

**Router must fetch context/memory from:**
- MLS / ledger entries
- Project context files
- `session_save` snapshots

**Example flow:**
```
1. Worker needs to process text for PD17
2. Router fetches PD17 context from MLS/ledger
3. Router builds context dict:
   {
     "project_id": "PD17",
     "project_type": "residential 3-story",
     "budget": "3.2M Baht",
     "recent_decisions": [...],
     ...
   }
4. Router injects context into prompt
5. Router sends to appropriate engine (Local/GG/Alter)
```

### Alter = Polish Only

- **No state storage**
- **No file operations**
- **No memory**
- **Just:** `input text → better text`

---

## 6. Phase Plan (For Next Feature-Dev)

### Phase H1 – Skeleton (Low Risk)

**Tasks:**
1. Create `hybrid_route_text(text, context)` in `agents/ai_manager/` (or designated path)
2. Bind to provider IDs: `local_general`, `gg_core`, `alter_polish`
3. Write unit tests:
   - `sensitivity == "high"` → local
   - `client_facing == True, mode == "polish"` → alter
   - `otherwise` → gg_core

**Files:**
- `agents/ai_manager/hybrid_router.py` (new)
- `tests/test_hybrid_router.py` (new)

**Estimated Time:** 1-2 days

### Phase H2 – First Integrations

**Tasks:**
1. Use router in:
   - Docs worker (replace direct GG/Alter calls)
   - 1-2 clear workers (e.g., report / proposal)
2. Add disable flag (ENV):
   - `HYBRID_ROUTER_ENABLED=0/1`

**Files:**
- Modify `agents/docs_v4/docs_worker.py`
- Modify `agents/lac_manager/lac_manager.py` (if applicable)
- Update config files

**Estimated Time:** 2-3 days

### Phase H3 – Telemetry & Tuning (Optional)

**Tasks:**
1. Log:
   - Which engine used for each task
   - Response time
   - Alter quota usage
2. Send logs to Liam / analytics for review

**Files:**
- `agents/ai_manager/hybrid_router_telemetry.py` (new)
- Log files in `g/data/memory/hybrid_router_logs.jsonl`

**Estimated Time:** 1-2 days

**Note:** No auto-learning in V1

---

## 7. Success Criteria (V1)

- ✅ Workers use `hybrid_route_text()` instead of direct GG/Alter calls in at least 1-2 real points
- ✅ No regression with existing flow (if router fails → still fallback works)
- ✅ Alter is used **only for:**
  - Client-facing content
  - Polish / translate mode
- ✅ Clear path forward for:
  - Adding local models
  - Adding learning router in future

---

## 8. Implementation Notes

### 8.1 Error Handling

**Router must never crash:**
```python
try:
    result = hybrid_route_text(text, context)
except Exception as e:
    # Fallback to GG (most reliable)
    result = call_gg(text, context)
    result["fallback"] = True
    result["error"] = str(e)
```

### 8.2 Quota Management

**Alter quota handling:**
- Check quota before calling Alter
- If quota exceeded → return draft from GG/Local
- Add flag: `alter_status: "quota_exceeded"`

### 8.3 Context Injection

**Before calling any engine:**
1. Fetch project context from MLS/ledger
2. Fetch user preferences
3. Fetch recent decisions
4. Build structured prompt:
   ```
   CONTEXT:
   Project: PD17
   Type: residential 3-story
   Budget: 3.2M Baht
   Recent decisions: [...]
   
   TASK:
   [text to process]
   ```

---

## 9. Dependencies

### Required (Already Exists)

- ✅ `AlterPolishService` (from PR #389)
- ✅ `ai_providers.yaml` config
- ✅ Local Ollama client (existing)
- ✅ GG client (existing)
- ✅ MLS / ledger system (existing)

### New (To Be Created)

- `agents/ai_manager/hybrid_router.py` (new)
- `tests/test_hybrid_router.py` (new)
- Config updates for router settings

---

## 10. Out of Scope (Future Phases)

### Not in V1:

- ❌ Adaptive learning router
- ❌ Cost optimization (beyond basic quota checks)
- ❌ Multi-provider fallback chains
- ❌ Real-time provider health monitoring
- ❌ A/B testing framework

**These can be added in future phases if needed.**

---

## 11. References

- **Alter Integration:** `g/reports/feature-dev/alter_ai_integration/251201_alter_ai_integration_spec_v02.md`
- **Alter Communication Map:** `g/reports/feature-dev/alter_ai_integration/ALTER_COMMUNICATION_MAP.md`
- **AI:OP-001 v4.1:** `g/docs/AI_OP_001_v4.md`

---

## 12. Next Steps

1. **Review this spec** with CLS / Mary / AI Manager
2. **Create implementation plan** (PLAN v01) if approved
3. **Start Phase H1** (skeleton implementation)
4. **Test with 1-2 real workers** before full rollout

---

**Spec Version:** 1.0  
**Last Updated:** 2025-12-01  
**Status:** 📋 **SPEC READY FOR REVIEW**
