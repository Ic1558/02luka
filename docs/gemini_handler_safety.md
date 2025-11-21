# Gemini Handler Safety Review Workflow

This document explains the end-to-end safety review workflow for Gemini work orders in the 02luka system, from work order ingestion through Overseer policy enforcement to final execution.

## Table of Contents

1. [High-Level Overview](#high-level-overview)
2. [Step-by-Step Work Order Journey](#step-by-step-work-order-journey)
3. [GM Policy Configuration](#gm-policy-configuration)

---

## High-Level Overview

The Gemini handler implements a **multi-layer safety system** that ensures all work orders are reviewed before execution. The system consists of three main components:

1. **Gemini Handler** (`bridge/handlers/gemini_handler.py`) - File I/O and work order management
2. **Mary Router** (`agents/liam/mary_router.py`) - Safety enforcement entry point
3. **Overseer** (`governance/overseerd.py`) - Policy-based decision engine

### Safety Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                    GEMINI Work Order Flow                        │
└─────────────────────────────────────────────────────────────────┘

1. INBOX
   │
   │ YAML file: bridge/inbox/GEMINI/wo_123.yaml
   │
   ▼
2. GEMINI HANDLER (gemini_handler.py)
   │
   │ • Reads YAML work order
   │ • Extracts: task_type, input, command
   │
   ▼
3. GEMINI LOGIC (gemini_logic.py)
   │
   │ • Normalizes payload
   │ • Builds task_spec (intent, target_files, command)
   │
   ▼
4. MARY ROUTER (mary_router.py)
   │
   │ • enforce_overseer(task_spec, payload)
   │ • Routes to appropriate Overseer function
   │
   ▼
5. OVERSEER (overseerd.py)
   │
   │ ┌─────────────────────────────────────┐
   │ │ Step A: Safe Zones Check            │
   │ │ • Validates file paths              │
   │ │ • Blocks writes outside /02luka     │
   │ └─────────────────────────────────────┘
   │
   │ ┌─────────────────────────────────────┐
   │ │ Step B: GM Policy Check             │
   │ │ • Analyzes files, keywords, commands│
   │ │ • Uses gm_policy_v4.yaml rules      │
   │ └─────────────────────────────────────┘
   │
   │ Returns decision: {approval, reason, trigger_details}
   │
   ▼
6. DECISION GATE (mary_router.py)
   │
   │ • apply_decision_gate(decision)
   │
   │ ┌──────────┬──────────┬──────────┐
   │ │ APPROVED │ REVIEW   │ BLOCKED  │
   │ │          │ REQUIRED  │          │
   │ └────┬─────┴────┬──────┴────┬─────┘
   │      │          │           │
   │      │          │           └─► Write error result
   │      │          │               Status: BLOCKED
   │      │          │
   │      │          └─► Write error result
   │      │              Status: REVIEW_REQUIRED
   │      │              Escalate to GM advisor
   │      │
   │      └─► Proceed to Gemini execution
   │
   ▼
7. GEMINI CONNECTOR
   │
   │ • Executes approved task
   │ • Returns result
   │
   ▼
8. OUTBOX
   │
   │ YAML file: bridge/outbox/GEMINI/wo_123_result.yaml
   │ • status: success | failed
   │ • result: {...} | error: "..."
   │
   └─► END
```

### Decision Outcomes

The system produces three possible outcomes:

- **APPROVED** (`approval: "Yes"`) - Task passes all safety checks, execution proceeds
- **REVIEW_REQUIRED** (`approval: "Review"`) - Task matches GM trigger policy, requires advisor review before execution
- **BLOCKED** (`approval: "No"`) - Task violates hard safety rules (e.g., writes outside allowed zones), execution prevented

---

## Step-by-Step Work Order Journey

### Step 1: Work Order Ingestion

A work order arrives as a YAML file in `bridge/inbox/GEMINI/`:

```yaml
wo_id: wo_123
task_type: refactor
input:
  instructions: "Update the Redis dispatcher logic"
  target_files:
    - "02luka/core/gg_orchestrator.py"
  context:
    description: "Refactor Redis connection handling"
```

**Handler Action:** `GeminiHandler.process_work_order()` reads the YAML file and extracts the work order data.

### Step 2: Payload Normalization

**Location:** `bridge/handlers/gemini_logic.py::_normalize_payload()`

The handler extracts and normalizes the payload:

```python
payload = {
    "instructions": "Update the Redis dispatcher logic",
    "target_files": ["02luka/core/gg_orchestrator.py"],
    "context": {"description": "Refactor Redis connection handling"},
    "command": ""  # Empty for patch operations
}
```

### Step 3: Task Specification Building

**Location:** `bridge/handlers/gemini_logic.py::_build_task_spec()`

The system converts the work order format to a standardized `task_spec` format:

```python
task_spec = {
    "intent": "refactor",  # Mapped from task_type
    "target_files": ["02luka/core/gg_orchestrator.py"],
    "command": None,
    "context": {"description": "Refactor Redis connection handling"}
}
```

**Intent Mapping:**
- `code_transform` → `refactor`
- `refactor` → `refactor`
- `fix-bug` → `fix-bug`
- `add-feature` → `add-feature`
- `generate-file` → `generate-file`
- `run-command` → `run-command`

### Step 4: Mary Router Entry Point

**Location:** `agents/liam/mary_router.py::enforce_overseer()`

The Mary Router receives the `task_spec` and routes it to the appropriate Overseer function based on intent:

- **Patch intents** (`refactor`, `fix-bug`, `add-feature`, `generate-file`) → `decide_for_patch()`
- **Shell intent** (`run-command`) → `decide_for_shell()`
- **Unknown intents** → Default to `Review` for safety

### Step 5: Overseer Safety Checks

**Location:** `governance/overseerd.py`

The Overseer performs two sequential checks:

#### 5A: Safe Zones Validation

**Function:** `decide_for_patch()::_is_path_allowed()`

Before any policy analysis, the Overseer validates that all target files are within allowed write zones:

- **Allowed zones:** Defined in `context/safety/safe_zones.yaml`
  - Default: `/Users/icmini/02luka` and subdirectories
- **Denied zones:** System paths like `/`, `/System`, `/usr`, `/bin`, etc.

**Decision Logic:**
- If any file is outside allowed zones → **BLOCKED** (`approval: "No"`)
- If all files are in allowed zones → Continue to policy check

**Example:**
```python
# File: /etc/hosts (outside allowed zone)
# Result: BLOCKED - "File /etc/hosts is outside allowed write zones."
```

#### 5B: GM Policy Analysis

**Function:** `decide_for_patch()::_POLICY.should_trigger_for_patch()`

The Overseer uses `PolicyLoader` to analyze the task against `gm_policy_v4.yaml` rules:

1. **Multi-file threshold** - Triggers if `len(files) >= files_changed_threshold` (default: 2)
2. **Sensitive paths** - Triggers if any file path contains a sensitive path pattern
3. **File extensions** - Triggers if any file has a critical extension (`.py`, `.yaml`, `.sh`, etc.)
4. **Critical keywords** - Triggers if diff text contains critical keywords (`redis`, `dispatcher`, `overseer`, etc.)

**Decision Logic:**
- If **any** rule matches → **REVIEW_REQUIRED** (`approval: "Review"`)
- If **no** rules match → **APPROVED** (`approval: "Yes"`)

**Example:**
```python
# Files: ["02luka/core/gg_orchestrator.py"]
# Diff: "update redis dispatcher logic"
# Matches: sensitive_path ("02luka/core/"), extension (".py"), keyword ("redis")
# Result: REVIEW_REQUIRED - "GM trigger policy matched; require advisor / manual review."
```

### Step 6: Decision Gate Processing

**Location:** `agents/liam/mary_router.py::apply_decision_gate()`

The decision gate converts Overseer decisions into actionable status codes:

| Overseer Decision | Gate Status | Action |
|-------------------|-------------|--------|
| `approval: "Yes"` | `APPROVED` | Proceed to Gemini execution |
| `approval: "Review"` | `REVIEW_REQUIRED` | Block execution, escalate to GM advisor |
| `approval: "No"` | `BLOCKED` | Block execution, write error result |

**Gate Response Format:**
```python
{
    "status": "APPROVED" | "REVIEW_REQUIRED" | "BLOCKED",
    "reason": "Human-readable explanation",
    "details": ["trigger_detail_1", "trigger_detail_2"],
    "confidence_score": 0.0-1.0
}
```

### Step 7: Error Handling (If Blocked/Review Required)

**Location:** `bridge/handlers/gemini_logic.py::_apply_decision_gate()`

If the gate returns `BLOCKED` or `REVIEW_REQUIRED`, the system:

1. Returns an error response with status and reason
2. **Does not** proceed to Gemini execution
3. Returns control to the handler

**Error Response Format:**
```python
{
    "ok": False,
    "engine": "overseer",
    "status": "BLOCKED" | "REVIEW_REQUIRED",
    "error": "Detailed error message",
    "details": ["trigger_detail_1", "trigger_detail_2"],
    "escalate_to": "gm-advisor"  # Only for REVIEW_REQUIRED
}
```

### Step 8: Gemini Execution (If Approved)

**Location:** `bridge/handlers/gemini_logic.py::_execute_gemini_task()`

If the decision gate returns `APPROVED`, the system:

1. Logs approval: `"Overseer approved task_type=refactor, proceeding to Gemini"`
2. Calls `gemini_connector.run_gemini_task(task_type, payload)`
3. Returns success response

**Success Response Format:**
```python
{
    "ok": True,
    "engine": "gemini",
    "task_type": "refactor",
    "result": {...}  # Gemini execution result
}
```

### Step 9: Result Persistence

**Location:** `bridge/handlers/gemini_handler.py::_write_success_result()` / `_write_error_result()`

The handler writes the final result to `bridge/outbox/GEMINI/wo_123_result.yaml`:

**Success Result:**
```yaml
wo_id: wo_123
status: success
engine: gemini
task_type: refactor
completed_at: "2025-01-15T10:30:00Z"
result:
  # Gemini execution result
```

**Error Result:**
```yaml
wo_id: wo_123
status: failed
completed_at: "2025-01-15T10:30:00Z"
error: "REVIEW_REQUIRED: GM trigger policy matched; require advisor / manual review."
```

**Error Message Construction:**
The handler extracts error messages with priority:
1. `response.get("error")` - Primary error field
2. `response.get("reason")` - Fallback reason field
3. `"Processing failed: no reason provided"` - Default message

Final error format: `"{status}: {detailed_error}"`

---

## GM Policy Configuration

The GM trigger policy is defined in `context/safety/gm_policy_v4.yaml`. This file controls when a work order requires review by a GM/GPT advisor before execution.

### Policy Structure

```yaml
version: "gmx-v1"

gm_trigger_policy:
  files_changed_threshold: 2
  sensitive_paths:
    - "02luka/core/"
    - "02luka/bridge/"
    - "02luka/agents/"
    - "02luka/context/"
    - "02luka/tools/"
  file_extensions:
    - ".yaml"
    - ".yml"
    - ".json"
    - ".py"
    - ".sh"
    - ".zsh"
    - ".plist"
    - ".toml"
    - "Makefile"
  critical_keywords:
    - "redis"
    - "dispatcher"
    - "overseer"
    - "hybrid"
    - "playwright"
    - "routing"
    - "memory"
    - "context loader"
  shell_keywords:
    - "docker"
    - "kubectl"
    - "helm"
    - "launchctl"
    - "systemctl"
    - "brew install"
    - "brew uninstall"
    - "git clean"
    - "find -delete"
    - "rm -rf"
```

### Policy Rules Explained

#### 1. Files Changed Threshold

**Rule:** `files_changed_threshold: 2`

**Behavior:** Triggers review if the work order modifies 2 or more files simultaneously.

**Rationale:** Multi-file changes are more complex and have higher risk of unintended side effects.

**Example:**
- 1 file changed → No trigger
- 2+ files changed → **REVIEW_REQUIRED**

#### 2. Sensitive Paths

**Rule:** List of path patterns that indicate critical system components.

**Behavior:** Triggers review if any target file path contains a sensitive path pattern.

**Rationale:** Changes to core infrastructure (orchestrators, bridges, agents) require extra scrutiny.

**Example:**
- File: `02luka/core/gg_orchestrator.py` → Matches `"02luka/core/"` → **REVIEW_REQUIRED**
- File: `02luka/docs/guide.md` → No match → No trigger

#### 3. File Extensions

**Rule:** List of file extensions that indicate executable or configuration files.

**Behavior:** Triggers review if any target file has a critical extension.

**Rationale:** Code and configuration files can have system-wide impact if modified incorrectly.

**Example:**
- File: `tools/helper.py` → Matches `.py` → **REVIEW_REQUIRED**
- File: `docs/readme.md` → No match → No trigger

#### 4. Critical Keywords

**Rule:** List of keywords that indicate high-risk operations.

**Behavior:** Triggers review if the diff text (instructions) contains any critical keyword.

**Rationale:** Certain operations (Redis, dispatcher, routing) affect system behavior and require review.

**Example:**
- Instructions: `"Update Redis connection handling"` → Matches `"redis"` → **REVIEW_REQUIRED**
- Instructions: `"Add user comments"` → No match → No trigger

#### 5. Shell Keywords

**Rule:** List of shell command keywords that indicate system-level operations.

**Behavior:** Triggers review if the shell command contains any shell keyword.

**Rationale:** System commands (Docker, Kubernetes, package managers) can affect the entire environment.

**Example:**
- Command: `docker volume rm my_volume` → Matches `"docker"` → **REVIEW_REQUIRED**
- Command: `ls -la` → No match → No trigger

### Policy Evaluation Logic

The Overseer evaluates all rules **in parallel** (not sequentially). If **any** rule matches, the task is marked for review:

```
Rule 1 (multi-file)     → Match? ──┐
Rule 2 (sensitive path) → Match? ──┤
Rule 3 (extension)      → Match? ──┼─► ANY match → REVIEW_REQUIRED
Rule 4 (keyword)        → Match? ──┤
Rule 5 (shell keyword)  → Match? ──┘
                                    │
                                    └─► NO matches → APPROVED
```

### Policy Versioning

The policy file includes a `version` field (`"gmx-v1"`). The `PolicyLoader` validates this version:

- **Version matches:** Policy is applied normally
- **Version mismatch:** Policy is treated as unavailable, forcing `Review` for all tasks (fail-safe)

### Safe Zones vs. GM Policy

**Safe Zones** (`context/safety/safe_zones.yaml`):
- **Purpose:** Hard security boundary
- **Action:** **BLOCKS** execution if violated
- **Scope:** File path validation only
- **Example:** Prevents writes to `/etc/`, `/System/`, etc.

**GM Policy** (`context/safety/gm_policy_v4.yaml`):
- **Purpose:** Risk assessment for review
- **Action:** **REQUIRES REVIEW** if triggered (does not block)
- **Scope:** File analysis, keyword matching, command analysis
- **Example:** Flags changes to `core/` or `redis` keywords for advisor review

**Order of Evaluation:**
1. Safe Zones check → **BLOCKED** if violated (stops here)
2. GM Policy check → **REVIEW_REQUIRED** if triggered
3. If both pass → **APPROVED**

---

## Summary

The Gemini handler safety workflow ensures that:

1. **All work orders are validated** before execution
2. **File path safety** is enforced via Safe Zones (hard block)
3. **Risk assessment** is performed via GM Policy (review flag)
4. **Clear error messages** are provided for blocked/review-required tasks
5. **Audit trail** is maintained via result files in the outbox

The system is designed to be **fail-safe**: if policy files are unavailable or versions mismatch, tasks default to `Review` status rather than being automatically approved.
