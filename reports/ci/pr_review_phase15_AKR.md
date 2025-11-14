# Phase 15 AKR — Reviewer Checklist

**Quick Validation (≈ 5 min)**
```bash
yamllint config/agents/*.yaml config/nlp_command_map.yaml
grep -R "phase15" docs/phase15_AKR_plan.md
zsh tools/router_akr.zsh --dry-run
```

**Confirm**
- [ ] docs/phase15_AKR_plan.md exists and matches Phase 14 architecture
- [ ] Andy + Kim configs load without YAML errors
- [ ] Delegation rules (Kim ↔ Andy) work as documented
- [ ] Telemetry sections follow unified schema (Phase 14.2)
- [ ] router_akr.zsh stub runs and logs router.init event

**Approve Comment**
> ✅ Verified Phase 15 AKR docs and agent scaffolding.
> Routing map and telemetry schema validated; ready for merge to main.

---

_Refer to `docs/phase15_AKR_plan.md` for 4-week implementation timeline and success metrics._
