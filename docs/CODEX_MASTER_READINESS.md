# CODEX Master Readiness – Phase 4 Snapshot

> 💡 **Developer Note:**
> For day-to-day workflow, smoke tests, and gateway setup,
> see [CODEX_DEV_RUNBOOK.md](./CODEX_DEV_RUNBOOK.md).

> **Updated:** 2025-10-15
> **Owner:** Codex Operations (boss ↔ codex)

## 1. Mission Summary
- Phase 4 merges MCP verification telemetry and the Linear-lite UI bridge into the Codex master prompt ecosystem.
- Goal: ensure Codex sessions inherit the freshest operational context before patch planning or deployment.

## 2. Gate Checklist
| Gate | Status | Notes |
|------|--------|-------|
| Preflight hooks | ✅ | Includes MCP verification freshness + Linear-lite cache age checks |
| MCP verification agent | ✅ | `agents/lukacode/verify_mcp.cjs` present & reporting to `g/reports/mcp_verify/` |
| Linear-lite sync agent | ✅ | `agents/lukacode/linear_lite_sync.cjs` active, SSE broadcast verified |
| Context mappings | ✅ | `f/ai_context/mapping.json` v2.2 exposes `codex:status:*` namespaces |
| Prompt templates | ✅ | `prompts/master_prompt.md` + derivatives hashed in `g/reports/templates/` |
| Runbooks | ✅ | `docs/CONTEXT_ENGINEERING.md` + `docs/api_endpoints.md` updated for Phase 4 |

## 3. Operational Steps (Codex Master)
1. Run `bash ./.codex/preflight.sh` – ensure Phase 4 checks return OK.
2. Pull latest context caches:
   ```bash
   scripts/context/refresh_phase4.sh --sync
   ```
3. Start Codex master session using `prompts/master_prompt.md`.
4. Reference MCP status with `codex:status:mcp` and Linear-lite board via `codex:status:linear-lite`.
5. On completion, archive outputs to `g/reports/` using `scripts/reports/publish_codex_master.sh`.

## 4. Escalation Paths
- **MCP Drift:** Trigger manual verify with `curl -X POST http://127.0.0.1:4000/api/mcp/verify -d '{"providers":["fs","docker"],"force":true}'`.
- **Linear-lite Stale Data:** Run `curl -X POST http://127.0.0.1:4000/api/linear-lite/sync -H "Content-Type: application/json" -d '{"syncType":"full"}'`.
- **Template Mismatch:** `g/tools/install_master_prompt.sh --force` to reinstall verified prompts.
- **Context Mapping Gap:** Update `f/ai_context/mapping.json` then run `scripts/context/rebuild_index.sh`.

## 5. Evidence Links
- MCP verify receipts: `g/reports/mcp_verify/`
- Linear-lite sync receipts: `g/reports/linear-lite/`
- Phase 4 diff summary: `g/reports/context_delta/`
- Template hashes: `g/reports/templates/master_prompt_*.json`

## 6. Next Actions
- [ ] Automate Codex master warmup pipeline (pending `verify_system.sh` integration).
- [ ] Extend Linear-lite coverage to include `done` state rollups in prompts.
- [ ] Publish nightly snapshot of MCP verification metrics to `boss/reports/`.

