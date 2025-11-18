# Gemini Routing Decision Guide

## 1.0 Purpose

This guide outlines the rules and heuristics for routing development tasks between CLC and Gemini within the 02luka ecosystem. The primary goal is to optimize for efficiency, preserve CLC's context for high-value tasks, and leverage Gemini for parallelizable or less context-sensitive work.

## 2.0 CLC Quota Guard (60% Rule)

When deciding whether to IMPLEMENT a task directly or ROUTE it to Gemini, CLC MUST check its weekly usage first.

- Source of truth: `/usage` command for Claude/CLC

### 2.1 Soft Guardrail – 60%+

IF weekly usage (any Claude Pro / Sonnet / Code tier) is ≥ 60% THEN:

- For NON-LOCKED zones (e.g. `apps/**`, `server/**`, `tools/**`, `tests/**`, non-governance `g/docs/**`):

  - CLC MUST NOT implement the task directly.
  - CLC MUST route via Gemini work order instead.
  - CLC MAY:
    - refine the WO description,
    - write specs/PRPs for Gemini to follow,
    - review the result.

- For LOCKED / GOVERNANCE zones (e.g. `/core/governance/**`, `/CLC/**`, protocol docs):

  - CLC MAY still implement directly, but:
    - SHOULD keep changes small and surgical (SIP patches),
    - MUST log rationale in the relevant report / MLS entry.

### 2.2 Hard Guardrail – 80%+

IF weekly usage is > 80% THEN:

- CLC SHOULD ONLY take:
  - emergency locked-zone fixes,
  - protocol / security surgery tasks.
- All other work MUST be routed to Gemini or deferred.

### 2.3 Required Response Pattern

When CLC is above 60% and the task is non-locked, CLC MUST say something like:

> “My weekly usage is above 60%. This is a non-locked task, so I must route it to Gemini via work order instead of implementing it myself.”

Then:

1. Propose or fill a work order (using the routing helper / templates).
2. Ask Boss to run `tools/route_to_gemini.zsh` or confirm automatic routing.
3. Optionally review Gemini’s result when it returns.

## 3.0 Routing Rules

### Rule 0 – Quota Guard
If CLC weekly usage ≥ 60%:
→ FORCE route to Gemini or Gemini-CLI for ALL non-locked tasks.
→ CLC may only handle locked/governance.

### Rule 1 – Task Type: Docs / Security / Multi-File
- **WHEN**: Task involves documentation creation/updates, security analysis, or spans multiple functionally distinct areas.
- **WHAT**: Route to Gemini.
- **WHY**: These tasks are often self-contained and benefit from parallel execution, minimizing CLC's context-switching overhead.
- **EXCEPTION**: Does not apply to core governance or protocol documents in locked zones.

### Rule 2 – Complexity & File Count (3+ Files)
- **WHEN**: Task is described as "complex" and requires editing 3 or more files.
- **WHAT**: Route to Gemini.
- **WHY**: High file count often indicates boilerplate work or refactoring that doesn't require deep, centralized context. Gemini can process these changes in parallel more efficiently.
- **EXCEPTION**: If the files are tightly coupled within a locked zone, CLC should handle it.

### Rule 3 – Priority & Output Size
- **WHEN**: Task is low-priority (P2/P3) and is expected to generate a large amount of code or output.
- **WHAT**: Route to Gemini.
- **WHY**: Conserves CLC's limited token budget for high-priority, interactive tasks. Gemini is better suited for generating large, non-critical blocks of code.
- **NOTE**: Boss makes the final priority judgment.

### Rule 4 – Token Efficiency
- **WHEN**: A task is estimated to require a large number of tokens (>5K) and is not time-sensitive.
- **WHAT**: Route to Gemini.
- **WHY**: This is a direct cost-saving measure. It prevents a single large task from consuming a significant portion of CLC's token allocation.
- **NOTE**: This rule is a guideline; Boss can override for urgent tasks.

### Rule 5 – Default Fallback to CLC
- **WHEN**: A task does not meet any of the criteria in Rules 1-4.
- **WHAT**: Route to CLC.
- **WHY**: CLC is the default agent for tasks requiring deep repository context, complex reasoning, or interactive refinement. This includes bug fixes, single-file features, and critical (P0/P1) tasks.
- **NOTE**: This rule assumes the Quota Guard (Rule 0) is not active.

## 4.0 Examples

(Optional section for task routing examples.)

## 5.0 Notes

(Optional section for additional notes and context.)
