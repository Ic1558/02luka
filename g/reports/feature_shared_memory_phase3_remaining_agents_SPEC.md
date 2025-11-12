# Feature SPEC: Shared Memory Phase 3 - Remaining Agents Integration

**Feature ID:** `shared_memory_phase3_remaining_agents`  
**Version:** 1.0.0  
**Date:** 2025-11-12  
**Status:** Ready for Implementation

---

## Objective

Integrate remaining agents (GPT/GG, Gemini) into the shared memory system, enabling full agent coordination and maximizing token savings across all 02luka agents.

---

## Problem Statement

Phase 2 integrated GC and CLS, but:
- GPT/GG (ChatGPT) not integrated
- Gemini not integrated
- No unified context across all agents
- Token savings limited to GC/CLS only

**Impact:**
- GPT/GG still repeats context
- Gemini operates in isolation
- Token savings not maximized
- No full system coordination

---

## Solution Overview

Phase 3 adds:
1. **GPT/GG Integration:** Python bridge for ChatGPT
2. **Gemini Integration:** CLI wrapper for Gemini
3. **Unified Context:** All agents share same context
4. **Token Optimization:** Maximum savings across all agents

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│ Phase 3: Remaining Agents Integration                   │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐            │
│  │ GC       │  │ CLS      │  │ GPT/GG   │            │
│  │ (Phase2) │  │ (Phase2) │  │ (Phase3) │            │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘            │
│       │             │              │                  │
│       └─────────────┼──────────────┘                  │
│                     │                                  │
│              ┌──────▼──────┐                         │
│              │ Shared Memory │                         │
│              │ (Phase 1+2)   │                         │
│              └──────┬───────┘                          │
│                     │                                  │
│              ┌──────▼──────┐                         │
│              │ Gemini      │                         │
│              │ (Phase3)     │                         │
│              └──────────────┘                          │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

---

## Components

### 1. GPT/GG Memory Bridge (`agents/gpt_bridge/gpt_memory.py`)

**Purpose:** Python bridge for GPT/GG (ChatGPT) to interact with shared memory

**Functions:**
- `get_context_for_gpt()` - Get shared context formatted for GPT system message
- `save_gpt_response(response)` - Save GPT response to shared memory

**Usage:**
```python
from agents.gpt_bridge.gpt_memory import GPTMemoryBridge

bridge = GPTMemoryBridge()
context = bridge.get_context_for_gpt()
# Use context as system message for GPT
response = gpt_call(context, user_message)
bridge.save_gpt_response(response)
```

**Integration:**
- Calls `memory_sync.sh` for status updates
- Writes to `bridge/memory/outbox/` for responses
- Formats context as GPT system message

### 2. Gemini Memory Wrapper (`tools/gemini_memory_wrapper.sh`)

**Purpose:** CLI wrapper for Gemini that includes shared context

**Usage:**
```bash
# Instead of: gemini-cli "your question"
# Use: gemini_memory_wrapper.sh "your question"

gemini_memory_wrapper.sh "What are we working on?"
```

**Features:**
- Loads shared context automatically
- Builds system prompt with agent status
- Updates memory after execution
- Transparent wrapper (same interface as gemini-cli)

**Integration:**
- Reads from `shared_memory/context.json`
- Updates via `memory_sync.sh`
- Maintains Gemini CLI compatibility

---

## Data Flow

### GPT/GG Integration Flow

```
GPT/GG Request
    ↓
get_context_for_gpt() → Format as system message
    ↓
GPT API Call (with context)
    ↓
save_gpt_response() → Update memory + bridge
    ↓
Shared Memory Updated
```

### Gemini Integration Flow

```
Gemini CLI Call
    ↓
gemini_memory_wrapper.sh
    ↓
Load shared context
    ↓
Build system prompt (agents + work)
    ↓
Call gemini-cli (with context)
    ↓
Update memory after execution
```

---

## Integration Points

### Existing Systems
- **Phase 1:** Shared memory structure, bridge system
- **Phase 2:** GC/CLS integration
- **GPT API:** OpenAI/ChatGPT API
- **Gemini CLI:** Existing gemini-cli tool

### New Integration
- **GPT Bridge:** Python module for GPT integration
- **Gemini Wrapper:** Shell wrapper for Gemini CLI

---

## Success Criteria

✅ **Functional:**
- GPT/GG can load shared context
- GPT/GG can save responses
- Gemini wrapper works transparently
- All agents share same context

✅ **Token Savings:**
- GPT/GG: 60-80% reduction
- Gemini: 60-80% reduction
- Overall system: 70-85% reduction

✅ **Coordination:**
- All agents aware of each other
- No redundant context
- Unified work tracking

---

## Configuration

### Environment Variables
- `LUKA_SOT`: `/Users/icmini/02luka` (default)
- `OPENAI_API_KEY`: For GPT/GG (if needed)
- `GEMINI_API_KEY`: For Gemini (if needed)

### File Locations
- GPT Bridge: `agents/gpt_bridge/gpt_memory.py`
- Gemini Wrapper: `tools/gemini_memory_wrapper.sh`

---

## Future Enhancements

1. **Advanced Context Formatting:**
   - Agent-specific context filtering
   - Relevance scoring
   - Context compression

2. **Response Caching:**
   - Cache GPT/Gemini responses
   - Reuse similar queries
   - Further token savings

3. **Agent Coordination:**
   - Work handoff protocols
   - Conflict resolution
   - Priority queuing

---

## References

- **Phase 1 SPEC:** `g/reports/feature_shared_memory_system_SPEC.md`
- **Phase 2 SPEC:** `g/reports/feature_shared_memory_phase2_gc_cls_SPEC.md`
- **SOT Path:** `/Users/icmini/02luka`

