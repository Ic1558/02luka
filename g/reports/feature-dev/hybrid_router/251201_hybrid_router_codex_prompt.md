# Hybrid Router Implementation Prompt for Codex IDE

**Date:** 2025-12-01  
**Feature:** Hybrid Router V1 (Local + GG + Alter)  
**Status:** 🔧 Ready for Implementation  
**For:** CLS / Liam / Codex IDE

---

## Context

We have created a **Hybrid Router V1** skeleton that intelligently routes text tasks to:
- **Local engines** (Ollama) for internal/sensitive/high-volume work
- **GG** (ChatGPT Plus) for general reasoning and orchestration
- **Alter** (Polish API) for client-facing polish/translation

**Current Status:**
- ✅ Router skeleton created: `agents/ai_manager/hybrid_router.py`
- ✅ Worker example created: `agents/docs_v4/docs_worker.py` (method: `generate_client_report_with_hybrid_router`)
- ⚠️ **Engine hooks need to be wired** to actual clients
- ⚠️ **Draft builder needs enhancement** for real use cases

**Spec:** `g/reports/feature-dev/hybrid_router/251201_hybrid_router_spec_v01.md`  
**Plan:** `g/reports/feature-dev/hybrid_router/251201_hybrid_router_plan_v01.md`

---

## Tasks

### Task 1: Wire Engine Hooks in `hybrid_router.py`

**File:** `agents/ai_manager/hybrid_router.py`

**Current State:**
- Hooks are `NotImplementedError` placeholders:
  - `_call_local()` - Line ~150
  - `_call_gg()` - Line ~160
  - `_call_alter_polish()` - Line ~170

**What to Do:**

#### 1.1 Wire `_call_local()` to Ollama Client

**Find existing Ollama client in codebase:**
- Search for: `ollama`, `localhost:11434`, `local.*client`
- Check: `g/config/ai_providers.yaml` for LOCAL provider config
- Check: `agents/dev_common/reasoner_backend.py` or similar files

**Implementation pattern:**
```python
def _call_local(text: str, context: Dict[str, Any]) -> str:
    """
    Call local engine (Ollama / LM Studio).
    """
    # Option 1: Use existing client if available
    from agents.dev_common.reasoner_backend import call_ollama
    return call_ollama(text, context)
    
    # Option 2: Create OpenAI-compatible client for Ollama
    from openai import OpenAI
    import os
    
    base_url = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434/v1")
    model = os.getenv("OLLAMA_MODEL", "llama3")
    
    client = OpenAI(base_url=base_url, api_key="not-needed")
    response = client.chat.completions.create(
        model=model,
        messages=[
            {"role": "system", "content": "You are a helpful assistant."},
            {"role": "user", "content": text}
        ]
    )
    return response.choices[0].message.content
```

**Requirements:**
- ✅ Use existing Ollama client if available
- ✅ Fallback to OpenAI-compatible client if needed
- ✅ Handle errors gracefully (return original text or raise)
- ✅ Support context injection (project_id, mode, etc.)

#### 1.2 Wire `_call_gg()` to GG Client

**Find existing GG client in codebase:**
- Search for: `openai`, `gpt`, `chatgpt`, `gg.*client`
- Check: `agents/gpt_bridge/` or similar
- Check: How other workers call GG currently

**Implementation pattern:**
```python
def _call_gg(text: str, context: Dict[str, Any]) -> str:
    """
    Call GG (ChatGPT-based core) for reasoning / draft.
    """
    # Option 1: Use existing GG client
    from agents.gpt_bridge.gpt_memory import call_gpt
    return call_gpt(text, context)
    
    # Option 2: Use OpenAI client directly
    from openai import OpenAI
    import os
    
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        raise ValueError("OPENAI_API_KEY not set")
    
    client = OpenAI(api_key=api_key)
    
    # Build prompt with context
    system_prompt = "You are a helpful assistant."
    if context.get("project_id"):
        system_prompt += f"\nProject: {context['project_id']}"
    
    response = client.chat.completions.create(
        model="gpt-4",  # or from config
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": text}
        ]
    )
    return response.choices[0].message.content
```

