# CLC GMX Orchestrator Specification v1

**WO-ID:** `WO-CLC-GMX-ORCH-SPEC-V1`  
**Title:** Design & implement GMX-based CLC Orchestrator loop  
**Owner:** CLC  
**Status:** Implemented (v1 Skeleton)

## 1. Overview

This document specifies the architecture for a "GMX-based CLC Orchestrator". The goal is to evolve the CLC (Code & Logic Companion) from a passive executor into a proactive agent capable of self-initiating tasks, mirroring the behavior of a "Claude Desktop sidecar".

This is achieved by introducing a role split:
- **GMX (Gemini CLI):** The **Planner/Brain**. It receives system context, reasons about it, and produces structured Work Orders (WOs). All complex reasoning, planning, and chain-of-thought processes are centralized here.
- **CLC Worker:** The **Executor/Hands**. It operates deterministically, executing the `ops` within a WO safely and idempotently without performing its own complex reasoning.

The orchestrator is implemented as a periodic, `launchd`-driven script that creates a "sense-plan-act" loop, enabling the system to self-initiate work without direct, per-task user commands.

## 2. Data Flow

The core orchestration loop follows this data flow:

1.  **Sense:** The `gmx_clc_orchestrator.zsh` script, running every 5 minutes, gathers context from multiple sources:
    - `g/telemetry/health_check_latest.json` (System health report)
    - `bridge/outbox/LIAM/*.ack.json` (Recent CLC Worker results)
    - `state/clc_sessions/*.yaml` (State of long-running tasks)

2.  **Plan:** The collected context is formatted into a prompt and sent to the **GMX (Gemini CLI)** `run` command using a dedicated `clc-orchestrator` profile. GMX analyzes the context and outputs a plan in a structured YAML format, containing a list of proposed work orders.

3.  **Act:** The orchestrator script validates the YAML output from GMX. If valid WOs are present, it converts them into individual WO files and places them in the `bridge/inbox/CLC/` directory using an atomic drop pattern.

4.  **Execute:** The existing **CLC Worker** pipeline picks up the new WOs from the inbox and executes them. The results are written as ACK files to the outbox, feeding back into the next "Sense" cycle.

![Data Flow Diagram](https://dummyimage.com/800x250/2d2d2d/ffffff.png&text=health/acks/state+->+Orchestrator+->+GMX+->+YAML+Plan+->+WO+->+CLC+Worker)

## 3. Directory Layout

The following directories form the foundation of the orchestrator's memory and state management:

-   **`g/knowledge/clc/`**: The long-term memory zone for CLC.
    -   `README.md`: Explains the contents of this directory.
    -   `event_log.jsonl` (Planned): A detailed, append-only log of all CLC actions.
    -   `topic_memory.yaml` (Planned): A high-level, semantic summary of learnings.

-   **`state/clc_sessions/`**: Stores the state of active, long-running tasks.
    -   `SESSION-ID.yaml`: A file for each session, tracking its goal, related WOs, and current status.

## 4. Work Order Schema Extension

The GMX Orchestrator will generate WOs that adhere to the existing schema but make full use of metadata to provide execution context.

### Example Orchestrator-Generated WO YAML:

```yaml
work_orders:
  - wo_id: "WO-CLC-AUTO-20251127-001"
    objective: "Refactor OPAL health tool into library + CLI"
    route:
      primary_agent: CLC
      collaborators: [GMX, GG]
    context:
      root: /Users/icmini/02luka
      project: opal_v4
      allowed_zones:
        - g/tools
        - g/apps
      forbidden_zones:
        - CLC/
        - CLS/
    ops:
      - op: write_file
        path: g/tools/lib_opal_health.sh
        # ... content ...
      - op: run_tests
        command: "zsh tests/run_opal_tests.zsh"
```

The `context` block is critical for the CLC Worker to validate operations before execution, ensuring it does not violate defined zone boundaries.

## 5. Security & Governance

This system operates under the existing `AI:OP-001` Governance framework.
- **Safe Zones:** The orchestrator and CLC Worker are restricted to writing only within designated safe zones (e.g., `g/tools`, `g/docs`, `bridge/`, `logs/`, `state/`).
- **Forbidden Zones:** Direct modification of core agent definitions in `CLC/` and `CLS/` is strictly prohibited.
- **Idempotency:** All generated scripts and file operations (`ops`) should strive to be idempotent.
- **Atomic Operations:** WOs are delivered to the inbox using an atomic `mv` operation to prevent partial reads by the CLC Worker.

## 6. Implementation Status (v1 - Skeleton)

The initial version of the GMX CLC Orchestrator implements the foundational structure but is **not yet functionally complete**. It is a "skeleton" designed to establish the necessary files, directories, and configurations.

**Key limitations of the current implementation:**
- **No GMX Integration:** The `gmx_clc_orchestrator.zsh` script **does not** actually call the `gmx` CLI. It uses a simulated response that always returns an empty list of work orders.
- **No Context Processing:** The script does not yet parse the contents of health checks, ACK files, or session states.
- **No WO Generation:** The logic to validate GMX output and create WO files in the inbox is currently a `TODO` placeholder.

The primary purpose of this version is to ensure the `launchd` agent can execute the script correctly and that logging is functional.

## 7. Verification Plan (v1 - Skeleton)

This plan verifies the health of the non-functional skeleton.

### Manual Verification Steps:
1.  **Load the Launch Agent:**
    ```bash
    cp LaunchAgents/com.02luka.gmx-clc-orchestrator.plist ~/Library/LaunchAgents/
    launchctl load ~/Library/LaunchAgents/com.02luka.gmx-clc-orchestrator.plist
    ```
2.  **Confirm Agent is Loaded:**
    ```bash
    launchctl list | grep gmx-clc-orchestrator
    ```
    - **Expected:** The command should return a line corresponding to the loaded agent.

3.  **Trigger the Script Manually:**
    ```bash
    ./g/tools/gmx_clc_orchestrator.zsh
    ```
    - **Expected:** The script should run without errors and exit with code 0.

4.  **Inspect the Log File:**
    - Wait for the `StartInterval` (5 minutes) or use the manual trigger from step 3.
    - Check the contents of the log file:
    ```bash
    tail -n 10 logs/gmx_clc_orchestrator.log
    ```
    - **Expected:** The log should show a clean run, including the "Orchestrator loop started", "Context gathered", "GMX planner returned (simulated) output", "Plan is empty. No new Work Orders to create", and "Orchestrator loop finished" messages.

5.  **Verify No Work Orders Created:**
    - Check the CLC inbox directory:
    ```bash
    ls -l bridge/inbox/CLC/
    ```
    - **Expected:** The directory should be empty. No new WO files should have been created.

## 8. Implementation Artifacts

- **Orchestrator Script:** `g/tools/gmx_clc_orchestrator.zsh`
- **LaunchAgent:** `LaunchAgents/com.02luka.gmx-clc-orchestrator.plist`
- **Session State Example:** `state/clc_sessions/SESSION-DEMO-001.yaml`
- **Memory Zone Definition:** `g/knowledge/clc/README.md`
