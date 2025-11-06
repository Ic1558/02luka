# Phase 15 – Autonomous Knowledge Routing (AKR)

This PR introduces **Phase 15 AKR** documentation and agent scaffolding — the foundation for autonomous intent-based routing between multiple agents (Kim ↔ Andy) built upon the Phase 14 RAG and Telemetry layers.

---

## 🧩 Deliverables

| File | Purpose |
|------|----------|
| `docs/phase14_summary.md` | Canonical consolidation of all Phase 14 reports |
| `docs/phase15_AKR_plan.md` | Full AKR architecture + 4-week implementation plan |
| `config/agents/andy.yaml` | Coding assistant agent spec (Phase 15) |
| `config/agents/kim.yaml` | NLP assistant agent spec (Phase 15) |
| `config/nlp_command_map.yaml` | Updated AKR routing map with bidirectional delegation |

---

## 🧠 Highlights
- **Router Architecture:** Intent Classifier → Router → Delegation Chain
- **Bidirectional Delegation:** Kim → Andy (code) and Andy → Kim (explain/help)
- **Unified Telemetry (Phase 14.2 Schema):** routing.*, delegation.*, performance.*
- **Governance Compliance:** All files contain SOT headers + version metadata
- **Success Metrics:** ≥ 95 % routing accuracy, < 100 ms latency

---

## 🧰 Implementation Summary
- Defined agent registries and capability mappings
- Added intent patterns and confidence thresholds (0.75)
- Introduced delegation protocol (max 3 hops to prevent loops)
- Embedded telemetry emission for router decisions
- Included sample `tools/router_akr.zsh` stub for core engine implementation

---

## 🧪 Testing & Verification
1. Validate YAML syntax
2. Confirm NLP map routes Kim ↔ Andy intents correctly
3. Ensure telemetry output uses unified schema
4. Verify router stub runs without errors (`zsh tools/router_akr.zsh --dry-run`)

---

## 🔗 Branch Info
**Branch:** `claude/docs-agent-scaffolding-011CUrRdJtiCFRLHXkdvMW1m`
**Commit:** `e09a87a`
**Work Order:** `WO-251107-PHASE-15-AKR`

---

## 🏁 Next Steps
- Merge docs & scaffolding → Main branch
- Begin Track C: Router Core Implementation (`tools/router_akr.zsh`)
- Extend telemetry with router.* events

---

**Labels:** phase15, akr, agents, docs
**Milestone:** Phase 15 — Autonomous Knowledge Routing
**Assignee:** Ic1558
