# GMX Design Summary: Agent Memory System v0.2

**Objective:** To design a memory system that an AI agent will **actually use** and not ignore, solving the "TL;DR" problem where context becomes "rubbish info."

---

### 1. The Problem: Passive Memory Failure

Standard AI memory systems fail because they are passive. An agent is given context (e.g., "Boss prefers brief responses") but is not programmatically forced to use it. The stateless nature of LLMs means this context is often ignored in favor of the immediate prompt, leading to repeated mistakes.

---

### 2. The Solution: "Proof of Use" via a Forced Validation Contract

This design makes memory an active, non-skippable part of the agent's core reasoning loop.

**The principle is simple: The agent must prove it has used its memory *before* it is allowed to act.**

---

### 3. Key Components of the Design

#### **A. Lightweight Data Flow**

*   **Ledger (`g/memory/ledger/liam_memory.jsonl`):** A simple JSONL file remains the single source of truth. Each entry contains a single, concise `learning` string.
*   **Loader (`g/tools/atg_memory_load.py`):** Reads the last N learnings from the ledger and returns them as a simple list in JSON format (e.g., `{"recent_learnings": ["learning 1", "learning 2"]}`).
*   **Saver (`g/tools/atg_memory_save.py`):** Appends a new, single-sentence learning to the ledger based on the outcome of a task.

#### **B. The "Forced Validation" Persona Contract**

This is the most critical component. The agent's persona prompt (`PERSONA_PROMPT.md`) is updated with a mandatory, non-bypassable protocol.

**The New Internal Process:**

1.  **Load:** At the start of a session, the agent loads the `recent_learnings` list.
2.  **Plan Action:** The agent formulates a plan (e.g., "call `write_file` tool with this content...").
3.  **Generate "Proof of Use" (Pre-Action Validation):** Before executing the plan, the agent **MUST** generate an internal JSON monologue that validates its planned action against **every learning** from memory.

    **Internal Monologue Example:**
    ```json
    {
      "planned_action": {
        "tool": "write_file",
        "file_path": "g/tools/new_tool.py"
      },
      "validation_checklist": [
        {
          "learning": "Boss wants a spec/plan before implementation.",
          "is_compliant": false,
          "reasoning": "My planned action is to create a file directly, which violates the 'plan first' directive."
        }
      ],
      "final_decision": "REVISE. I must create a plan first."
    }
    ```
4.  **Self-Correct:** If any check results in `is_compliant: false`, the agent **MUST STOP** and formulate a new plan. It repeats the validation until all checks pass and `final_decision` is "Proceed".
5.  **Execute:** Only after successful validation can the agent execute its planned action.

---

### 4. Why This Design is Useful and Avoids "TL;DR"

*   **Forces Engagement:** The agent cannot passively scan its memory; it must actively iterate through each learning and justify its compliance.
*   **Creates Auditable Reasoning:** If the agent makes a mistake, its internal "Proof of Use" monologue can be reviewed to pinpoint the exact failure in its validation logic.
*   **Enables Self-Correction:** It builds a reliable, programmatic feedback loop where past failures directly and immediately prevent future identical mistakes.

This design ensures memory is not just context to be potentially ignored, but a set of hard constraints that actively shape the agent's behavior, making it truly useful in reality.
