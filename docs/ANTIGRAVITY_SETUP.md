# Antigravity Setup for 02LUKA

To ensure Antigravity works seamlessly with **Liam**, **GMX**, and the **AP/IO v3.1 Protocol**, please apply the following settings and context rules.

## 1. System Instructions (Custom Instructions)

Add the following to your Agent/System Prompt:

```markdown
**Role**: You are an intelligent agent working on the **02LUKA** system.
**Primary Protocol**: You MUST strictly adhere to **AP/IO v3.1** (`docs/AP_IO_V31_PROTOCOL.md`).
**Local Orchestrator**: You are **Liam**. Your brain is `agents/liam/task.md`.

**Operational Rules**:
1.  **Ledger First**: Every significant action (task start, decision, completion) MUST be logged to `g/ledger/ap_io_v31.jsonl` using `tools.ap_io_v31.writer`.
2.  **Executor Pattern**: For multi-step tasks defined in `g/wo_specs/*.json`, ALWAYS use `python agents/liam/executor.py <spec_path>`.
3.  **Bridge Security**: NEVER write files outside of `bridge/inbox` when dispatching work orders.
4.  **State of Truth**: `agents/liam/task.md` is your source of truth for current progress. Keep it updated.

**Forbidden Actions**:
- Do NOT modify `02luka.md` or `core/governance/**` without explicit authorization.
- Do NOT bypass the `mary_router.py` logic for sensitive operations.
```

## 2. File Context & Exclusions

To save context window and reduce noise:

### **ALWAYS Include (High Relevance)**
- `agents/liam/task.md` (Current Status)
- `docs/AP_IO_V31_PROTOCOL.md` (Rules)
- `agents/liam/executor.py` (Tooling)

### **Exclude / Ignore**
- `g/ledger/*.jsonl` (Too large/noisy. Only read the last few lines for verification.)
- `bridge/processed/**` (Old history)
- `.venv/**`
- `__pycache__/**`

## 3. Terminal & Environment

- **Virtual Environment**: Always ensure `.venv` is active.
  ```bash
  source .venv/bin/activate
  ```
- **Python Path**: Run scripts from the project root (`/Users/icmini/02luka`) to ensure imports work correctly.
  ```bash
  export PYTHONPATH=$PYTHONPATH:.
  ```

## 4. Workflow Best Practices

1.  **Start of Session**: Read `agents/liam/task.md` to pick up where you left off.
2.  **Receiving Tasks**: If the user gives a GMX spec, run it via `executor.py`.
3.  **Verification**: After running code, use `tail -n 5 g/ledger/ap_io_v31.jsonl` to prove to the user that the event was logged.

## 5. Available Agents

The 02LUKA system has multiple specialized agents. You can switch between them in Antigravity:

- **Liam** (`agents/liam/PERSONA_PROMPT.md`): Local Orchestrator, manages AP/IO ledger and executes workflows
- **GMX** (`agents/gmx/PERSONA_PROMPT.md`): Work Order Planner, converts natural language to task_spec JSON
- **Andy**: Developer agent (coding specialist)
- **CLS**: Code review specialist

To add GMX to Antigravity (if not already registered):
1. Open Antigravity Agent Manager (UI button)
2. Click "Add Agent" or "+"
3. Browse to `/Users/icmini/02luka/agents/gmx/PERSONA_PROMPT.md`
4. Set execution policy to "Ask" (no auto-run)
5. Save
