# R&D Layer Integration (v1.0)

This blueprint installs the missing fifth layer (R&D) across the 02luka pipeline so the system improves after every Work Order (WO).

## 5-Layer Team Structure
1. Architect – plan and design reasoning lanes.
2. Senior Architect – validate/adjust the plan.
3. Developer (LAC Worker) – execute the WO.
4. QA (CLS) – audit outputs.
5. R&D – analyze outcomes, capture lessons, and propose improvements.

## Opal Workflow Hook (Option A)
- Insert an **R&D node after CLS/QA** in the Opal workflow.
- Inputs: WO summary, QA verdict, reasoning-depth signal, escalation flags.
- Outputs: lesson+rule files under `g/memory/` and auto-opened improvement tickets for risky WOs.
- Deploy by adding the node to Opal flows that currently end at QA; set it to call `tools/rnd_memory_refresh.py` after writing memory files.

## CLS Lane Background Analytics (Option B)
- Extend CLS to emit a background record after each WO: `{wo_id, status, reasoning_depth, escalation?, key_patterns}`.
- R&D consumes these analytics to flag low-depth reasoning or repeated failure patterns even when WO passes.
- Store synthesized findings in `g/memory/lessons/` and rules in `g/memory/rules/` to keep the feedback loop alive between runs.

## Combined Path (Option C)
- Use **both** the Opal node and CLS background analytics to ensure every WO produces R&D data.
- When a WO fails or hits "basic" reasoning, **open an improvement ticket** in `g/memory/improvement_tickets/` and notify Architect + Senior.
- Run `tools/rnd_memory_refresh.py` after each batch to refresh `latest_lessons.json` and `latest_rules.json` for planning nodes.

## Full R&D v1.0 Scope (Option D)
- Governance: send a digest of R&D proposals/risks to Mary (COO) and GG after each cycle.
- Memory: keep durable lessons/rules in `g/memory/lessons/` and `g/memory/rules/`; tickets live in `g/memory/improvement_tickets/`.
- Planning Inputs: Architect nodes must ingest `g/memory/latest_lessons.json` + `latest_rules.json` on every run.
- Escalation: any WO with repeated patterns or missing skills triggers a new WO via the R&D ticket queue.

## Operational Checklist
- [ ] Add R&D node to Opal immediately after QA nodes.
- [ ] Wire CLS background analytics to write lesson/rule/ticket stubs.
- [ ] Call `tools/rnd_memory_refresh.py` to regenerate `latest_*.json` artifacts for planners.
- [ ] Route R&D digest to Mary and GG for governance visibility.