**Requirements:**
- ✅ Use existing GG client if available
- ✅ Support context injection (project_id, mode, etc.)
- ✅ Handle API errors gracefully

#### 1.3 Wire `_call_alter_polish()` to AlterPolishService

**Alter service already exists:**
- File: `agents/alter/polish_service.py`
- Helper: `agents/alter/helpers.py`

**Implementation:**
```python
def _call_alter_polish(
    draft_text: str,
    context: Dict[str, Any],
) -> Tuple[str, Dict[str, Any]]:
    """
    Call AlterPolishService via API gateway.
    """
    from agents.alter.polish_service import AlterPolishService
    
    service = AlterPolishService()
    tone = context.get("tone", "formal")
    target_lang = context.get("language")
    
    if target_lang and target_lang != "en":
        # Translate + polish
        polished = service.polish_and_translate(draft_text, target_lang, tone=tone)
    else:
        # Polish only
        polished = service.polish_text(draft_text, tone=tone)
    
    # Check quota status
    tracker = service.tracker
    quota = tracker.check_quota(1)
    
    alter_meta = {
        "alter_status": "used" if polished != draft_text else "skipped",
        "quota_daily_remaining": quota.get("daily_remaining", 0),
        "quota_lifetime_remaining": quota.get("lifetime_remaining", 0),
    }
    
    return polished, alter_meta
```

**Requirements:**
- ✅ Use `AlterPolishService` from `agents/alter/polish_service.py`
- ✅ Support polish and translate modes
- ✅ Return metadata (alter_status, quota info)
- ✅ Handle quota exceeded gracefully

---

### Task 2: Enhance Draft Builder in `docs_worker.py`

**File:** `agents/docs_v4/docs_worker.py`

**Current State:**
- Method: `_build_initial_draft()` - Line ~467
- Currently: Simple markdown builder (placeholder)

**What to Do:**

#### 2.1 Enhance `_build_initial_draft()` for Real Use Cases

**Options:**

**Option A: Use GG to Generate Draft**
```python
def _build_initial_draft(self, task: Dict[str, Any]) -> str:
    """
    Generate draft using GG (or local if preferred).
    """
    from agents.ai_manager.hybrid_router import _call_gg
    
    # Build prompt from task
    project_id = task.get("project_id", "PD17")
    topic = task.get("topic", "client_report")
    title = task.get("title", "Client Report")
    
    prompt = f"""Generate a professional client report for:
- Project: {project_id}
- Topic: {topic}
- Title: {title}

Include:
1. Executive summary
2. Project status
3. Key findings
4. Recommendations

Format as markdown."""
    
    context = {
        "project_id": project_id,
        "mode": "draft",
        "source_agent": "docs_worker_v4",
    }
    
    try:
        return _call_gg(prompt, context)
    except Exception:
        # Fallback to simple markdown
        return self._build_simple_draft(task)
```

**Option B: Fetch from MLS/Ledger and Format**
```python
def _build_initial_draft(self, task: Dict[str, Any]) -> str:
    """
    Build draft from MLS/ledger data.
    """
    project_id = task.get("project_id", "PD17")
    
    # Fetch project data from MLS/ledger
    # (Implement based on your MLS structure)
    project_data = self._fetch_project_data(project_id)
    
    # Format as markdown
    lines = []
    lines.append(f"# {task.get('title', 'Client Report')}")
    lines.append("")
    lines.append(f"**Project:** {project_id}")
    lines.append("")
    
    if project_data:
        lines.append("## Project Overview")
        lines.append("")
        lines.append(project_data.get("description", ""))
        lines.append("")
    
    # Add more sections based on task requirements
    return "\n".join(lines)
```

**Requirements:**
- ✅ Generate meaningful draft (not just placeholder)
- ✅ Use GG or fetch from MLS based on task
- ✅ Support project context (PD17, etc.)
- ✅ Handle errors gracefully (fallback to simple draft)

---

### Task 3: Test Integration

**Create test file:** `tests/test_hybrid_router_integration.py`

