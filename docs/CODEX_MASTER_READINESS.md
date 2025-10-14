# Codex Master Readiness (v251015_0212_atomic_phase4)
Status: ✅ Ready

## 1) Core Behaviors
- ✅ Linear-lite UI routes: `/`, `/chat`, `/plan`, `/build`, `/ship`
- ✅ Static assets: `/shared/*` (ui.css, api.js, components.js)
- ✅ `/api/plan` expects `goal` (stub via body `{"stub":true}` or header `X-Smoke: 1`)
- ✅ Reports API: `/api/reports/list`, `/api/reports/latest`, `/api/reports/summary`

## 2) Health & Smoke
- Runbook: `./run/ops_atomic.sh`
- Expect: PASS on **Preflight**, **Migration**, **Verify**, **MCP Verification**
- Quick smoke: `bash ./run/smoke_api_ui.sh`

## 3) Gateways
- AI Gateway (optional): `AI_GATEWAY_URL`, `AI_GATEWAY_KEY`
- Agents Gateway (optional): `AGENTS_GATEWAY_URL`, `AGENTS_GATEWAY_KEY`

## 4) Docs & Tag
- Updated docs: `docs/api_endpoints.md`, `docs/02luka.md`, `docs/CONTEXT_ENGINEERING.md`
- Checkpoint tag: `v251015_0212_atomic_phase4`

## 5) Quick Commands
```bash
# Plan (stub/fast)
curl -s http://127.0.0.1:4000/api/plan \
  -H 'Content-Type: application/json' \
  -d '{"goal":"ping","stub":true}' | jq .

# Reports summary
curl -s http://127.0.0.1:4000/api/reports/summary | jq .

# UI sanity (served by boss-api on 4000)
for p in / /chat /plan /build /ship /shared/ui.css; do \
  echo -n "$p: "; curl -sI http://127.0.0.1:4000$p | head -1; done
```

## 6) CI (optional, fast docs smoke)

Add a tiny job to validate the documented endpoints (≈5s):

```yaml
# .github/workflows/docs-smoke.yml
name: docs-smoke
on: [workflow_dispatch]
jobs:
  smoke:
    runs-on: ubuntu-latest
    timeout-minutes: 2
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20' }
      - name: Start boss-api
        run: |
          nohup node boss-api/server.cjs >/tmp/api.log 2>&1 &
          for i in {1..20}; do curl -fsS http://127.0.0.1:4000/healthz && break || sleep 0.5; done
      - name: Check /api/plan (stub)
        run: |
          code=$(curl -s -m 3 -w '%{http_code}' -o /dev/null \
            -H 'Content-Type: application/json' \
            -d '{"goal":"ping","stub":true}' \
            http://127.0.0.1:4000/api/plan)
          [ "$code" = "200" ] || (echo "plan stub failed: $code"; exit 1)
      - name: Check reports summary
        run: |
          curl -fsS http://127.0.0.1:4000/api/reports/summary >/dev/null || exit 1
```
