# Liam System Integration Summary

## Flow Diagram

```
Boss
  ↓
GMX CLI v2 (Planner)
  ↓ writes JSON spec
g/wo_specs/*.json
  ↓
Liam Executor
  ├→ write_ledger_entry (g/ledger/ap_io_v31.jsonl)
  └→ write_to_bridge (bridge/inbox/*)
        ↓
   Bridge Inbox
        ↓
 Hybrid / Mary / Runtime Agents
```

---

## Component Relationships

### Boss → GMX CLI v2
- Boss provides natural language request
- GMX converts to structured JSON `task_spec`
- Output: `g/wo_specs/*.json`

### GMX → Liam Executor
- Liam reads GMX-generated spec
- Validates structure
- Executes steps sequentially

### Liam → AP/IO Ledger
- All decisions logged to `g/ledger/ap_io_v31.jsonl`
- Events: `task_received`, `task_scheduled`, `task_completed`
- Uses `tools.ap_io_v31.writer.write_ledger_entry()`

### Liam → Bridge
- Creates Work Orders in `bridge/inbox/<AGENT>/`
- Format: YAML or JSON
- Targets: LIAM, GEMINI, HYBRID, etc.

### Bridge → Runtime Agents
- Mary Router processes inbox
- Dispatches to appropriate agents
- Hybrid executes shell commands
- Other agents handle specialized tasks

---

## Key Files

| File | Purpose |
|------|---------|
| `agents/liam/PERSONA_PROMPT.md` | Core identity & rules |
| `agents/liam/executor.py` | GMX spec executor |
| `agents/liam/core.py` | Task lifecycle management |
| `agents/liam/mary_router.py` | Routing & oversight |
| `tools/ap_io_v31/writer.py` | Ledger writer |
| `docs/AP_IO_V31_PROTOCOL.md` | Protocol specification |

---

## Operational Lanes

1. **feature-dev**: Design → Plan → GMX spec → Executor
2. **code-review**: Analyze → Critique → Suggest improvements
3. **deploy**: Plan → Safety checks → Rollback strategy

---

## Safety Guarantees

- ✅ No writes outside `bridge/inbox`
- ✅ All decisions logged to AP/IO ledger
- ✅ Forbidden zones protected (governance files)
- ✅ GMX specs validated before execution
- ✅ Lifecycle events tracked end-to-end