**Test Cases:**
```python
def test_high_sensitivity_routes_to_local():
    """Test that high sensitivity routes to local engine."""
    from agents.ai_manager.hybrid_router import hybrid_route_text
    
    context = {
        "sensitivity": "high",
        "client_facing": False,
        "mode": "draft",
        "source_agent": "test",
    }
    
    text, meta = hybrid_route_text("Test text", context)
    assert meta["engine_used"] == "local_general"

def test_client_facing_routes_to_alter():
    """Test that client-facing routes through Alter."""
    from agents.ai_manager.hybrid_router import hybrid_route_text
    
    context = {
        "client_facing": True,
        "mode": "polish",
        "project_id": "PD17",
        "source_agent": "test",
    }
    
    text, meta = hybrid_route_text("Draft text", context)
    assert meta["engine_used"] == "alter_polish" or meta.get("draft_engine") is not None

def test_docs_worker_integration():
    """Test docs worker with hybrid router."""
    from agents.docs_v4.docs_worker import DocsWorkerV4
    
    worker = DocsWorkerV4()
    task = {
        "project_id": "PD17",
        "topic": "client_report",
        "title": "Test Report",
        "client_facing": True,
        "mode": "polish",
    }
    
    result = worker.generate_client_report_with_hybrid_router(task)
    assert result["ok"] is True
    assert "engine_used" in result
```

---

## Implementation Guidelines

### 1. Error Handling

**Always handle errors gracefully:**
- Don't crash the worker
- Return original text if all engines fail
- Log errors for debugging
- Set `fallback: True` in metadata

### 2. Context Injection

**Always inject context into prompts:**
- Project ID
- Mode (draft, polish, translate)
- Sensitivity level
- Source agent

### 3. Configuration

**Use config files, not hard-coded values:**
- `g/config/ai_providers.yaml` for provider configs
- Environment variables for API keys
- Logical provider IDs (not hard-coded URLs)

### 4. Testing

**Test each hook independently:**
- Mock providers for unit tests
- Test real integration with small examples
- Verify fallback mechanisms work

---

## Files to Modify

1. **`agents/ai_manager/hybrid_router.py`**
   - Wire `_call_local()` (Line ~150)
   - Wire `_call_gg()` (Line ~160)
   - Wire `_call_alter_polish()` (Line ~170)

2. **`agents/docs_v4/docs_worker.py`**
   - Enhance `_build_initial_draft()` (Line ~467)

3. **`tests/test_hybrid_router_integration.py`** (NEW)
   - Create integration tests

---

## Dependencies

**Already Available:**
- ✅ `AlterPolishService` - `agents/alter/polish_service.py`
- ✅ `ai_providers.yaml` - `g/config/ai_providers.yaml`
- ✅ Router skeleton - `agents/ai_manager/hybrid_router.py`

**Need to Find/Create:**
- ⚠️ Ollama client (search codebase or create)
- ⚠️ GG client (search codebase or create)
- ⚠️ MLS data fetcher (if using Option B for draft builder)

---

## Success Criteria

- ✅ All three hooks wired and working
- ✅ Draft builder generates meaningful content
- ✅ Integration tests pass
- ✅ No regressions in existing functionality
- ✅ Error handling works (fallback mechanisms)

---

## Next Steps After Implementation

1. **Test with real use case:**
   ```python
   worker = DocsWorkerV4()
   task = {
       "project_id": "PD17",
       "topic": "client_report",
       "title": "Monthly Status Report",
       "client_facing": True,
       "mode": "polish",
   }
   result = worker.generate_client_report_with_hybrid_router(task)
   ```

2. **Verify router decisions:**
   - High sensitivity → Local
   - Normal internal → GG
   - Client-facing → GG draft → Alter polish

3. **Check save gateway:**
   - Verify `tools/save.sh` receives content
   - Verify files saved correctly
   - Verify metadata in `latest_status.yaml`

---

## Questions to Answer

Before implementing, answer:
1. **Where is the Ollama client?** (Search codebase)
2. **Where is the GG client?** (Search codebase)
3. **How to fetch project data from MLS?** (If using Option B)
4. **What model/config to use for each engine?** (Check `ai_providers.yaml`)

---

**Prompt Version:** 1.0  
**Last Updated:** 2025-12-01  
**Status:** 🔧 Ready for Codex IDE
