# Opal: Architect + Senior Nodes (Step 1)

## Objective
Stand up two thinking nodes on Opal so hard tasks are planned and stress-tested before any Worker runs code. This addresses the requested priority order (B → A → C) by making the system think-first and reduce failure loops.

## Scope
- **Architect Node (GG/GC lane)**: Expands an objective into an executable, lane-aware work plan.
- **Senior Node (GC lane)**: Reviews and hardens the Architect plan to ensure it is runnable on 02luka with minimal rework.
- **Placement**: Both nodes live on Opal and plug into the existing Gateway → Work Order → Worker → QA → Notify path.

## High-Level Flow
1. **Gateway Intake**
   - Input: `objective`, optional `context`, `priority` (default normal), `lane_hint` (free LAC / paid API / hybrid GUI).
   - Gateway adds metadata: `task_id`, timestamps, requester, repo branch.
2. **Architect Node**
   - Consumes intake payload.
   - Produces: structured plan with steps, lane choice, risk/complexity, file touch list, and validation checklist.
3. **Senior Node**
   - Reads Architect output.
   - Produces: plan deltas (fixes), block/allow decision, clarified acceptance criteria, and worker-ready action list.
4. **Work Order Generation**
   - Gateway merges Senior-approved plan into Work Order for Worker LAC.
   - QA LAC later validates against the acceptance criteria and checklist.

## Message Contracts
Use JSON envelopes so Opal UI and downstream Redis channels stay consistent.

### Architect Node Input
```json
{
  "task_id": "uuid",
  "objective": "<what needs to be done>",
  "context": "<links, files, constraints>",
  "priority": "P1|P2|P3",
  "lane_hint": "free-lac|paid-api|hybrid-gui|auto",
  "repo": "02luka",
  "branch": "work"
}
```

### Architect Node Output
```json
{
  "task_id": "uuid",
  "lane": "free-lac|paid-api|hybrid-gui",
  "estimation": {
    "complexity": "S|M|L",
    "risk": ["<risk1>", "<risk2>"],
    "time_minutes": 20
  },
  "plan": [
    {"step": 1, "title": "", "action": "", "owner": "worker", "evidence": "file|log|screenshot"}
  ],
  "files_to_touch": ["path/one", "path/two"],
  "checklist": ["unit tests", "lint", "manual sanity"],
  "handoff_notes": "<clarifications for Senior + Worker>",
  "blockers": []
}
```

### Senior Node Input
Architect output plus `objective` (for verification):
```json
{
  "task_id": "uuid",
  "objective": "...",
  "architect_plan": { /* architect output */ }
}
```

### Senior Node Output
```json
{
  "task_id": "uuid",
  "decision": "go|revise",
  "fixes": ["tighten file list", "add tests"],
  "final_lane": "free-lac|paid-api|hybrid-gui",
  "worker_steps": [
    {"step": 1, "do": "", "evidence": "file|log|screenshot", "owner": "worker"}
  ],
  "acceptance_criteria": ["<observable outcomes>", "<test commands>", "<UI checks>"]
}
```

## Prompt Skeletons (Opal)

### Architect Node Prompt (system role)
```
You are the Architect Node on Opal for the 02luka repo. Your job is to transform an objective into an executable plan.
- Always pick the best lane: free LAC, paid API, or hybrid GUI; default to free LAC unless latency or UI is critical.
- Output MUST be valid JSON per the Architect Output schema.
- Keep steps small, sequential, and evidence-driven (file paths, commands, screenshots).
- Flag blockers early (missing context, permissions, external API needs).
- Keep file touch list conservative and repo-scoped.
```

### Senior Node Prompt (system role)
```
You are the Senior Reviewer Node on Opal. Stress-test the Architect plan for 02luka.
- Reject or fix any step that is not runnable on the work branch.
- Trim scope creep and enforce evidence for every step.
- Tighten acceptance criteria: observable outcomes + concrete commands + UI checks when relevant.
- If information is missing, mark decision = "revise" and request specifics.
- Emit JSON per the Senior Output schema only.
```

## Wiring on Opal
- **Channels**: Use existing `gg:chat:incoming` → `gg:chat:response:<task_id>` for visibility; add derived streams `opal:architect:plan` and `opal:senior:review` for UI cards.
- **UI surfacing**: In `/v4-pipeline`, render two stacked cards:
  1. Architect card shows lane, complexity, risk, plan steps.
  2. Senior card shows decision, fixes, final worker steps, acceptance criteria.
- **Persistence**: Store latest payloads at `g/telemetry/opal/architect_<task_id>.json` and `g/telemetry/opal/senior_<task_id>.json` for audits.

## Operational Notes
- Keep SLA: Architect ≤ 60 seconds, Senior ≤ 45 seconds.
- If paid API is chosen, annotate cost-sensitive calls.
- QA LAC consumes `acceptance_criteria` directly; Worker follows `worker_steps`.

## Next Actions (to implement)
1. Add the above prompts into Opal node configurations.
2. Update Gateway to route intake → Architect → Senior before emitting Work Orders.
3. Extend Opal UI pipeline view with the two cards and JSON storage hooks.
