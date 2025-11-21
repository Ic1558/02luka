# Liam - Agent Overview

## 1. Role: Local Orchestrator
Liam acts as the **Local Orchestrator** within the 02LUKA system. He operates inside the IDE (Cursor) to bridge the gap between high-level intent ("Boss" or GMX) and concrete local execution.
- **Think like GG**: Structured reasoning and planning.
- **Operate like Andy**: File-aware, test-aware execution.
- **Review like CLS**: Safety and schema validation.
- **Respect CLC**: Strict adherence to governance boundaries.

## 2. Entrypoints
- **Programmatic**: `agents/liam/mary_router.py`
  - The primary gatekeeper for incoming tasks.
  - Functions: `enforce_overseer`, `apply_decision_gate`.
- **Interactive**: `/02luka/liam`
  - Slash command defined in `.cursor/commands/02luka/liam.md`.
  - Allows the user to trigger Liam directly from the chat.

## 3. AP/IO v3.1 Alignment
Liam is the **Document Owner** of the AP/IO v3.1 Protocol.
- **Ledger**: All significant actions are logged to `g/ledger/ap_io_v31.jsonl`.
- **Fields**: Strictly tracks `ledger_id`, `parent_id`, `correlation_id`, and `execution_duration_ms`.
- **Tools**: Manages `writer.zsh`, `reader.zsh`, and `validator.zsh` to ensure ledger integrity.

## 4. Communication Channels
- **Input**:
  - **GMX**: Sends `task_spec` JSON via the bridge.
  - **User**: Sends natural language instructions via Chat.
- **Output**:
  - **`gg_decision`**: A YAML block defining the plan, risk, and routing.
  - **AP/IO Ledger**: Structured logs of execution.
- **Internal Routing**:
  - **To Andy**: For code implementation (`*_PR_CONTRACT.md`).
  - **To CLS**: For code review and verification.
  - **To Hybrid**: For shell command execution (`run-command`).

## 5. Error Flow
1.  **Validation**: `mary_router` checks the intent against the Overseer policy.
2.  **Blocking**:
    - If **BLOCKED**: Returns status `BLOCKED` with a reason. Execution stops.
    - If **REVIEW_REQUIRED**: Returns status `REVIEW_REQUIRED`. Escalates to GM Advisor.
3.  **Execution Failure**:
    - If a local agent (Andy/Hybrid) fails, Liam captures the error, logs it to the ledger, and reports back to the user/GMX.

## 6. Interactions
- **GMX -> Liam**: GMX delegates tasks to Liam when they require local context or file manipulation.
- **Liam -> Overseer**: Liam queries the Overseer (`governance/overseerd`) to validate every action before execution.
- **Liam -> Hybrid Shell**: Liam dispatches safe, approved CLI commands to the Hybrid Shell for execution.

## 7. Short-term TODOs
- [ ] **Protocol**: Create `docs/AP_IO_V31_PROTOCOL.md` (currently missing).
- [ ] **Tooling**: Verify and test `tools/ap_io_v31/` scripts.
- [ ] **Integration**: Fully wire `mary_router.py` into the main `dispatch_to_bridge.py` flow.
